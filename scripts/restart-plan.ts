#!/usr/bin/env bun
// Read-only list of running-app candidates whose declared saved settings differ.
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

const repo = resolve(import.meta.dir, "..");
function output(command: string, args: string[]): string {
  const result = spawnSync(command, args, { cwd: repo, encoding: "utf8" });
  if (result.status !== 0) throw new Error(`Could not plan app restarts: ${command} ${args.join(" ")}`);
  return result.stdout;
}
export function appsForChanges(
  codex: string,
  preferences: string,
  chezmoi: string,
  defaults: string,
  json: string,
  options: { skipDocker?: boolean; strict?: boolean } = {},
): string[] {
  const strict = options.strict ?? process.env.MACHINE_RESTART_STRICT === "1";
  const apps = new Set<string>();
  if (/^  MISSING /m.test(codex) || /^  CONFLICT /m.test(codex) || /^\[DIFF\] codex\./m.test(codex)) {
    apps.add("ChatGPT");
  }
  if (/\[DIFF\] claude-/i.test(preferences)) apps.add("Claude");
  if (/\[UNKNOWN\] /i.test(preferences)) {
    throw new Error("App preferences could not be checked; resolve this before applying");
  }
  for (const line of chezmoi.split("\n")) {
    if (!line.startsWith("diff --git ")) continue;
    if (/codex|agents\//i.test(line)) apps.add("ChatGPT");
    if (/aerospace/i.test(line)) apps.add("AeroSpace");
    if (/vscode-family/i.test(line)) {
      apps.add("Cursor");
      apps.add("Visual Studio Code");
    }
    if (/iterm/i.test(line)) apps.add("iTerm");
    if (/karabiner/i.test(line)) apps.add("Karabiner-Elements");
    if (/handy/i.test(line)) apps.add("Handy");
    if (/antigravity/i.test(line)) apps.add("Antigravity IDE");
  }
  for (const line of defaults.split("\n")) {
    if (!/^\[(DIFF|UNKNOWN|UNVERIFIED)\] /.test(line)) continue;
    if (line.includes("eu.exelban.Stats")) apps.add("Stats");
    if (line.includes("com.stonerl.Thaw")) apps.add("Thaw");
    if (line.includes("app.monitorcontrol.MonitorControl")) apps.add("MonitorControl");
    if (line.includes("com.google.Chrome")) apps.add("Google Chrome");
    if (line.includes("bobko.aerospace")) apps.add("AeroSpace");
    if (line.includes("com.openai.chat")) apps.add("ChatGPT");
    if (line.includes("com.raycast.macos")) apps.add("Raycast");
  }
  const rows = JSON.parse(json) as { id: string; status: string; only_repo_keys?: string[]; diff_keys?: string[] }[];
  for (const row of rows) {
    if (row.id === "docker-settings-store") continue;
    if (["permission_denied", "parse_error", "missing_repo"].includes(row.status)) {
      if (strict) {
        throw new Error(
          `${row.id} settings are unverified; resolve access or parse errors before apply-full`,
        );
      }
      continue;
    }
    const changed = row.status === "missing_live" || row.status === "json_differs" || row.status === "text_differs"
      || (row.status === "report" && ((row.only_repo_keys?.length ?? 0) + (row.diff_keys?.length ?? 0) > 0));
    if (!changed) continue;
    if (row.id.startsWith("vscode-family")) {
      apps.add("Cursor");
      apps.add("Visual Studio Code");
    }
    if (row.id.startsWith("cursor-")) apps.add("Cursor");
    if (row.id.startsWith("antigravity")) apps.add("Antigravity IDE");
    if (row.id.startsWith("iterm")) apps.add("iTerm");
    if (row.id.startsWith("handy")) apps.add("Handy");
    if (row.id.startsWith("continue-")) {
      apps.add("Cursor");
      apps.add("Visual Studio Code");
    }
    if (row.id.startsWith("chrome-")) apps.add("Google Chrome");
  }
  return [...apps].sort();
}

if (import.meta.main) {
  try {
    const codex = output("bun", ["scripts/codex-config-sync.ts", "check"]);
    const preferences = output("bun", ["scripts/app-preferences.ts", "check"]);
    const chezmoi = output("chezmoi", ["diff", "--source", `${repo}/home`]);
    const defaults = output("bun", [
      "scripts/check-app-defaults.ts",
      process.env.MACHINE_HOST ?? "machine",
    ]);
    const json = output("bun", ["scripts/repo-settings-import.ts", repo, "--json"]);
    for (const app of appsForChanges(codex, preferences, chezmoi, defaults, json)) console.log(app);
  } catch (error) {
    console.error((error as Error).message);
    process.exitCode = 2;
  }
}
