import { expect, test } from "bun:test";
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

test("Raycast native sync stays paused during the Spotlight trial", () => {
  const root = mkdtempSync(join(tmpdir(), "machine-raycast-sync-"));
  try {
    const config = join(root, "config/raycast");
    mkdirSync(config, { recursive: true });
    writeFileSync(join(config, "settings.json"), "{}\n");
    writeFileSync(join(config, "settings-native.rayconfig"), Buffer.from([0x45, 0x82, 0x37, 0x4a]));
    for (const mode of ["check", ""]) {
      const result = Bun.spawnSync(["bash", join(import.meta.dir, "raycast-settings-sync.sh"), root, mode], {
        env: { ...process.env, XDG_STATE_HOME: join(root, "state") },
        stdout: "pipe",
        stderr: "pipe",
      });
      expect(result.exitCode).toBe(0);
      expect(result.stdout.toString()).toContain("[PAUSED]");
    }
    expect(existsSync(join(config, "settings.rayconfig"))).toBe(false);
    expect(existsSync(join(root, "state/machine/raycast-settings-confirmed.sha256"))).toBe(false);
  } finally {
    rmSync(root, { recursive: true });
  }
});
