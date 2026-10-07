#!/usr/bin/env bun
// Report only differing declared CustomUserPreferences keys and values.
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import { isPlistDict, parsePlistXml, PlistData, plistEqual, type PlistValue } from "./plist";

const repo = resolve(import.meta.dir, "..");
const host = process.argv[2] ?? process.env.MACHINE_HOST ?? "machine";
const evaluated = spawnSync("nix", [
  "--extra-experimental-features",
  "nix-command flakes",
  "--option",
  "warn-dirty",
  "false",
  "eval",
  "--offline",
  "--no-write-lock-file",
  "--json",
  `${repo}#darwinConfigurations.${host}.config.system.defaults.CustomUserPreferences`,
], { encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] });
if (evaluated.status !== 0) {
  console.error("Could not evaluate declared CustomUserPreferences");
  process.exit(1);
}
const declared = JSON.parse(evaluated.stdout) as Record<string, Record<string, PlistValue>>;

// Return-key shortcuts may be stored as CR or LF depending on how they were
// written. Compare with both sides normalized to LF so neither is reported as drift.
function lineEnds(value: PlistValue): PlistValue {
  if (typeof value === "string") return value.replace(/\r\n?/g, "\n");
  if (Array.isArray(value)) return value.map(lineEnds);
  if (isPlistDict(value)) return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, lineEnds(v)]));
  return value;
}

function sorted(value: PlistValue): unknown {
  if (Array.isArray(value)) return value.map(sorted);
  if (isPlistDict(value)) return Object.fromEntries(Object.keys(value).sort().map((key) => [key, sorted(value[key])]));
  return value;
}

function shown(key: string, value: PlistValue): string {
  if (/password|secret|token|credential|auth|session|private/i.test(key)) return "<redacted>";
  if (value instanceof PlistData) return "0x" + value.hex;
  return JSON.stringify(sorted(value));
}

for (const domain of Object.keys(declared).sort()) {
  const expected = lineEnds(declared[domain]) as Record<string, PlistValue>;
  const result = spawnSync("defaults", ["export", domain, "-"], { encoding: "utf8" });
  if (result.status !== 0) {
    console.log(`[UNVERIFIED] ${domain}: preferences absent or unreadable`);
    continue;
  }
  let actual: PlistValue;
  try {
    actual = parsePlistXml(result.stdout);
  } catch (error) {
    console.log(`[UNVERIFIED] ${domain}: invalid plist (${(error as Error).message})`);
    continue;
  }
  actual = lineEnds(actual);
  if (!isPlistDict(actual)) {
    console.log(`[UNVERIFIED] ${domain}: invalid plist (top level is not a dictionary)`);
    continue;
  }
  for (const [key, value] of Object.entries(expected)) {
    if (key in actual && plistEqual(actual[key], value)) continue;
    const current = key in actual ? shown(key, actual[key]) : "<unset>";
    console.log(`[DIFF] ${domain}.${key}: current=${current} -> repo=${shown(key, value)}`);
  }
}
