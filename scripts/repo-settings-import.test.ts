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
