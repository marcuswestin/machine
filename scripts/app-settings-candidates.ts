#!/usr/bin/env bun
import { spawnSync } from "node:child_process";
import { existsSync, lstatSync, mkdirSync, readdirSync, writeFileSync } from "node:fs";
import { basename, extname, join, resolve } from "node:path";

type CaskConfig = {
  name: string;
};

type CaskInfo = {
  token?: string;
  full_token?: string;
  artifacts?: unknown[];
};

type DefaultsDomain = {
  domain: string;
  match: "bundle-id" | "bundle-id-prefix" | "quit-bundle-id" | "name-heuristic";
  plistPaths: string[];
  keys: string[];
};

type CandidateFile = {
  path: string;
  reason: string;
};

type AppReport = {
  cask: string;
  token: string;
  appBundles: string[];
  bundleIds: string[];
  quitBundleIds: string[];
  defaultsDomains: DefaultsDomain[];
  candidateFiles: CandidateFile[];
  ignoredFiles: CandidateFile[];
  zapPaths: string[];
  warnings: string[];
};

const repoDir = resolve(import.meta.dir, "..");
const outDir = join(repoDir, "inventory-global", "discovery");
const jsonOut = join(outDir, "app-settings-candidates.json");
const textOut = join(outDir, "app-settings-candidates.txt");
const home = process.env.HOME ?? "";

function run(command: string, args: string[], options: { cwd?: string; input?: string } = {}) {
  const result = spawnSync(command, args, {
    cwd: options.cwd ?? repoDir,
    env: {
      ...process.env,
      HOMEBREW_NO_AUTO_UPDATE: "1",
      HOMEBREW_NO_INSTALL_FROM_API: "1",
    },
    input: options.input,
    encoding: "utf8",
  });
  return {
    ok: result.status === 0,
    stdout: result.stdout.trim(),
    stderr: result.stderr.trim(),
    status: result.status,
  };
}

function readJsonCommand<T>(command: string, args: string[]): T {
  const result = run(command, args);
  if (!result.ok) {
    throw new Error(`${command} ${args.join(" ")} failed:\n${result.stderr}`);
  }
  return JSON.parse(result.stdout) as T;
}

function declaredCasks(): string[] {
  const casks = readJsonCommand<CaskConfig[]>("nix", [
    "eval",
    "--extra-experimental-features",
    "nix-command flakes",
    "--json",
    ".#darwinConfigurations.machine.config.homebrew.casks",
  ]);
  return casks.map((cask) => cask.name).sort((a, b) => a.localeCompare(b));
}

function caskInfo(cask: string): { info?: CaskInfo; warnings: string[] } {
  const result = run("brew", ["info", "--cask", "--json=v2", cask]);
  if (!result.ok) {
    return { warnings: [`brew info failed: ${result.stderr || `exit ${result.status}`}`] };
  }
  const parsed = JSON.parse(result.stdout) as { casks?: CaskInfo[] };
  return { info: parsed.casks?.[0], warnings: [] };
}

function stringsFromArtifact(cask: CaskInfo, key: string): string[] {
  const values: string[] = [];
  for (const artifact of cask.artifacts ?? []) {
    if (!artifact || typeof artifact !== "object" || !(key in artifact)) continue;
    const value = (artifact as Record<string, unknown>)[key];
    if (Array.isArray(value)) {
      for (const item of value) {
        if (typeof item === "string") values.push(item);
      }
    } else if (typeof value === "string") {
      values.push(value);
    }
  }
  return [...new Set(values)].sort((a, b) => a.localeCompare(b));
}

function nestedStrings(value: unknown, wantedKey: string): string[] {
  if (Array.isArray(value)) return value.flatMap((item) => nestedStrings(item, wantedKey));
  if (!value || typeof value !== "object") return [];
  const record = value as Record<string, unknown>;
  const direct = record[wantedKey];
  const found: string[] = [];
  if (typeof direct === "string") found.push(direct);
  if (Array.isArray(direct)) {
    for (const item of direct) {
      if (typeof item === "string") found.push(item);
    }
  }
  for (const item of Object.values(record)) found.push(...nestedStrings(item, wantedKey));
  return found;
}

