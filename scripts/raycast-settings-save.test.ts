import { expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { gzipSync } from "node:zlib";

test("Raycast export parser changes no repo data without explicit interactive review", () => {
  const root = mkdtempSync(join(tmpdir(), "machine-raycast-save-"));
  try {
    mkdirSync(join(root, "config/raycast"), { recursive: true });
    const repoFile = join(root, "config/raycast/settings.json");
    const source = {
      builtin_package_raycastPreferences: { preferencesAppearance: { raycastPreferredWindowMode: "compact" } },
      account: { token: "local-secret" },
    };
    writeFileSync(repoFile, JSON.stringify(source));
    const exportFile = join(root, "export.rayconfig");
    writeFileSync(exportFile, gzipSync(JSON.stringify(source)));
    const env = { ...process.env, MACHINE_REPO: root };
    const unchanged = Bun.spawnSync(["bun", join(import.meta.dir, "raycast-settings-save.ts"), exportFile], {
      env,
      stdout: "pipe",
      stderr: "pipe",
    });
    expect(unchanged.exitCode).toBe(0);
    const changedExport = structuredClone(source);
    changedExport.builtin_package_raycastPreferences.preferencesAppearance.raycastPreferredWindowMode = "large";
    writeFileSync(exportFile, gzipSync(JSON.stringify(changedExport)));
    const changed = Bun.spawnSync(["bun", join(import.meta.dir, "raycast-settings-save.ts"), exportFile], {
      env,
      stdout: "pipe",
      stderr: "pipe",
    });
    expect(changed.exitCode).not.toBe(0);
    expect(readFileSync(repoFile, "utf8")).toBe(JSON.stringify(source));
    writeFileSync(exportFile, Buffer.from([0x45, 0x82, 0x37, 0x4a]));
    const encrypted = Bun.spawnSync(["bun", join(import.meta.dir, "raycast-settings-save.ts"), exportFile], {
      env,
      stdout: "pipe",
      stderr: "pipe",
    });
    expect(encrypted.exitCode).not.toBe(0);
    expect(encrypted.stderr.toString()).toContain("requires interactive review");
    expect(readFileSync(repoFile, "utf8")).toBe(JSON.stringify(source));
  } finally {
    rmSync(root, { recursive: true });
  }
});
