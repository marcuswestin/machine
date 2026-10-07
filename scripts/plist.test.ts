import { expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parsePlistXml, PlistData, plistEqual, readPlist } from "./plist";

const sample = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>a &amp; b</key>
\t<string>&lt;x&gt; &#233;</string>
\t<key>count</key>
\t<integer>-3</integer>
\t<key>ratio</key>
\t<real>1.5</real>
\t<key>on</key>
\t<true/>
\t<key>empty</key>
\t<string/>
\t<key>list</key>
\t<array>
\t\t<false/>
\t\t<dict/>
\t\t<array/>
\t</array>
\t<key>when</key>
\t<date>2024-01-02T03:04:05Z</date>
\t<key>blob</key>
\t<data>
\tAAH/
\t</data>
\t<key>zoom</key>
\t<string>^@\r</string>
</dict>
</plist>
`;

test("parses every XML plist value type", () => {
  const value = parsePlistXml(sample) as Record<string, unknown>;
  expect(value["a & b"]).toBe("<x> é");
  expect(value.count).toBe(-3);
  expect(value.ratio).toBe(1.5);
  expect(value.on).toBe(true);
  expect(value.empty).toBe("");
  expect(value.list).toEqual([false, {}, []]);
  expect((value.when as Date).toISOString()).toBe("2024-01-02T03:04:05.000Z");
  expect((value.blob as PlistData).hex).toBe("0001ff");
  // Raw CR is preserved, as plutil writes Return-key shortcuts.
  expect(value.zoom).toBe("^@\r");
});

test("rejects malformed plists", () => {
  expect(() => parsePlistXml("<dict></dict>")).toThrow("expected <plist>");
  expect(() => parsePlistXml("<plist><dict><string>x</string></dict></plist>")).toThrow("expected <key>");
  expect(() => parsePlistXml("<plist><widget/></plist>")).toThrow("unsupported");
});

test("compares values like Python plist equality", () => {
  expect(plistEqual({ a: [1, "x"], b: true }, { b: true, a: [1, "x"] })).toBe(true);
  expect(plistEqual(true, 1)).toBe(true);
  expect(plistEqual(false, 1)).toBe(false);
  expect(plistEqual(1, 1.0)).toBe(true);
  expect(plistEqual({ a: 1 }, { a: 1, b: 2 })).toBe(false);
  expect(plistEqual(new PlistData("00"), new PlistData("00"))).toBe(true);
  expect(plistEqual(new PlistData("00"), "0x00")).toBe(false);
  expect(plistEqual(new Date(0), new Date(0))).toBe(true);
});

test("reads binary plists through plutil", () => {
  const dir = mkdtempSync(join(tmpdir(), "machine-plist-"));
  try {
    const file = join(dir, "sample.plist");
    writeFileSync(file, sample);
    expect(spawnSync("/usr/bin/plutil", ["-convert", "binary1", file]).status).toBe(0);
    expect(readPlist(file)).toEqual(parsePlistXml(sample));
  } finally {
    rmSync(dir, { recursive: true });
  }
});
