#!/usr/bin/env bun
// Save a user-confirmed Settings-only native export, or promote declared
// preference leaves from the older JSON export format.
import { copyFileSync, readFileSync, readSync, writeFileSync } from "node:fs";
import { extname, join, resolve } from "node:path";
import { gunzipSync } from "node:zlib";

type JsonObject = Record<string, unknown>;
function object(value: unknown): value is JsonObject {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
function leaves(value: JsonObject, prefix: string[] = []): string[][] {
  return Object.entries(value).flatMap(([key, child]) =>
    object(child) ? leaves(child, [...prefix, key]) : [[...prefix, key]]
  );
}
function at(value: JsonObject, keys: string[]): unknown {
  let current: unknown = value;
  for (const key of keys) {
    if (!object(current)) return undefined;
    current = current[key];
  }
  return current;
}
function set(value: JsonObject, keys: string[], replacement: unknown): void {
  let current = value;
  for (const key of keys.slice(0, -1)) current = current[key] as JsonObject;
  current[keys.at(-1)!] = replacement;
}
function answerLine(): string {
  const byte = Buffer.alloc(1);
  let answer = "";
  while (readSync(0, byte, 0, 1, null) === 1 && byte[0] !== 10) answer += byte.toString();
  return answer.trim().toLowerCase();
}

const source = process.argv[2];
if (!source) throw new Error("usage: raycast-settings-save.ts <native-export.rayconfig|json>");
const repoFile = join(resolve(process.env.MACHINE_REPO ?? join(import.meta.dir, "..")), "config/raycast/settings.json");
const current = JSON.parse(readFileSync(repoFile, "utf8")) as JsonObject;
const contents = readFileSync(resolve(source));
// Native Raycast exports are encrypted binary files. Raycast itself must import
// them; the old gzip JSON format below is the repo's own generated fallback.
if (extname(source) === ".rayconfig" && !(contents[0] === 0x1f && contents[1] === 0x8b)) {
  if (!process.stdin.isTTY) {
    throw new Error("Encrypted Raycast export requires interactive review; repo left untouched");
  }
  console.log("Native encrypted Raycast export detected. Its contents cannot be inspected here.");
  console.log("Confirm that ONLY \"Settings (including aliases, hotkeys & favorites)\" was selected in Raycast.");
  console.log("This repo and its export password are public, so treat the export as public data.");
  process.stdout.write("Save this native Settings export in the repo? Type yes: ");
  if (answerLine() !== "yes") throw new Error("Raycast export was not saved");
  const nativeFile = join(
    resolve(process.env.MACHINE_REPO ?? join(import.meta.dir, "..")),
    "config/raycast/settings-native.rayconfig",
  );
  copyFileSync(resolve(source), nativeFile);
  console.log(`Saved native Raycast Settings export: ${nativeFile}`);
  process.exit(0);
}
const exported = JSON.parse(
  extname(source) === ".rayconfig" ? gunzipSync(contents).toString("utf8") : contents.toString("utf8"),
) as JsonObject;
if (!object(exported) || !object(exported.builtin_package_raycastPreferences)) {
  throw new Error("Export lacks the expected Raycast preferences section; repo left untouched");
}
if (!object(current.builtin_package_raycastPreferences)) throw new Error("Repo preferences section is invalid");
const next = structuredClone(current);
const saved = next.builtin_package_raycastPreferences as JsonObject;
const live = exported.builtin_package_raycastPreferences as JsonObject;
let changed = 0;
for (const keys of leaves(saved)) {
  if (keys.some((part) => /password|secret|token|credential|auth|private/i.test(part))) continue;
  const previous = at(saved, keys);
  const value = at(live, keys);
  if (value === undefined || JSON.stringify(value) === JSON.stringify(previous)) continue;
  if (object(value) || Array.isArray(value)) continue;
  if (!process.stdin.isTTY) throw new Error("Raycast save requires an interactive terminal; repo left untouched");
  console.log(`${keys.join(".")}\n  repo: ${JSON.stringify(previous)}\n  Mac:  ${JSON.stringify(value)}`);
  process.stdout.write("Promote this Raycast preference? [y/N] ");
  if (["y", "yes"].includes(answerLine())) {
    set(saved, keys, value);
    changed++;
  }
}
if (changed) writeFileSync(repoFile, JSON.stringify(next, null, 2) + "\n");
console.log(`Promoted ${changed} declared Raycast preferences. Extensions and personal data were not copied.`);
