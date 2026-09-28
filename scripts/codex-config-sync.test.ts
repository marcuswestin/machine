import { expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

function fixture(managed: string, live: string) {
  const root = mkdtempSync(join(tmpdir(), "machine-codex-sync-"));
  const repo = join(root, "repo");
  const home = join(root, "home");
  mkdirSync(join(repo, "config/codex"), { recursive: true });
  mkdirSync(join(home, ".codex"), { recursive: true });
  writeFileSync(join(repo, "config/codex/config.toml"), managed);
  writeFileSync(join(home, ".codex/config.toml"), live);
  const run = (mode: string) =>
    Bun.spawnSync(["bun", join(import.meta.dir, "codex-config-sync.ts"), mode], {
      env: { ...process.env, MACHINE_REPO: repo, MACHINE_HOME: home },
      stdout: "pipe",
      stderr: "pipe",
    });
  return { root, home, run, read: () => readFileSync(join(home, ".codex/config.toml"), "utf8") };
}

test("merges only managed leaves, keeps local trust and is idempotent", () => {
  const f = fixture(
    "model = \"gpt-6-sol\"\n[desktop]\nprimary-number-shortcut-target = \"sidebar\"\n",
    "model = \"gpt-6-sol\"\n[projects.\"/tmp/local\"]\ntrust_level = \"trusted\"\n",
  );
  try {
    expect(f.run("apply").exitCode).toBe(0);
    expect(f.read()).toContain("primary-number-shortcut-target = \"sidebar\"");
    expect(f.read()).toContain("trust_level = \"trusted\"");
    const once = f.read();
    expect(f.run("apply").exitCode).toBe(0);
    expect(f.read()).toBe(once);
  } finally {
    rmSync(f.root, { recursive: true });
  }
});

test("conflicting UI value blocks apply without changing the local file", () => {
  const f = fixture(
    "[desktop]\nprimary-number-shortcut-target = \"sidebar\"\n",
    "[desktop]\nprimary-number-shortcut-target = \"tabs\"\n[projects.\"/tmp/local\"]\ntrust_level = \"trusted\"\n",
  );
  try {
    const before = f.read();
    const result = f.run("apply");
    expect(result.exitCode).toBe(1);
    expect(result.stderr.toString()).toContain("primary-number-shortcut-target");
    expect(f.read()).toBe(before);
  } finally {
    rmSync(f.root, { recursive: true });
  }
});
