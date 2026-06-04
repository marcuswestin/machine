#!/usr/bin/env bun
/**
 * Compare live app config on this Mac to repo-managed chezmoi sources.
 *
 * Default: human-readable report. Optional writes merge JSON as
 *   merged = { ...live, ...repo }
 * so existing repo keys win on conflicts and keys only on the machine are added.
 *
 * JSONC (vscode-family): parsing strips line and block comments outside strings. Writing
 * strips all comments unless you only use report mode.
 *
 * Excluded on purpose: ~/.config/gh (secrets), Claude settings (secrets heuristics).
 * Codex config is tracked as text; auth/session files and SQLite caches stay unmanaged.
 * Raycast: repo is the source of truth; use Raycast export UI then diff against
 * config/raycast/settings.json manually (no stable public live path here).
 *
 * Docker Desktop: do not symlink `settings-store.json` into the Group Container
 * (the backend crashes). Use `--push-docker-live` to merge repo keys onto the
 * live file: merged = { ...live, ...repo } (same as merge-in-settings writes to
 * repo, but applied to disk where Docker reads it). Invoked from `just chezmoi-apply`.
 */

import { createHash } from "node:crypto";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

function home(): string {
  return os.homedir();
}

function joinHome(parts: string[]): string {
  return path.join(home(), ...parts);
}

function joinRepo(repo: string, parts: string[]): string {
  return path.join(path.resolve(repo), ...parts);
}

/** Remove // line comments and slash-star block comments outside JSON strings. */
function stripJsoncComments(text: string): string {
  const out: string[] = [];
  let i = 0;
  const n = text.length;
  let inStr = false;
  let escape = false;
  while (i < n) {
    const c = text[i]!;
    if (inStr) {
      out.push(c);
      if (escape) {
        escape = false;
      } else if (c === "\\") {
        escape = true;
      } else if (c === "\"" && !escape) {
        inStr = false;
      }
      i += 1;
      continue;
    }
    if (c === "\"") {
      inStr = true;
      out.push(c);
      i += 1;
      continue;
    }
    if (c === "/" && i + 1 < n && text[i + 1] === "/") {
      while (i < n && text[i] !== "\n") {
        i += 1;
      }
      continue;
    }
    if (c === "/" && i + 1 < n && text[i + 1] === "*") {
      i += 2;
      while (i + 1 < n && !(text[i] === "*" && text[i + 1] === "/")) {
        i += 1;
      }
      i = Math.min(i + 2, n);
      continue;
    }
    out.push(c);
    i += 1;
  }
  return out.join("");
}

function parseJsonc(p: string): unknown {
  const raw = fs.readFileSync(p, "utf8");
  const stripped = stripJsoncComments(raw);
  return JSON.parse(stripped) as unknown;
}

function parseJson(p: string): unknown {
  return JSON.parse(fs.readFileSync(p, "utf8")) as unknown;
}

function pickLive(liveCandidates: string[], repo: string): string | null {
  let rdev: number | null = null;
  let rpath: string | null = null;
  try {
    rdev = fs.statSync(repo).ino;
    rpath = fs.realpathSync(repo);
  } catch {
    rdev = null;
    rpath = null;
  }
  for (const c of liveCandidates) {
    if (!fs.existsSync(c) || !fs.statSync(c).isFile()) {
      continue;
    }
    try {
      if (rpath !== null && fs.realpathSync(c) === rpath) {
        continue;
      }
    } catch {
      /* ignore */
    }
    try {
      if (rdev !== null && fs.statSync(c).ino === rdev) {
        continue;
      }
    } catch {
      /* ignore */
    }
    return c;
  }
  return null;
}

function allLiveResolveToRepo(liveCandidates: string[], repo: string): boolean {
  if (!fs.existsSync(repo) || !fs.statSync(repo).isFile()) {
    return false;
  }
  let r: string;
  try {
    r = fs.realpathSync(repo);
  } catch {
    return false;
  }
  let ok = false;
  for (const c of liveCandidates) {
    if (!fs.existsSync(c) || !fs.statSync(c).isFile()) {
      continue;
    }
    ok = true;
    try {
      if (fs.realpathSync(c) !== r) {
        return false;
      }
    } catch {
      return false;
    }
  }
  return ok;
}

