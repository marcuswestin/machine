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
  return {
    root,
    home,
    run,
    source: () => readFileSync(join(repo, "config/codex/config.toml"), "utf8"),
    read: () => readFileSync(join(home, ".codex/config.toml"), "utf8"),
  };
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

test("apply overwrites differing managed values from repo and preserves local keys", () => {
  const f = fixture(
    "[desktop]\nprimary-number-shortcut-target = \"sidebar\"\n",
    "[desktop]\nprimary-number-shortcut-target = \"tabs\"\n[projects.\"/tmp/local\"]\ntrust_level = \"trusted\"\n",
  );
  try {
    const source = f.source();
    const result = f.run("apply");
    expect(result.exitCode).toBe(0);
    expect(f.read()).toContain("primary-number-shortcut-target = \"sidebar\"");
    expect(f.read()).toContain("trust_level = \"trusted\"");
    expect(f.source()).toBe(source);
    const once = f.read();
    expect(f.run("apply").exitCode).toBe(0);
    expect(f.read()).toBe(once);
  } finally {
    rmSync(f.root, { recursive: true });
  }
});

test("preflight validates noninteractively without mutating either file", () => {
  const f = fixture("service_tier = \"priority\"\n", "service_tier = \"default\"\n");
  try {
    const source = f.source();
    const live = f.read();
    const result = f.run("preflight");
    expect(result.exitCode).toBe(0);
    expect(result.stdout.toString()).toContain("1 managed keys will be applied from the repo");
    expect(f.source()).toBe(source);
    expect(f.read()).toBe(live);
  } finally {
    rmSync(f.root, { recursive: true });
  }
});
