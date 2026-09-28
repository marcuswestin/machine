#!/usr/bin/env bun
// Merge only repo-declared Codex leaves into this user's writable config.
// Leave project trust, local hooks, app paths, credentials, and unknown keys alone.
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

type Json = null | boolean | number | string | Json[] | { [key: string]: Json };
type Leaf = { path: string[]; value: Json };
const repo = resolve(process.env.MACHINE_REPO ?? join(import.meta.dir, ".."));
const source = join(repo, "config/codex/config.toml");
const home = process.env.MACHINE_HOME ?? homedir();
const target = join(home, ".codex/config.toml");

function parseToml(text: string): Record<string, Json> {
  const result = spawnSync("taplo", ["get", "-o", "json"], { input: text, encoding: "utf8" });
  if (result.status !== 0) throw new Error("Invalid Codex TOML; left untouched");
  return JSON.parse(result.stdout) as Record<string, Json>;
}

function leaves(value: Record<string, Json>, path: string[] = []): Leaf[] {
  return Object.entries(value).flatMap(([key, child]) =>
    child !== null && typeof child === "object" && !Array.isArray(child)
      ? leaves(child, [...path, key])
      : [{ path: [...path, key], value: child }]
  );
}

function at(value: Record<string, Json>, path: string[]): Json | undefined {
  let item: Json | undefined = value;
  for (const key of path) {
    if (item === null || typeof item !== "object" || Array.isArray(item)) return undefined;
    item = item[key];
  }
  return item;
}

function dotted(path: string[]): string {
  return path.join(".");
}
function safeImport(path: string[]): boolean {
  return !path.some((part) =>
    /token|secret|password|auth|credential|header|env|notify|project|hook|marketplace/i.test(part)
  )
    && path[0] !== "mcp_servers";
}

function splitPath(input: string): string[] {
  const parts = input.match(/"(?:\\.|[^"\\])*"|'[^']*'|[^.\s]+/g) ?? [];
  return parts.map((part) =>
    part.startsWith("\"") ? JSON.parse(part) as string : part.startsWith("'") ? part.slice(1, -1) : part
  );
}
function keyText(key: string): string {
  return /^[A-Za-z0-9_-]+$/.test(key) ? key : JSON.stringify(key);
}
function tomlValue(value: Json): string {
  if (typeof value === "string") {
    return JSON.stringify(value).replace(
      /\\u([0-9a-fA-F]{4})/g,
      (_, digits: string) => String.fromCharCode(parseInt(digits, 16)),
    );
  }
  if (typeof value === "boolean" || typeof value === "number") return String(value);
  if (Array.isArray(value)) return `[${value.map(tomlValue).join(", ")}]`;
  throw new Error("Only scalar and scalar-array Codex settings can be merged");
}