function dictOnly(obj: unknown): Record<string, unknown> {
  if (obj === null || typeof obj !== "object" || Array.isArray(obj)) {
    return {};
  }
  return { ...(obj as Record<string, unknown>) };
}

/** Match JSON.stringify(..., { sort_keys: true }) — sort keys at every object level. */
function canonicalizeForJson(v: unknown): unknown {
  if (v === null || typeof v !== "object") {
    return v;
  }
  if (Array.isArray(v)) {
    return v.map(canonicalizeForJson);
  }
  const obj = v as Record<string, unknown>;
  const out: Record<string, unknown> = {};
  for (const k of Object.keys(obj).sort()) {
    out[k] = canonicalizeForJson(obj[k]);
  }
  return out;
}

function jsonStableStringify(v: unknown): string {
  return JSON.stringify(canonicalizeForJson(v));
}

function mergeReport(
  repoObj: Record<string, unknown>,
  liveObj: Record<string, unknown>,
): {
  onlyLive: Record<string, unknown>;
  onlyRepo: Record<string, unknown>;
  diffs: Record<string, [unknown, unknown]>;
} {
  const onlyLive: Record<string, unknown> = {};
  for (const k of Object.keys(liveObj)) {
    if (!(k in repoObj)) {
      onlyLive[k] = liveObj[k]!;
    }
  }
  const onlyRepo: Record<string, unknown> = {};
  for (const k of Object.keys(repoObj)) {
    if (!(k in liveObj)) {
      onlyRepo[k] = repoObj[k]!;
    }
  }
  const diffs: Record<string, [unknown, unknown]> = {};
  for (const k of Object.keys(repoObj)) {
    if (k in liveObj && jsonStableStringify(repoObj[k]) !== jsonStableStringify(liveObj[k])) {
      diffs[k] = [liveObj[k]!, repoObj[k]!];
    }
  }
  return { onlyLive, onlyRepo, diffs };
}

