import { expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync, statSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { syncFile } from "./app-preferences";

test("partial nested preferences preserve private state; second apply does not rewrite", () => {
  const dir = mkdtempSync(join(tmpdir(), "machine-preferences-"));
  try {
    const file = join(dir, "config.json");
    const live = { token: "fixture", preferences: { secret: "fixture", theme: "light" } };
    const desired = { preferences: { theme: "system" } };
    writeFileSync(file, JSON.stringify(live), { mode: 0o600 });
    expect(syncFile(file, desired, false, () => true)).toEqual(["preferences.theme"]);
    expect(JSON.parse(readFileSync(file, "utf8"))).toEqual(live);
    expect(() => syncFile(file, desired, true, () => true)).toThrow("Quit Claude");
    syncFile(file, desired, true, () => false);
    expect(JSON.parse(readFileSync(file, "utf8"))).toEqual({
      ...live,
      preferences: { secret: "fixture", theme: "system" },
    });
    const stamp = statSync(file).mtimeMs;
    expect(syncFile(file, desired, true, () => true)).toEqual([]);
    expect(statSync(file).mtimeMs).toBe(stamp);
    expect(statSync(file).mode & 0o777).toBe(0o600);
  } finally {
    rmSync(dir, { recursive: true });
  }
});

test("invalid JSON and symlinks remain untouched; missing files can be initialized", () => {
  const dir = mkdtempSync(join(tmpdir(), "machine-preferences-"));
  try {
    const bad = join(dir, "bad.json");
    writeFileSync(bad, "{invalid");
    expect(() => syncFile(bad, { theme: "system" }, true, () => false)).toThrow();
    expect(readFileSync(bad, "utf8")).toBe("{invalid");
    const link = join(dir, "link.json");
    symlinkSync(bad, link);
    expect(() => syncFile(link, {}, true, () => false)).toThrow("regular");
    const fresh = join(dir, "new/config.json");
    syncFile(fresh, { theme: "system" }, true, () => false);
    expect(JSON.parse(readFileSync(fresh, "utf8"))).toEqual({ theme: "system" });
  } finally {
    rmSync(dir, { recursive: true });
  }
});
