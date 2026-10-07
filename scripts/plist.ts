#!/usr/bin/env bun
// Read macOS property lists without Python. plutil (built into macOS) turns any
// plist, binary or XML, into XML; parsePlistXml reads that. plutil's own JSON
// conversion is not enough: it rejects the Data and Date values that real
// preference files contain (for example Stats' file-dialog bookmarks).
import { spawnSync } from "node:child_process";

// Data values compare and print as hex, matching how [DIFF] lines show them.
export class PlistData {
  constructor(readonly hex: string) {}
  toJSON(): string {
    return "0x" + this.hex;
  }
}
export type PlistValue = string | number | boolean | Date | PlistData | PlistValue[] | { [key: string]: PlistValue };

const token = /<!--[\s\S]*?-->|<\?[\s\S]*?\?>|<!DOCTYPE[^>]*>|<(\/?)([A-Za-z]+)[^>]*?(\/?)>|([^<]+)/g;
type Token = { close: boolean; name: string; empty: boolean } | { text: string };

function decode(text: string): string {
  return text.replace(/&(lt|gt|amp|quot|apos|#x[0-9A-Fa-f]+|#[0-9]+);/g, (_, entity: string) => {
    if (entity[0] === "#") {
      return String.fromCodePoint(entity[1] === "x" ? parseInt(entity.slice(2), 16) : parseInt(entity.slice(1), 10));
    }
    return { lt: "<", gt: ">", amp: "&", quot: "\"", apos: "'" }[entity]!;
  });
}

export function parsePlistXml(xml: string): PlistValue {
  // Raw CRs are kept (plutil writes Return-key shortcuts that way), unlike a
  // spec XML parser, so file contents round-trip exactly.
  const tokens: Token[] = [];
  for (const match of xml.matchAll(token)) {
    if (match[2]) tokens.push({ close: match[1] === "/", name: match[2], empty: match[3] === "/" });
    else if (match[4] !== undefined) tokens.push({ text: match[4] });
  }
  let index = 0;
  const skipSpace = () => {
    while (index < tokens.length && "text" in tokens[index] && !(tokens[index] as { text: string }).text.trim()) {
      index++;
    }
  };
  const open = (): { name: string; empty: boolean } => {
    skipSpace();
    const next = tokens[index++];
    if (!next || "text" in next || next.close) throw new Error("Invalid plist: expected an element");
    return next;
  };
  const closeTag = (name: string) => {
    skipSpace();
    const next = tokens[index++];
    if (!next || "text" in next || !next.close || next.name !== name) {
      throw new Error(`Invalid plist: expected </${name}>`);
    }
  };
  const text = (tag: { name: string; empty: boolean }): string => {
    if (tag.empty) return "";
    let value = "";
    while (index < tokens.length && "text" in tokens[index]) value += (tokens[index++] as { text: string }).text;
    closeTag(tag.name);
    return decode(value);
  };
  const atClose = (name: string): boolean => {
    skipSpace();
    const next = tokens[index];
    return !!next && !("text" in next) && next.close && next.name === name;
  };
  const value = (): PlistValue => {
    const tag = open();
    switch (tag.name) {
      case "dict": {
        const result: { [key: string]: PlistValue } = {};
        if (tag.empty) return result;
        while (!atClose("dict")) {
          const key = open();
          if (key.name !== "key") throw new Error("Invalid plist: expected <key>");
          const name = text(key);
          result[name] = value();
        }
        closeTag("dict");
        return result;
      }
      case "array": {
        const result: PlistValue[] = [];
        if (tag.empty) return result;
        while (!atClose("array")) result.push(value());
        closeTag("array");
        return result;
      }
      case "string":
        return text(tag);
      case "integer":
      case "real":
        return Number(text(tag));
      case "true":
      case "false":
        if (!tag.empty) closeTag(tag.name);
        return tag.name === "true";
      case "date":
        return new Date(text(tag));
      case "data":
        return new PlistData(Buffer.from(text(tag).replace(/\s+/g, ""), "base64").toString("hex"));
      default:
        throw new Error(`Invalid plist: unsupported <${tag.name}>`);
    }
  };
  const root = open();
  if (root.name !== "plist") throw new Error("Invalid plist: expected <plist>");
  if (root.empty) throw new Error("Invalid plist: empty <plist>");
  const result = value();
  closeTag("plist");
  return result;
}

// Read a plist file, or stdin bytes when path is "-".
export function readPlist(path: string, input?: Buffer): PlistValue {
  const result = spawnSync("/usr/bin/plutil", ["-convert", "xml1", "-o", "-", path], { input, encoding: "utf8" });
  if (result.status !== 0) throw new Error(`plutil could not read ${path}: ${result.stderr.trim()}`);
  return parsePlistXml(result.stdout);
}

export function isPlistDict(value: PlistValue | undefined): value is { [key: string]: PlistValue } {
  return typeof value === "object" && value !== null && !Array.isArray(value) && !(value instanceof Date)
    && !(value instanceof PlistData);
}

// Booleans equal 1/0, as they do for defaults written as either type.
export function plistEqual(a: PlistValue | undefined, b: PlistValue | undefined): boolean {
  if (typeof a === "boolean" && typeof b === "number") return Number(a) === b;
  if (typeof a === "number" && typeof b === "boolean") return a === Number(b);
  if (a instanceof Date || b instanceof Date) {
    return a instanceof Date && b instanceof Date && a.getTime() === b.getTime();
  }
  if (a instanceof PlistData || b instanceof PlistData) {
    return a instanceof PlistData && b instanceof PlistData && a.hex === b.hex;
  }
  if (Array.isArray(a) || Array.isArray(b)) {
    return Array.isArray(a) && Array.isArray(b) && a.length === b.length
      && a.every((item, i) => plistEqual(item, b[i]));
  }
  if (isPlistDict(a) && isPlistDict(b)) {
    const keys = Object.keys(a);
    return keys.length === Object.keys(b).length && keys.every((key) => key in b && plistEqual(a[key], b[key]));
  }
  return a === b;
}

// usage: plist.ts json [file|-] prints the plist as JSON (Data as "0x…" hex).
if (import.meta.main) {
  const [mode, path = "-"] = process.argv.slice(2);
  if (mode !== "json") throw new Error("usage: plist.ts json [file|-]");
  const input = path === "-" ? Buffer.from(await new Response(Bun.stdin.stream()).arrayBuffer()) : undefined;
  console.log(JSON.stringify(readPlist(path, input)));
}
