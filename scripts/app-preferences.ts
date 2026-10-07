#!/usr/bin/env bun
// Merge only declared preference leaves into writable app files. Never import
// whole app files into Git: Claude's files also contain credentials and sessions.
import { spawnSync } from "node:child_process";
import {
  chmodSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readSync,
  renameSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";

type ObjectValue = Record<string, unknown>;
function object(value: unknown): value is ObjectValue {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

export function mergePreferences(live: ObjectValue, desired: ObjectValue): ObjectValue {
  const result = { ...live };
  for (const [key, value] of Object.entries(desired)) {
    result[key] = object(value) ? mergePreferences(object(live[key]) ? live[key] : {}, value) : value;
  }
  return result;
}

export function differingKeys(live: ObjectValue, desired: ObjectValue, prefix = ""): string[] {
  return Object.entries(desired).flatMap(([key, value]) => {
    const name = prefix + key;
    return object(value)
      ? differingKeys(object(live[key]) ? live[key] : {}, value, name + ".")
      : JSON.stringify(live[key]) === JSON.stringify(value)
      ? []
      : [name];
  });
}

function leafPaths(value: ObjectValue, prefix: string[] = []): string[][] {
  return Object.entries(value).flatMap(([key, child]) =>
    object(child) ? leafPaths(child, [...prefix, key]) : [[...prefix, key]]
  );
}

function at(value: ObjectValue, keys: string[]): unknown {
  let current: unknown = value;
  for (const key of keys) {
    if (!object(current)) return undefined;
    current = current[key];
  }
  return current;
}

function set(value: ObjectValue, keys: string[], replacement: unknown): void {
  let current = value;
  for (const key of keys.slice(0, -1)) {
    if (!object(current[key])) current[key] = {};
    current = current[key] as ObjectValue;
  }
  current[keys.at(-1)!] = replacement;
}

function keyText(key: string): string {
  return /^[A-Za-z0-9_-]+$/.test(key) ? key : JSON.stringify(key);
}

function shownFile(path: string): string {
  return path.startsWith(homedir() + "/") ? "~" + path.slice(homedir().length) : path;
}

function answerLine(): string {
  const byte = Buffer.alloc(1);
  let answer = "";
  while (readSync(0, byte, 0, 1, null) === 1 && byte[0] !== 10) answer += byte.toString();
  return answer.trim().toLowerCase();
}

function savePreferences(file: string, desired: ObjectValue, name: string): ObjectValue {
  let live: ObjectValue;
  try {
    const stat = lstatSync(file);
    if (!stat.isFile()) throw new Error("Expected a regular writable app config");
    const parsed: unknown = JSON.parse(readFileSync(file, "utf8"));
    if (!object(parsed)) throw new Error("Expected a JSON object");
    live = parsed;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") {
      console.log(`${name}: live preferences absent; no values imported`);
      return desired;
    }
    throw error;
  }
  const next = structuredClone(desired);
  for (const keys of leafPaths(desired)) {
    if (keys.some((part) => /password|secret|token|credential|auth|session|private/i.test(part))) {
      console.log(`${name}.${keys.join(".")}: skipped local or potentially sensitive key`);
      continue;
    }
    const current = at(live, keys);
    const previous = at(desired, keys);
    if (current === undefined || JSON.stringify(current) === JSON.stringify(previous)) continue;
    if (!process.stdin.isTTY) throw new Error("Save requires an interactive terminal");
    // Name the leaf by its full path in config/app-preferences.json.
    console.log([name, "settings", ...keys].map(keyText).join("."));
    console.log(`  repo: ${JSON.stringify(previous)}`);
    console.log(`  Mac:  ${JSON.stringify(current)}  (${shownFile(file)})`);
    process.stdout.write("Promote this local value into the repo? [y/N] ");
    if (["y", "yes"].includes(answerLine())) set(next, keys, current);
  }
  return next;
}

export function syncFile(file: string, desired: ObjectValue, apply: boolean, running: () => boolean): string[] {
  let live: ObjectValue = {};
  let mode = 0o600;
  try {
    const stat = lstatSync(file);
    if (!stat.isFile()) throw new Error("Expected a regular writable app config (not a symlink)");
    mode = stat.mode & 0o777;
    const parsed: unknown = JSON.parse(readFileSync(file, "utf8"));
    if (!object(parsed)) throw new Error("Expected a JSON object");
    live = parsed;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
  }
  const differences = differingKeys(live, desired);
  if (!apply || differences.length === 0) return differences;
  if (running()) {
    throw new Error("Quit Claude before applying its pending preferences, then rerun just apply-to-machine");
  }
  mkdirSync(dirname(file), { recursive: true });
  const temporary = file + `.machine-${process.pid}.tmp`;
  try {
    writeFileSync(temporary, JSON.stringify(mergePreferences(live, desired), null, 2) + "\n", {
      flag: "wx",
      mode: 0o600,
    });
    chmodSync(temporary, mode);
    renameSync(temporary, file);
  } finally {
    try {
      unlinkSync(temporary);
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    }
  }
  return differences;
}

if (import.meta.main) {
  const mode = process.argv[2] ?? "check";
  // apply-unless-running is the partial apply: Claude rewrites this file on quit, so a
  // write while it runs would be lost; leave those keys reported as pending instead.
  if (!["apply", "apply-unless-running", "check", "save"].includes(mode)) {
    throw new Error("usage: app-preferences.ts [check|apply|apply-unless-running|save]");
  }
  const repo = resolve(import.meta.dir, "..");
  const manifestPath = join(repo, "config/app-preferences.json");
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8")) as Record<
    string,
    { path: string; process: string; settings: ObjectValue }
  >;
  let failed = false;
  let saved = false;
  for (const [name, target] of Object.entries(manifest)) {
    try {
      if (mode === "save") {
        const next = savePreferences(join(process.env.MACHINE_HOME ?? homedir(), target.path), target.settings, name);
        if (JSON.stringify(next) !== JSON.stringify(target.settings)) {
          target.settings = next;
          saved = true;
        }
        continue;
      }
      const running = () => {
        const expression = "^" + target.process.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "( |$)";
        // -a: macOS pgrep otherwise skips its ancestors, missing Claude when run from Claude Code.
        const result = spawnSync("pgrep", ["-a", "-f", expression]);
        if (result.status !== 0 && result.status !== 1) {
          throw new Error("Could not determine whether Claude is running");
        }
        return result.status === 0;
      };
      const writes = mode === "apply" || (mode === "apply-unless-running" && !running());
      const differences = syncFile(
        join(process.env.MACHINE_HOME ?? homedir(), target.path),
        target.settings,
        writes,
        running,
      );
      if (!writes) {
        if (mode === "apply-unless-running" && differences.length > 0) {
          console.log(`[PENDING] ${name}: Claude is running; run just apply-to-machine to restart it and apply`);
        }
        if (differences.length === 0) continue;
        const file = join(process.env.MACHINE_HOME ?? homedir(), target.path);
        const live = existsSync(file) ? JSON.parse(readFileSync(file, "utf8")) as ObjectValue : {};
        for (const key of differences) {
          const keys = key.split(".");
          const current = at(live, keys);
          const desired = at(target.settings, keys);
          const sensitive = /password|secret|token|credential|auth|session|private/i.test(key);
          const shown = (value: unknown) =>
            sensitive ? "<redacted>" : value === undefined ? "<unset>" : JSON.stringify(value);
          console.log(`[DIFF] ${name}.${key}: current=${shown(current)} -> repo=${shown(desired)}`);
        }
      } else {
        console.log(
          `[${differences.length ? "APPLIED" : "MATCH"}] ${name}${
            differences.length ? ": " + differences.join(", ") : ""
          }`,
        );
      }
    } catch (error) {
      failed = true;
      // Avoid emitting parse errors containing private JSON fragments.
      console.error(
        `[UNKNOWN] ${name}: ${
          error instanceof SyntaxError ? "Invalid private JSON; left untouched" : (error as Error).message
        }`,
      );
    }
  }
  if (mode === "save" && saved) writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n");
  if (mode === "save") console.log("Reviewed only declared app preference keys; app-owned fields were not copied.");
  if (mode !== "check" && failed) process.exitCode = 1;
}