function zapPaths(cask: CaskInfo): string[] {
  return [...new Set(nestedStrings(cask.artifacts ?? [], "trash").map(expandHome))]
    .sort((a, b) => a.localeCompare(b));
}

function quitBundleIds(cask: CaskInfo): string[] {
  return [...new Set(nestedStrings(cask.artifacts ?? [], "quit"))].sort((a, b) => a.localeCompare(b));
}

function expandHome(path: string): string {
  if (path === "~") return home;
  if (path.startsWith("~/")) return join(home, path.slice(2));
  return path;
}

function appBundlePaths(appArtifacts: string[]): string[] {
  const paths = new Set<string>();
  for (const artifact of appArtifacts) {
    const expanded = expandHome(artifact);
    const candidates = expanded.startsWith("/")
      ? [expanded]
      : [join("/Applications", basename(expanded)), join(home, "Applications", basename(expanded))];
    for (const candidate of candidates) {
      if (existsSync(candidate)) paths.add(candidate);
    }
  }
  return [...paths].sort((a, b) => a.localeCompare(b));
}

function bundleId(appPath: string): string | undefined {
  const plist = join(appPath, "Contents", "Info.plist");
  if (!existsSync(plist)) return undefined;
  const result = run("/usr/bin/plutil", ["-extract", "CFBundleIdentifier", "raw", "-o", "-", plist]);
  return result.ok && result.stdout ? result.stdout : undefined;
}

function defaultsDomains(): string[] {
  const result = run("defaults", ["domains"]);
  if (!result.ok || !result.stdout) return [];
  return result.stdout
    .split(",")
    .map((domain) => domain.trim())
    .filter(Boolean)
    .sort((a, b) => a.localeCompare(b));
}

function normalizeName(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]/g, "");
}

function domainMatches(
  domain: string,
  appNames: string[],
  bundleIds: string[],
  quitIds: string[],
): DefaultsDomain["match"] | undefined {
  if (bundleIds.includes(domain)) return "bundle-id";
  if (bundleIds.some((id) => domain.startsWith(`${id}.`))) return "bundle-id-prefix";
  if (quitIds.includes(domain)) return "quit-bundle-id";

  const normalizedDomain = normalizeName(domain);
  const domainParts = domain.split(/[^A-Za-z0-9]+/).map(normalizeName).filter(Boolean);
  const normalizedNames = appNames.map(normalizeName).filter((name) => name.length >= 4);
  const helperSuffixes = ["app", "desktop", "helper", "settings", "service", "updater"];
  const nameMatch = normalizedNames.some((name) =>
    domainParts.some((part) => part === name || helperSuffixes.some((suffix) => part === `${name}${suffix}`))
    || normalizedDomain === name
    || helperSuffixes.some((suffix) => normalizedDomain === `${name}${suffix}`)
  );
  if (!domain.startsWith("com.apple.") && nameMatch) {
    return "name-heuristic";
  }
  return undefined;
}

function plistPathsForDomain(domain: string): string[] {
  return [
    join(home, "Library", "Preferences", `${domain}.plist`),
    join("/Library", "Preferences", `${domain}.plist`),
  ].filter((path) => existsSync(path));
}

function plistTopLevelKeys(path: string): string[] {
  const result = run("/usr/bin/plutil", ["-convert", "json", "-o", "-", path]);
  if (!result.ok || !result.stdout) return [];
  try {
    const parsed = JSON.parse(result.stdout) as unknown;
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return [];
    return Object.keys(parsed as Record<string, unknown>).sort((a, b) => a.localeCompare(b));
  } catch {
    return [];
  }
}