function writeJson(filePath: string, data: unknown): void {
  fs.writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`, "utf8");
}

function filesDeepEqual(a: string, b: string): boolean {
  try {
    return Buffer.compare(fs.readFileSync(a), fs.readFileSync(b)) === 0;
  } catch {
    return false;
  }
}

type TargetBase = {
  id: string;
  repo: string[];
  live: string[][];
};

type TargetJson = TargetBase & {
  kind?: undefined;
  parse: (p: string) => unknown;
  dict_merge?: boolean;
  write_jsonc?: boolean;
  write_flag?: "docker";
};

type TargetText = TargetBase & {
  kind: "text";
};

type Target = TargetJson | TargetText;

const TARGETS: Target[] = [
  {
    id: "vscode-family-settings",
    repo: ["home", ".dotfiles", "vscode-family", "settings.json"],
    live: [
      ["Library", "Application Support", "Cursor", "User", "settings.json"],
      ["Library", "Application Support", "Code", "User", "settings.json"],
    ],
    parse: parseJsonc,
    dict_merge: true,
    write_jsonc: true,
  },
  {
    id: "vscode-family-keybindings",
    repo: ["home", ".dotfiles", "vscode-family", "keybindings.json"],
    live: [
      ["Library", "Application Support", "Cursor", "User", "keybindings.json"],
      ["Library", "Application Support", "Code", "User", "keybindings.json"],
    ],
    parse: parseJsonc,
    dict_merge: false,
    write_jsonc: true,
  },
  {
    id: "cursor-cli-config",
    repo: ["home", ".dotfiles", "cursor", "cli-config.json"],
    live: [[".cursor", "cli-config.json"]],
    parse: parseJson,
    dict_merge: true,
    write_jsonc: false,
  },
  {
    id: "codex-config",
    repo: ["home", ".dotfiles", "codex", "config.toml"],
    live: [[".codex", "config.toml"]],
    kind: "text",
  },
  {
    id: "handy-settings-store",
    repo: ["home", ".dotfiles", "handy", "settings_store.json"],
    live: [["Library", "Application Support", "com.pais.handy", "settings_store.json"]],
    parse: parseJson,
    dict_merge: true,
    write_jsonc: false,
  },
  {
    // Docker Desktop: chezmoi symlink at live path crashes the backend — push merged JSON via --push-docker-live.
    id: "docker-settings-store",
    repo: ["home", ".dotfiles", "docker", "settings-store.json"],
    live: [["Library", "Group Containers", "group.com.docker", "settings-store.json"]],
    parse: parseJson,
    dict_merge: true,
    write_jsonc: false,
    write_flag: "docker",
  },
  {
    id: "continue-continuerc",
    repo: ["home", ".dotfiles", "continue", ".continuerc.json"],
    live: [[".continue", ".continuerc.json"]],
    parse: parseJson,
    dict_merge: true,
    write_jsonc: false,
  },
  {
    id: "iterm-dynamic-profile",
    repo: ["home", ".dotfiles", "iterm2", "dynamic-profiles", "machine.json"],
    live: [
      ["Library", "Application Support", "iTerm2", "DynamicProfiles", "machine.json"],
    ],
    parse: parseJson,
    dict_merge: true,
    write_jsonc: false,
  },
  {
    id: "antigravity-preferences",
    repo: ["home", ".dotfiles", "antigravity", "Preferences"],
    live: [["Library", "Application Support", "Antigravity", "Preferences"]],
    parse: parseJson,
    dict_merge: true,
    write_jsonc: false,
  },
  {
    id: "continue-config-yaml",
    repo: ["home", ".dotfiles", "continue", "config.yaml"],
    live: [[".continue", "config.yaml"]],
    kind: "text",
  },
  {
    id: "continue-config-ts",
    repo: ["home", ".dotfiles", "continue", "config.ts"],
    live: [[".continue", "config.ts"]],
    kind: "text",
  },
];

function anyLiveFile(livePaths: string[]): boolean {
  for (const p of livePaths) {
    if (fs.existsSync(p) && fs.statSync(p).isFile()) {
      return true;
    }
  }
  return false;
}

/** Merge repo Docker settings onto the live Group Container file (never a symlink). */
function pushDockerLiveSettings(repoRoot: string): { status: string; live?: string; error?: string } {
  const repo = joinRepo(repoRoot, ["home", ".dotfiles", "docker", "settings-store.json"]);
  const livePath = joinHome(["Library", "Group Containers", "group.com.docker", "settings-store.json"]);

  if (!fs.existsSync(repo) || !fs.statSync(repo).isFile()) {
    return { status: "missing_repo", error: repo };
  }

  let repoData: unknown;
  try {
    repoData = parseJson(repo);
  } catch (e) {
    return {
      status: "parse_error",
      error: e instanceof Error ? e.message : String(e),
    };
  }
  const rd = dictOnly(repoData);

  if (fs.existsSync(livePath)) {
    const st = fs.lstatSync(livePath);
    if (st.isSymbolicLink()) {
      return {
        status: "symlink_blocked",
        live: livePath,
        error: "remove symlink; Docker Desktop crashes when this path is symlinked",
      };
    }
    if (!st.isFile()) {
      return { status: "not_a_file", live: livePath };
    }
  }

  let ld: Record<string, unknown> = {};
  if (fs.existsSync(livePath)) {
    try {
      ld = dictOnly(parseJson(livePath));
    } catch (e) {
      return {
        status: "parse_error",
        live: livePath,
        error: e instanceof Error ? e.message : String(e),
      };
    }
  }

  const merged = { ...ld, ...rd };
  if (fs.existsSync(livePath)) {
    try {
      if (jsonStableStringify(merged) === jsonStableStringify(dictOnly(parseJson(livePath)))) {
        return { status: "identical", live: livePath };
      }
    } catch {
      /* fall through to write */
    }
  }

  fs.mkdirSync(path.dirname(livePath), { recursive: true });
  writeJson(livePath, merged);
  return { status: "wrote_live", live: livePath };
}

function processTarget(
  repoRoot: string,
  t: Target,
  opts: {
    writeLossy: boolean;
    writeJsoncVscode: boolean;
    writeDocker: boolean;
    asJson: boolean;
  },
): Record<string, unknown> {
  const out: Record<string, unknown> = { id: t.id, status: "unknown" };
  const repo = joinRepo(repoRoot, t.repo);
  const livePaths = t.live.map((p) => joinHome(p));

  if (!fs.existsSync(repo) || !fs.statSync(repo).isFile()) {
    out.status = "missing_repo";
    out.repo = repo;
    return out;
  }

  if (t.kind === "text") {
    const live = pickLive(livePaths, repo);
    if (live === null) {
      if (anyLiveFile(livePaths) && allLiveResolveToRepo(livePaths, repo)) {
        out.status = "symlink_ok";
      } else if (!anyLiveFile(livePaths)) {
        out.status = "missing_live";
      } else {
        out.status = "symlink_ok";
      }
      out.repo = repo;
      return out;
    }
    const same = filesDeepEqual(live, repo);
    out.status = same ? "identical" : "text_differs";
    out.live = live;
    out.repo = repo;
    if (!same && !opts.asJson) {
      const ha = createHash("sha256").update(fs.readFileSync(live)).digest("hex").slice(0, 12);
      const hb = createHash("sha256").update(fs.readFileSync(repo)).digest("hex").slice(0, 12);
      console.log(
        `\n=== ${t.id} ===\n  live: ${live}\n  repo: ${repo}\n  sha256 live ${ha}  repo ${hb}\n  run: diff -u ${repo} ${live}`,
      );
    }
    return out;
  }

  const parse = t.parse;
  const live = pickLive(livePaths, repo);
  if (live === null) {
    if (anyLiveFile(livePaths) && allLiveResolveToRepo(livePaths, repo)) {
      out.status = "symlink_ok";
    } else if (!anyLiveFile(livePaths)) {
      out.status = "missing_live";
    } else {
      out.status = "symlink_ok";
    }
    out.repo = repo;
    return out;
  }

  out.live = live;
  out.repo = repo;

  let repoData: unknown;
  let liveData: unknown;
  try {
    repoData = parse(repo);
    liveData = parse(live);
  } catch (e) {
    out.status = "parse_error";
    out.error = e instanceof Error ? e.message : String(e);
    return out;
  }

  const dictMerge = t.dict_merge !== false;
  if (!dictMerge) {
    const allowCopyLive = Boolean(opts.writeJsoncVscode && t.write_jsonc);
    if (jsonStableStringify(repoData) === jsonStableStringify(liveData)) {
      out.status = "identical";
    } else {
      out.status = "json_differs";
      if (!opts.asJson) {
        console.log(
          `\n=== ${t.id} ===\n  live: ${live}\n  repo: ${repo}\n`
            + "  (array JSON — diff -u, or --write-jsonc-vscode to replace repo with live copy)",
        );
      }
      if (allowCopyLive) {
        writeJson(repo, liveData);
        out.status = "wrote_live_copy";
        out.wrote = repo;
      }
    }
    return out;
  }

  const rd = dictOnly(repoData);
  const ld = dictOnly(liveData);
  const { onlyLive, onlyRepo, diffs } = mergeReport(rd, ld);
  out.only_live_keys = Object.keys(onlyLive).sort();
  out.only_repo_keys = Object.keys(onlyRepo).sort();
  out.diff_keys = Object.keys(diffs).sort();
  out.status = "report";

  const merged = { ...ld, ...rd };
  let allowWrite: boolean;
  if (t.write_jsonc) {
    allowWrite = opts.writeJsoncVscode;
  } else {
    allowWrite = opts.writeLossy;
    if (t.write_flag === "docker") {
      allowWrite = opts.writeLossy && opts.writeDocker;
    }
  }

  if (allowWrite && t.dict_merge !== false) {
    writeJson(repo, merged);
    out.status = "wrote_merged";
    out.wrote = repo;
  }

  return out;
}

function parseCli(argv: string[]): {
  repo: string;
  writeLossy: boolean;
  writeJsoncVscode: boolean;
  writeDocker: boolean;
  pushDockerLive: boolean;
  asJson: boolean;
} | null {
  const positionals: string[] = [];
  let writeLossy = false;
  let writeJsoncVscode = false;
  let writeDocker = false;
  let pushDockerLive = false;
  let asJson = false;
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i]!;
    if (a === "--write-lossy") {
      writeLossy = true;
    } else if (a === "--write-jsonc-vscode") {
      writeJsoncVscode = true;
    } else if (a === "--write-docker") {
      writeDocker = true;
    } else if (a === "--push-docker-live") {
      pushDockerLive = true;
    } else if (a === "--json") {
      asJson = true;
    } else if (a.startsWith("-")) {
      console.error(`error: unknown flag: ${a}`);
      return null;
    } else {
      positionals.push(a);
    }
  }
  if (positionals.length < 1) {
    console.error(
      "usage: repo-settings-import.ts <repo-root> [--write-lossy] ... [--push-docker-live] (run via: just merge-in-settings …)",
    );
    return null;
  }
  return {
    repo: positionals[0]!,
    writeLossy,
    writeJsoncVscode,
    writeDocker,
    pushDockerLive,
    asJson,
  };
}

function main(): number {
  const parsed = parseCli(process.argv.slice(2));
  if (parsed === null) {
    return 2;
  }
  const repoRoot = path.resolve(parsed.repo);
  const homeDir = path.join(repoRoot, "home");
  if (!fs.existsSync(homeDir) || !fs.statSync(homeDir).isDirectory()) {
    console.error(`error: not a machine repo (missing home/): ${repoRoot}`);
    return 2;
  }

  if (parsed.pushDockerLive) {
    const r = pushDockerLiveSettings(repoRoot);
    if (parsed.asJson) {
      console.log(JSON.stringify(r, null, 2));
    } else if (r.status === "wrote_live") {
      console.log(`docker-settings-store: wrote merged JSON → ${r.live}`);
    } else if (r.status === "identical") {
      console.log(`docker-settings-store: identical (${r.live})`);
    } else if (r.status === "symlink_blocked" || r.status === "not_a_file") {
      console.error(
        `docker-settings-store: ${r.status}${r.live ? ` (${r.live})` : ""}${r.error ? `: ${r.error}` : ""}`,
      );
      return 1;
    } else if (r.status === "parse_error" || r.status === "missing_repo") {
      console.error(`docker-settings-store: ${r.status}${r.error ? `: ${r.error}` : ""}`);
      return 1;
    } else {
      console.log(`docker-settings-store: ${r.status}`);
    }
    if (!(parsed.writeLossy || parsed.writeJsoncVscode || parsed.writeDocker)) {
      return 0;
    }
  }

  const rows: Record<string, unknown>[] = [];
  for (const t of TARGETS) {
    rows.push(
      processTarget(repoRoot, t, {
        writeLossy: parsed.writeLossy,
        writeJsoncVscode: parsed.writeJsoncVscode,
        writeDocker: parsed.writeDocker,
        asJson: parsed.asJson,
      }),
    );
  }

  if (parsed.asJson) {
    console.log(JSON.stringify(rows, null, 2));
    return 0;
  }

  for (const row of rows) {
    const sid = row.id as string;
    const st = row.status as string;
    if (st === "symlink_ok") {
      console.log(`${sid}: OK (live resolves to repo canonical file)`);
    } else if (st === "missing_live") {
      console.log(`${sid}: no live file on this Mac (skip)`);
    } else if (st === "missing_repo") {
      console.log(`${sid}: missing repo file ${row.repo}`);
    } else if (st === "parse_error") {
      console.log(`${sid}: parse error: ${row.error}`);
    } else if (st === "identical") {
      console.log(`${sid}: identical`);
    } else if (st === "json_differs") {
      console.log(`${sid}: JSON differs (see note above)`);
    } else if (st === "wrote_live_copy") {
      console.log(`${sid}: wrote live JSON → ${row.wrote}`);
    } else if (st === "text_differs") {
      console.log(`${sid}: text differs (see diff lines above)`);
    } else if (st === "wrote_merged") {
      console.log(`${sid}: wrote merged JSON → ${row.wrote}`);
    } else {
      const ol = (row.only_live_keys as string[]) || [];
      const dr = (row.diff_keys as string[]) || [];
      const orp = (row.only_repo_keys as string[]) || [];
      console.log(`${sid}: keys only on machine (not in repo): ${ol.length}`);
      if (ol.length > 0) {
        for (const k of ol.slice(0, 80)) {
          console.log(`  + ${k}`);
        }
        if (ol.length > 80) {
          console.log(`  … (${ol.length - 80} more)`);
        }
      }
      console.log(`  keys only in repo: ${orp.length}  conflicting values: ${dr.length}`);
      if (dr.length > 0 && dr.length <= 12) {
        for (const k of dr) {
          console.log(`  ~ ${k} (repo value kept on merge)`);
        }
      }
    }
  }

  if (parsed.writeLossy || parsed.writeJsoncVscode) {
    console.log("\nNote: merged JSON uses repo values when the same key exists in both files.");
    if (parsed.writeJsoncVscode) {
      console.log(
        "vscode-family JSONC write strips // and /* */ comments — prefer report-only and paste keys.",
      );
    }
  }

  return 0;
}

process.exit(main());