function setLeaf(text: string, leaf: Leaf): string {
  const lines = text === "" ? [] : text.trimEnd().split("\n");
  const table = leaf.path.slice(0, -1);
  const key = leaf.path.at(-1)!;
  let active: string[] = [];
  let tableStart = table.length === 0 ? 0 : -1;
  let tableEnd = lines.length;
  let keyLine = -1;
  for (let i = 0; i < lines.length; i++) {
    const header = lines[i]!.trim().match(/^\[([^\[\]]+)\]$/);
    if (header) {
      if (tableStart >= 0 && tableEnd === lines.length && active.join("\0") === table.join("\0")) tableEnd = i;
      active = splitPath(header[1]!);
      if (active.join("\0") === table.join("\0")) tableStart = i;
      continue;
    }
    const assignment = lines[i]!.match(/^\s*("(?:\\.|[^"\\])*"|'[^']*'|[A-Za-z0-9_-]+)\s*=/);
    if (assignment && [...active, ...splitPath(assignment[1]!)].join("\0") === leaf.path.join("\0")) keyLine = i;
  }
  const assignment = `${keyText(key)} = ${tomlValue(leaf.value)}`;
  if (keyLine >= 0) {
    // A multi-line TOML value cannot be replaced safely with this line editor.
    if (/=\s*(\[\s*$|"""|'''|\{\s*$)/.test(lines[keyLine]!)) {
      throw new Error(`Cannot merge multiline value: ${dotted(leaf.path)}`);
    }
    lines[keyLine] = assignment;
  } else if (tableStart >= 0) {
    lines.splice(tableEnd, 0, assignment);
  } else {
    if (lines.length) lines.push("");
    lines.push(`[${table.map(keyText).join(".")}]`, assignment);
  }
  const output = lines.join("\n") + "\n";
  parseToml(output);
  return output;
}

function atomicWrite(path: string, contents: string, mode: number): void {
  mkdirSync(dirname(path), { recursive: true });
  const temporary = `${path}.machine-${process.pid}.tmp`;
  try {
    writeFileSync(temporary, contents, { flag: "wx", mode });
    chmodSync(temporary, mode);
    renameSync(temporary, path);
  } finally {
    if (existsSync(temporary)) unlinkSync(temporary);
  }
}

function answerLine(): string {
  const byte = Buffer.alloc(1);
  let value = "";
  while (readSync(0, byte, 0, 1, null) === 1 && byte[0] !== 10) value += byte.toString();
  return value.trim().toLowerCase();
}

function main(): void {
  const mode = process.argv[2] ?? "check";
  if (!["check", "preflight", "apply", "save"].includes(mode)) {
    throw new Error("usage: codex-config-sync.ts [check|preflight|apply|save]");
  }
  const managedText = readFileSync(source, "utf8");
  const managed = parseToml(managedText);
  const stat = existsSync(target) ? lstatSync(target) : null;
  if (stat && !stat.isFile()) throw new Error("Codex user config must be a regular file; left untouched");
  const liveText = stat ? readFileSync(target, "utf8") : "";
  const live = liveText ? parseToml(liveText) : {};
  const expected = leaves(managed);
  const conflicts = expected.filter(({ path, value }) => {
    const current = at(live, path);
    return current !== undefined && JSON.stringify(current) !== JSON.stringify(value);
  });
  const missing = expected.filter(({ path }) => at(live, path) === undefined);
  if (mode === "check") {
    console.log(
      `Codex user config: ${
        expected.length - conflicts.length - missing.length
      } matching, ${missing.length} missing, ${conflicts.length} conflicting managed keys.`,
    );
    for (const item of [...missing, ...conflicts]) {
      console.log(`  ${at(live, item.path) === undefined ? "MISSING" : "CONFLICT"} ${dotted(item.path)}`);
    }
    return;
  }
  if (mode === "preflight") {
    if (conflicts.length) {
      console.error("Codex managed-key conflicts; run just save-machine-settings to review:");
      for (const item of conflicts) console.error(`  ${dotted(item.path)}`);
      process.exitCode = 1;
    }
    return;
  }
  if (mode === "apply" && conflicts.length) {
    console.error(
      "Codex UI changed repo-managed settings. Run just save-machine-settings to review them, then rerun just apply:",
    );
    for (const item of conflicts) console.error(`  ${dotted(item.path)}`);
    process.exitCode = 1;
    return;
  }
  if (mode === "save") {
    let next = managedText;
    for (const item of conflicts) {
      if (!safeImport(item.path)) {
        console.log(`SKIP ${dotted(item.path)}: local or potentially sensitive setting`);
        continue;
      }
      if (!process.stdin.isTTY) throw new Error("Save requires an interactive terminal; no values were imported");
      console.log(`  repo: ${JSON.stringify(item.value)}\n  Mac:  ${JSON.stringify(at(live, item.path))}`);
      process.stdout.write(`Promote local ${dotted(item.path)} into the repo? [y/N] `);
      const answer = answerLine();
      if (answer === "y" || answer === "yes") next = setLeaf(next, { path: item.path, value: at(live, item.path)! });
    }
    if (next !== managedText) atomicWrite(source, next, lstatSync(source).mode & 0o777);
    console.log("Codex import reviewed. Inspect git diff before applying; unlisted local keys were untouched.");
    return;
  }
  let next = liveText;
  for (const item of missing) next = setLeaf(next, item);
  if (next !== liveText) atomicWrite(target, next, stat ? stat.mode & 0o777 : 0o600);
  console.log(`Codex user config: ${missing.length} managed keys applied; all other keys preserved.`);
}

if (import.meta.main) {
  try {
    main();
  } catch (error) {
    console.error((error as Error).message);
    process.exitCode = 1;
  }
}