function shouldIgnorePath(path: string): string | undefined {
  const lower = path.toLowerCase();
  const ignoredFragments = [
    "/caches/",
    "/cache/",
    "/logs/",
    "/crashes/",
    "/saved application state/",
    "/httpstorages/",
    "/cookies",
    "/local storage/",
    "/session storage/",
    "/indexeddb/",
    "/gpucache/",
    "/code cache/",
    "/crashpad/",
    "/sentry/",
    "/sentrycrash/",
    "/component_crx_cache/",
    "/extensions_crx_cache/",
  ];
  const sensitiveFragments = [
    "auth",
    "token",
    "secret",
    "cookie",
    "session",
    "history",
    "credentials",
    "keychain",
  ];
  const volatileExtensions = [".db", ".sqlite", ".sqlite3", ".log", ".lock"];

  if (ignoredFragments.some((fragment) => lower.includes(fragment))) return "volatile app state";
  if (sensitiveFragments.some((fragment) => lower.includes(fragment))) return "sensitive name";
  if (volatileExtensions.includes(extname(lower))) return "volatile file type";
  if (
    lower.includes("/library/application support/google/chrome/") && !lower.endsWith("/default/preferences")
    && !lower.endsWith("/local state")
  ) {
    return "browser generated state";
  }
  if (basename(lower) === "manifest.json") return "app/component manifest";
  if (basename(lower) === "window-state.json") return "volatile window state";
  return undefined;
}

function looksLikeConfigFile(path: string): string | undefined {
  const name = basename(path).toLowerCase();
  const extension = extname(name);
  if ([".json", ".jsonc", ".yaml", ".yml", ".toml", ".plist", ".conf", ".ini"].includes(extension)) {
    return `${extension.slice(1)} file`;
  }
  if (["prefs.js", "user.js"].includes(name)) return "browser preference file";
  if (["preferences", "settings", "config"].includes(name)) return "config-like filename";
  if (name.startsWith("settings.") || name.startsWith("config.")) return "config-like filename";
  return undefined;
}

function walkFiles(root: string, maxDepth: number): string[] {
  const files: string[] = [];
  function visit(path: string, depth: number) {
    if (depth > maxDepth || !existsSync(path)) return;
    let stat;
    try {
      stat = lstatSync(path);
    } catch {
      return;
    }
    if (stat.isSymbolicLink()) return;
    if (stat.isFile()) {
      files.push(path);
      return;
    }
    if (!stat.isDirectory()) return;
    const ignored = shouldIgnorePath(`${path}/`);
    if (ignored) return;
    for (const child of readdirSync(path)) visit(join(path, child), depth + 1);
  }
  visit(root, 0);
  return files.sort((a, b) => a.localeCompare(b));
}

function supportRoots(caskName: string, paths: string[], bundleIds: string[], appNames: string[]): string[] {
  const roots = new Set<string>();
  const supportAliases: Record<string, string[]> = {
    firefox: ["Firefox"],
    "google-chrome": [join("Google", "Chrome")],
    "visual-studio-code": ["Code"],
  };
  for (const path of paths) {
    if (!path.includes("/Library/Application Support/")) continue;
    const ignored = shouldIgnorePath(path);
    if (!ignored) roots.add(path);
  }
  for (const id of bundleIds) roots.add(join(home, "Library", "Application Support", id));
  for (const name of appNames) roots.add(join(home, "Library", "Application Support", name));
  for (const name of supportAliases[caskName] ?? []) roots.add(join(home, "Library", "Application Support", name));
  const deduped = new Map<string, string>();
  for (const root of roots) {
    if (!existsSync(root)) continue;
    deduped.set(root.toLowerCase(), root);
  }
  return [...deduped.values()].sort((a, b) => a.localeCompare(b));
}

function candidateFiles(roots: string[]): { candidates: CandidateFile[]; ignored: CandidateFile[] } {
  const candidates: CandidateFile[] = [];
  const ignored: CandidateFile[] = [];
  for (const root of roots) {
    for (const file of walkFiles(root, 3)) {
      const ignoredReason = shouldIgnorePath(file);
      if (ignoredReason) {
        ignored.push({ path: file, reason: ignoredReason });
        continue;
      }
      const reason = looksLikeConfigFile(file);
      if (reason) candidates.push({ path: file, reason });
    }
  }
  return {
    candidates: candidates.sort((a, b) => a.path.localeCompare(b.path)),
    ignored: ignored.sort((a, b) => a.path.localeCompare(b.path)),
  };
}

