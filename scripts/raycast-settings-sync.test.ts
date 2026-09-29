import { expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

test("Raycast confirmation check uses a saved native export when present", () => {
  const root = mkdtempSync(join(tmpdir(), "machine-raycast-sync-"));
  try {
    const config = join(root, "config/raycast");
    const state = join(root, "state/machine");
    mkdirSync(config, { recursive: true });
    mkdirSync(state, { recursive: true });
    writeFileSync(join(config, "settings.json"), "{}\n");
    const native = Buffer.from([0x45, 0x82, 0x37, 0x4a]);
    writeFileSync(join(config, "settings-native.rayconfig"), native);
    const hash = createHash("sha256").update(native).digest("hex");
    writeFileSync(join(state, "raycast-settings-confirmed.sha256"), `${hash}\n`);
    const result = Bun.spawnSync(["bash", join(import.meta.dir, "raycast-settings-sync.sh"), root, "check"], {
      env: { ...process.env, XDG_STATE_HOME: join(root, "state") },
      stdout: "pipe",
      stderr: "pipe",
    });
    expect(result.exitCode).toBe(0);
    expect(result.stdout.toString()).toContain("matches the last confirmed import");
  } finally {
    rmSync(root, { recursive: true });
  }
});
