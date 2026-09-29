import { expect, test } from "bun:test";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

test("Docker access denial fails apply and remains unverified in reports", () => {
  const root = mkdtempSync(join(tmpdir(), "machine-docker-permissions-"));
  const home = join(root, "home");
  const repo = join(root, "repo");
  const live = join(home, "Library/Group Containers/group.com.docker/settings-store.json");
  const desired = join(repo, "home/.dotfiles/docker/settings-store.json");
  try {
    mkdirSync(dirname(live), { recursive: true });
    mkdirSync(dirname(desired), { recursive: true });
    writeFileSync(live, "{\"privateFixture\":true}", { mode: 0o000 });
    writeFileSync(desired, "{\"setting\":true}");
    const run = (args: string[]) =>
      Bun.spawnSync([process.execPath, join(import.meta.dir, "repo-settings-import.ts"), repo, ...args], {
        env: { ...process.env, HOME: home },
        stdout: "pipe",
        stderr: "pipe",
      });
    const apply = run(["--push-docker-live"]);
    expect(apply.exitCode).toBe(1);
    expect(apply.stderr.toString()).toContain("permission denied");
    const report = run([]);
    expect(report.stdout.toString()).toContain("docker-settings-store: UNVERIFIED (permission denied)");
    const rows = JSON.parse(run(["--json"]).stdout.toString());
    expect(rows.find((row: { id: string }) => row.id === "docker-settings-store").status).toBe("permission_denied");
    chmodSync(live, 0o600);
    expect(readFileSync(live, "utf8")).toBe("{\"privateFixture\":true}");
  } finally {
    chmodSync(live, 0o600);
    rmSync(root, { recursive: true });
  }
});

test("single-target import leaves other repo settings untouched", () => {
  const root = mkdtempSync(join(tmpdir(), "machine-targeted-import-"));
  const home = join(root, "home");
  const repo = join(root, "repo");
  const live = join(home, ".cursor/cli-config.json");
  const desired = join(repo, "home/.dotfiles/cursor/cli-config.json");
  const other = join(repo, "home/.dotfiles/handy/settings_store.json");
  try {
    for (const file of [live, desired, other]) mkdirSync(dirname(file), { recursive: true });
    writeFileSync(live, "{\"shared\":\"machine\",\"new\":true}");
    writeFileSync(desired, "{\"shared\":\"repo\"}");
    writeFileSync(other, "{\"unrelated\":true}");
    const run = (args: string[]) =>
      Bun.spawnSync([process.execPath, join(import.meta.dir, "repo-settings-import.ts"), repo, ...args], {
        env: { ...process.env, HOME: home },
        stdout: "pipe",
        stderr: "pipe",
      });
    const report = JSON.parse(run(["--only", "cursor-cli-config", "--json"]).stdout.toString());
    expect(report).toHaveLength(1);
    expect(report[0].only_live_keys).toEqual(["new"]);
    expect(run(["--only", "cursor-cli-config", "--write-lossy"]).exitCode).toBe(0);
    expect(JSON.parse(readFileSync(desired, "utf8"))).toEqual({ shared: "repo", new: true });
    expect(readFileSync(other, "utf8")).toBe("{\"unrelated\":true}");
    expect(run(["--only", "unknown", "--write-lossy"]).exitCode).toBe(2);
    expect(run(["--only", "cursor-cli-config", "--push-docker-live"]).exitCode).toBe(2);
  } finally {
    rmSync(root, { recursive: true });
  }
});