function renderText(apps: AppReport[]): string {
  const lines: string[] = [];
  lines.push("App settings candidates");
  lines.push("=======================");
  lines.push("");
  lines.push("Review-only report. Defaults values and file contents are intentionally omitted.");
  lines.push("");
  for (const app of apps) {
    lines.push(`## ${app.cask}`);
    if (app.bundleIds.length > 0) lines.push(`Bundle IDs: ${app.bundleIds.join(", ")}`);
    if (app.quitBundleIds.length > 0) lines.push(`Quit IDs: ${app.quitBundleIds.join(", ")}`);
    if (app.appBundles.length > 0) lines.push(`Apps: ${app.appBundles.join(", ")}`);
    for (const warning of app.warnings) lines.push(`Warning: ${warning}`);
    lines.push(`Defaults domains: ${app.defaultsDomains.length}`);
    for (const domain of app.defaultsDomains) {
      lines.push(`  - ${domain.domain} (${domain.match})`);
      if (domain.keys.length > 0) lines.push(`    keys: ${domain.keys.join(", ")}`);
      for (const path of domain.plistPaths) lines.push(`    plist: ${path}`);
    }
    lines.push(`Candidate config files: ${app.candidateFiles.length}`);
    for (const file of app.candidateFiles.slice(0, 30)) {
      lines.push(`  - ${file.path} (${file.reason})`);
    }
    if (app.candidateFiles.length > 30) lines.push(`  ... ${app.candidateFiles.length - 30} more in JSON report`);
    lines.push(`Ignored sensitive/volatile files: ${app.ignoredFiles.length}`);
    lines.push("");
  }
  return `${lines.join("\n")}\n`;
}

mkdirSync(outDir, { recursive: true });

const domains = defaultsDomains();
const apps: AppReport[] = declaredCasks().map((caskName) => {
  const { info, warnings } = caskInfo(caskName);
  const cask = info ?? { token: caskName, artifacts: [] };
  const appArtifacts = stringsFromArtifact(cask, "app");
  const appBundles = appBundlePaths(appArtifacts);
  const bundleIds = [...new Set(appBundles.map(bundleId).filter((id): id is string => Boolean(id)))].sort((a, b) =>
    a.localeCompare(b)
  );
  const quitIds = quitBundleIds(cask);
  const token = cask.token ?? cask.full_token ?? caskName;
  const appNames = [
    token.split("/").at(-1) ?? token,
    ...appArtifacts.map((artifact) => basename(artifact, ".app")),
    ...appBundles.map((app) => basename(app, ".app")),
  ];
  const matchedDomains = domains
    .map((domain) => {
      const match = domainMatches(domain, appNames, bundleIds, quitIds);
      if (!match) return undefined;
      const plists = plistPathsForDomain(domain);
      const keys = [...new Set(plists.flatMap(plistTopLevelKeys))].sort((a, b) => a.localeCompare(b));
      return { domain, match, plistPaths: plists, keys } satisfies DefaultsDomain;
    })
    .filter((domain): domain is DefaultsDomain => Boolean(domain));
  const zaps = zapPaths(cask);
  const roots = supportRoots(caskName, zaps, bundleIds, appNames);
  const files = candidateFiles(roots);

  return {
    cask: caskName,
    token,
    appBundles,
    bundleIds,
    quitBundleIds: quitIds,
    defaultsDomains: matchedDomains,
    candidateFiles: files.candidates,
    ignoredFiles: files.ignored,
    zapPaths: zaps,
    warnings,
  };
});

const summary = {
  generatedAt: new Date().toISOString(),
  repo: repoDir,
  appCount: apps.length,
  defaultsDomainCount: apps.reduce((count, app) => count + app.defaultsDomains.length, 0),
  candidateFileCount: apps.reduce((count, app) => count + app.candidateFiles.length, 0),
  ignoredFileCount: apps.reduce((count, app) => count + app.ignoredFiles.length, 0),
};

writeFileSync(jsonOut, `${JSON.stringify({ summary, apps }, null, 2)}\n`);
writeFileSync(textOut, renderText(apps));

console.log(`Wrote ${jsonOut}`);
console.log(`Wrote ${textOut}`);
console.log(`Apps: ${summary.appCount}`);
console.log(`Defaults domains: ${summary.defaultsDomainCount}`);
console.log(`Candidate config files: ${summary.candidateFileCount}`);
console.log(`Ignored sensitive/volatile files: ${summary.ignoredFileCount}`);
