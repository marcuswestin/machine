import { expect, test } from "bun:test";
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

function fixture() {
  const root = mkdtempSync(join(tmpdir(), "machine-full-apply-"));
  const bin = join(root, "bin");
  const scripts = join(root, "scripts");
  mkdirSync(bin);
  mkdirSync(scripts);
  for (const name of ["settings-apply.sh", "settings-prompt.sh"]) {
    cpSync(join(import.meta.dir, name), join(scripts, name));
  }
  const log = join(root, "calls");
  writeFileSync(join(bin, "bun"), "#!/bin/bash\nprintf 'bun %s\\n' \"$*\" >> \"$TEST_LOG\"\n", { mode: 0o755 });
  writeFileSync(
    join(bin, "just"),
    `#!/bin/bash
printf 'just %s\\n' "$*" >> "$TEST_LOG"
if [[ "$1" == _restart-plan ]]; then printf '%s\\n' "\${MOCK_PLAN:-}"; fi
if [[ "$1" == apply && "\${FAIL_APPLY:-}" == 1 ]]; then exit 1; fi
`,
    { mode: 0o755 },
  );
  writeFileSync(join(bin, "open"), "#!/bin/bash\nprintf 'open %s\\n' \"$*\" >> \"$TEST_LOG\"\n", { mode: 0o755 });
  writeFileSync(join(bin, "pgrep"), "#!/bin/bash\nexit 1\n", { mode: 0o755 });
  writeFileSync(
    join(bin, "osascript"),
    `#!/bin/bash
app="\${@: -1}"
if [[ " $* " == *"to quit"* ]]; then
  printf 'quit %s\\n' "$app" >> "$TEST_LOG"
  touch "$TEST_ROOT/quit-$app"
elif [[ "\${FAIL_STATUS:-}" == "$app" ]]; then
  exit 1
elif [[ "\${MOCK_RUNNING:-}" == 1 && ! -e "$TEST_ROOT/quit-$app" ]]; then
  printf 'running\\n'
else
  printf 'stopped\\n'
fi
`,
    { mode: 0o755 },
  );
  const env = {
    ...process.env,
    PATH: bin + ":" + process.env.PATH,
    TEST_LOG: log,
    TEST_ROOT: root,
    MACHINE_SKIP_DOCKER: "0",
    MACHINE_APPLY_MODE: "basic",
    MACHINE_RESTART_STRICT: "0",
    MACHINE_SETTINGS_INTERACTIVE: "1",
    TERM_PROGRAM: "Apple_Terminal",
  };
  const run = (input: string, extra: Record<string, string> = {}) =>
    Bun.spawnSync(["bash", join(scripts, "settings-apply.sh")], {
      env: { ...env, ...extra },
      stdin: Buffer.from(input),
      stdout: "pipe",
      stderr: "pipe",
    });
  return { root, run, calls: () => existsSync(log) ? readFileSync(log, "utf8") : "" };
}

test("full apply quits and restores only changed running apps", () => {
  const f = fixture();
  try {
    const result = f.run("\n\n", { MOCK_PLAN: "Claude\nStats", MOCK_RUNNING: "1" });
    expect(result.exitCode).toBe(0);
    const calls = f.calls();
    expect(calls.indexOf("quit Claude")).toBeLessThan(calls.indexOf("just apply"));
    expect(calls.indexOf("quit Stats")).toBeLessThan(calls.indexOf("just apply"));
    expect(calls.indexOf("just apply")).toBeLessThan(calls.indexOf("open -gj -a Claude"));
    expect(calls).not.toContain("quit Docker");
    expect(calls).not.toContain("open -gj -a Cursor");
    expect(calls).toContain("just settings-check");
    expect(result.stdout.toString()).toContain("7. Docker: after it starts");
  } finally {
    rmSync(f.root, { recursive: true });
  }
});

test("dormant affected apps stay closed", () => {
  const f = fixture();
  try {
    expect(f.run("\n\n", { MOCK_PLAN: "Stats" }).exitCode).toBe(0);
    expect(f.calls()).not.toContain("quit Stats");
    expect(f.calls()).not.toContain("open -gj -a Stats");
  } finally {
    rmSync(f.root, { recursive: true });
  }
});

test("explicit Docker skip never quits Docker", () => {
  const f = fixture();
  try {
    const result = f.run("\n\n", {
      MOCK_PLAN: "Docker\nStats",
      MOCK_RUNNING: "1",
      MACHINE_SKIP_DOCKER: "1",
    });
    expect(result.exitCode).toBe(0);
    expect(result.stdout.toString()).toContain("Docker settings and Docker restart are skipped");
    expect(result.stdout.toString()).toContain("Docker settings were skipped by MACHINE_SKIP_DOCKER=1");
    expect(result.stdout.toString()).not.toContain("7. Docker: after it starts");
    expect(f.calls()).not.toContain("quit Docker");
    expect(f.calls()).not.toContain("open -gj -a Docker");
    expect(f.calls()).toContain("quit Stats");
  } finally {
    rmSync(f.root, { recursive: true });
  }
});

test("EOF before start does not apply, and unknown app status stops before mutation", () => {
  const f = fixture();
  try {
    expect(f.run("", { MOCK_PLAN: "Stats" }).exitCode).toBe(1);
    expect(f.calls()).not.toContain("just apply");
    const result = f.run("\n", { MOCK_PLAN: "Stats", FAIL_STATUS: "Stats" });
    expect(result.exitCode).toBe(1);
    expect(result.stderr.toString()).toContain("Could not check whether Stats is running");
    expect(f.calls()).not.toContain("just apply");
  } finally {
    rmSync(f.root, { recursive: true });
  }
});

test("failed apply restores previously running affected apps", () => {
  const f = fixture();
  try {
    expect(f.run("\n", { MOCK_PLAN: "Docker", MOCK_RUNNING: "1", FAIL_APPLY: "1" }).exitCode).toBe(1);
    const calls = f.calls();
    expect(calls.indexOf("quit Docker")).toBeLessThan(calls.indexOf("just apply"));
    expect(calls.indexOf("just apply")).toBeLessThan(calls.indexOf("open -gj -a Docker"));
    expect(calls).not.toContain("just settings-check");
  } finally {
    rmSync(f.root, { recursive: true });
  }
});

test("current terminal app prevents self-termination", () => {
  const f = fixture();
  try {
    const result = f.run("\n", { MOCK_PLAN: "iTerm", TERM_PROGRAM: "iTerm.app" });
    expect(result.exitCode).toBe(2);
    expect(f.calls()).not.toContain("just apply");
  } finally {
    rmSync(f.root, { recursive: true });
  }
});
