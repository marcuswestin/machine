#!/usr/bin/env bun
// Operational checks only: no activation, downloads, repairs, or consent changes.
import { spawnSync } from "node:child_process";
import { existsSync, lstatSync, readFileSync, realpathSync } from "node:fs";
import { basename, join, resolve } from "node:path";

type Status = "OK" | "WARN" | "FAIL" | "UNKNOWN";
type Finding = { check: string; status: Status; detail: string; action?: string };
type Result = { status: Status; detail: string; action?: string };

export function backgroundStatus(label: string, serviceStatus: string): Result {
  if (serviceStatus === "enabled") return { status: "OK", detail: `${label}: enabled and eligible to run` };
  if (serviceStatus === "requiresApproval") {
    return {
      status: "FAIL",
      detail: `${label}: requires approval`,
      action:
        "Review System Settings → General → Login Items & Extensions; enable the corresponding machine background item.",
    };
  }
  if (serviceStatus === "notRegistered") {
    return { status: "FAIL", detail: `${label}: not registered`, action: "Run just apply-to-machine." };
  }
  return { status: "UNKNOWN", detail: `${label}: authorization status ${serviceStatus || "missing"} is unverified` };
}

export function launchdStatus(text: string): Result {
  const state = text.match(/^\s*state = (.+)$/m)?.[1];
  const exit = text.match(/^\s*last exit code = (-?\d+)/m)?.[1];
  if (exit !== undefined && exit !== "0") {
    return {
      status: "FAIL",
      detail: `registered; last exit code ${exit}`,
      action: "Inspect launchctl print and the service logs before applying again.",
    };
  }
  // These are RunAtLoad jobs. A successful one-shot normally says 'not running'.
  if (state === "running" || exit === "0") {
    return { status: "OK", detail: `registered; ${state}; last exit ${exit ?? "not yet recorded"}` };
  }
  return { status: "UNKNOWN", detail: `registered; ${state ?? "unknown state"}; no successful completion recorded` };
}

export function hasMappings(
  text: string,
  mappings: { HIDKeyboardModifierMappingSrc: number; HIDKeyboardModifierMappingDst: number }[],
): boolean {
  // hidutil prints a mapping per HID service, with decimal or hexadecimal codes.
  const pairs = [...text.matchAll(/\{([^{}]*)\}/g)].map(m => ({
    src: Number(m[1].match(/HIDKeyboardModifierMappingSrc\s*=\s*(0x[\da-f]+|\d+)/i)?.[1]),
    dst: Number(m[1].match(/HIDKeyboardModifierMappingDst\s*=\s*(0x[\da-f]+|\d+)/i)?.[1]),
  }));
  if (mappings.length === 0) return !pairs.some(p => Number.isFinite(p.src) && Number.isFinite(p.dst));
  return mappings.every(m =>
    pairs.some(p => p.src === m.HIDKeyboardModifierMappingSrc && p.dst === m.HIDKeyboardModifierMappingDst)
  );
}

export function exitCode(findings: Result[]): number {
  return findings.some(f => f.status === "FAIL") ? 1 : findings.some(f => f.status !== "OK") ? 2 : 0;
}

export function appArtifactPath(artifact: unknown[], appdir: string): string | undefined {
  const source = artifact[0];
  if (typeof source !== "string") return undefined;
  const options = artifact[1] as { target?: string } | undefined;
  // A cask's source may be nested inside its archive; Homebrew installs its basename.
  const target = options?.target ?? basename(source);
  return target.startsWith("/") ? target : join(appdir, target);
}

function main() {
  const args = process.argv.slice(2);
  if (args.some(a => a !== "--json")) {
    console.error("Usage: just check machine [--json]");
    process.exitCode = 64;
    return;
  }
  const repo = resolve(import.meta.dir, "..");
  const home = process.env.HOME!;
  const host = process.env.MACHINE_HOST ?? "machine";
  const findings: Finding[] = [];
  function run(command: string, args: string[]) {
    const r = spawnSync(command, args, {
      cwd: repo,
      env: { ...process.env, HOMEBREW_NO_AUTO_UPDATE: "1", HOMEBREW_NO_ANALYTICS: "1" },
      encoding: "utf8",
      timeout: 60_000,
      maxBuffer: 4 * 1024 * 1024,
    });
    if (r.error) throw r.error;
    return { code: r.status, out: r.stdout.trim(), error: r.stderr.trim() };
  }
  function required(command: string, args: string[]) {
    const r = run(command, args);
    if (r.code !== 0) throw new Error(`${command}: ${r.error || r.out || `exit ${r.code}`}`);
    return r.out;
  }
  function check(name: string, fn: () => Result) {
    try {
      findings.push({ check: name, ...fn() });
    } catch (e) {
      findings.push({
        check: name,
        status: "UNKNOWN",
        detail: String(e).slice(0, 700),
        action: "Run just check machine in a normal Terminal if access was denied; inspect the reported error.",
      });
    }
  }
  function symlink(name: string, path: string, target: string) {
    check(name, () => {
      let matches = false;
      try {
        matches = lstatSync(path).isSymbolicLink() && realpathSync(path) === realpathSync(target);
      } catch (e) {
        if ((e as NodeJS.ErrnoException).code !== "ENOENT") throw e;
      }
      return matches
        ? { status: "OK", detail: "managed symlink resolves to the repository" }
        : {
          status: "FAIL",
          detail: "managed symlink is missing, broken, or differs",
          action: "Run just apply-to-machine dotfiles; reopen affected apps afterward.",
        };
    });
  }
  function script(name: string, path: string, args: string[], action: string) {
    check(name, () => {
      const r = run("bash", [join(repo, "scripts", path), ...args]);
      return {
        status: /Operation not permitted|Permission denied|not authorized/i.test(r.out + r.error)
          ? "UNKNOWN"
          : r.code === 0
          ? "OK"
          : "FAIL",
        detail: r.out || r.error || "check passed",
        ...(r.code !== 0 ? { action } : {}),
      };
    });
  }

  check("macOS baseline", () => {
    const r = run("bash", ["up.sh", "--check-os"]);
    return {
      status: r.code !== 0 ? "FAIL" : r.out ? "WARN" : "OK",
      detail: r.out || r.error || `macOS ${required("sw_vers", ["-productVersion"])} matches the repo baseline`,
    };
  });
  check("Nix activation", () => {
    if (!existsSync("/run/current-system")) {
      return {
        status: "FAIL",
        detail: "/run/current-system is missing",
        action: "Review machine-nix-boot background permission, then run just apply-to-machine.",
      };
    }
    const active = realpathSync("/run/current-system");
    const selected = realpathSync("/nix/var/nix/profiles/system");
    return {
      status: active === selected ? "OK" : "FAIL",
      detail: active === selected
        ? "active generation matches the selected system profile (not a build comparison with Git)"
        : "active and selected generations differ",
      ...(active !== selected ? { action: "Run just apply-to-machine." } : {}),
    };
  });
  const uid = Number(required("id", ["-u"]));
  for (
    const [label, domain] of [["org.nixos.activate-system", "system"], [
      "org.nixos.machine-login-startup",
      `gui/${uid}`,
    ]]
  ) {
    check(label, () => {
      const r = run("launchctl", ["print", `${domain}/${label}`]);
      if (r.code !== 0 && /Could not find service/.test(r.error)) {
        return {
          status: "FAIL",
          detail: "service is not registered",
          action: "Review Background App Activity permission, then run just apply-to-machine.",
        };
      }
      if (r.code !== 0) throw new Error(r.error || r.out);
      return launchdStatus(r.out);
    });
  }
  check("Background permissions", () => {
    const labels = ["org.nixos.activate-system", "org.nixos.machine-login-startup"];
    const statuses = required("/usr/bin/swift", [
      resolve(repo, "scripts/background-permissions.swift"),
      "/Library/LaunchDaemons/org.nixos.activate-system.plist",
      join(home, "Library/LaunchAgents/org.nixos.machine-login-startup.plist"),
    ]).split("\n");
    if (statuses.length !== labels.length) throw new Error("Service Management returned an incomplete status list");
    const results = labels.map((label, index) => backgroundStatus(label, statuses[index]));
    const problem = results.find(r => r.status === "FAIL") ?? results.find(r => r.status !== "OK");
    return { status: problem?.status ?? "OK", detail: results.map(r => r.detail).join("; "), action: problem?.action };
  });

  let declared: any;
  check("Repository declarations", () => {
    declared = JSON.parse(
      required("nix", [
        "eval",
        "--extra-experimental-features",
        "nix-command flakes",
        "--offline",
        "--no-write-lock-file",
        "--json",
        `${repo}#darwinConfigurations.${host}.config`,
        "--apply",
        "c: { inherit (c.machine) startupApps; inherit (c.system) keyboard; inherit (c.homebrew) casks brews; }",
      ]),
    );
    return { status: "OK", detail: `${host}: evaluated locked declarations without fetching inputs` };
  });
  if (declared) {
    check("Keyboard mapping", () => {
      if (!declared.keyboard.enableKeyMapping) return { status: "OK", detail: "nix-darwin key mapping is not enabled" };
      const mappings = declared.keyboard.userKeyMapping;
      const found = hasMappings(required("hidutil", ["property", "--get", "UserKeyMapping"]), mappings);
      return {
        status: found ? "OK" : "FAIL",
        detail: found
          ? mappings.length === 0
            ? "no hidutil mappings active; test Karabiner's Caps Lock tap/hold behavior physically"
            : "declared mappings found in HID service output; physical keyboard behavior not tested"
          : "HID service mappings do not match the declarations",
        ...(!found ? { action: "Run just apply-to-machine and test the physical keyboard." } : {}),
      };
    });
    check("Startup applications", () => {
      const stopped: string[] = [];
      for (const app of declared.startupApps) {
        const r = run("pgrep", ["-x", basename(app.executable)]);
        if (r.code === 1) stopped.push(app.name);
        else if (r.code !== 0) throw new Error(r.error);
      }
      return {
        status: stopped.length ? "WARN" : "OK",
        detail: stopped.length
          ? `not running: ${stopped.join(", ")} (may have been quit intentionally)`
          : `${declared.startupApps.length} declared startup apps are running`,
        ...(stopped.length
          ? { action: "Open the apps you need; a process check does not verify app functionality." }
          : {}),
      };
    });
    check("Homebrew declarations", () => {
      const prefix = required("brew", ["--prefix"]);
      const formulae = new Set(
        required("brew", ["list", "--formula", "--versions"]).split("\n").map(l => l.split(" ")[0].split("/").pop()),
      );
      const missing: string[] = [];
      for (const formula of declared.brews) {
        if (!formulae.has(formula.name.split("/").pop())) missing.push(`formula ${formula.name}`);
      }
      let bundles = 0;
      for (const cask of declared.casks) {
        const receipt = join(prefix, "Caskroom", cask.name.split("/").pop(), ".metadata/INSTALL_RECEIPT.json");
        if (!existsSync(receipt)) {
          missing.push(`cask receipt ${cask.name}`);
          continue;
        }
        for (const artifact of JSON.parse(readFileSync(receipt, "utf8")).uninstall_artifacts ?? []) {
          // Only app artifacts have a recorded destination; pkg installers are not covered.
          if (!artifact.app) continue;
          const path = appArtifactPath(artifact.app, cask.args?.appdir ?? "/Applications");
          if (!path) throw new Error(`Unrecognized app artifact for ${cask.name}`);
          bundles++;
          if (!existsSync(path)) missing.push(path);
        }
      }
      return {
        status: missing.length ? "WARN" : "OK",
        detail: missing.length
          ? `missing: ${missing.join(", ")}`
          : `${declared.brews.length} formulae, ${declared.casks.length} cask receipts, ${bundles} recorded app paths present`,
        ...(missing.length
          ? {
            action:
              "Inspect missing packages or moved app bundles before reinstalling; just apply-to-machine does not repair stale receipts.",
          }
          : {}),
      };
    });
  } else {
    for (const name of ["Keyboard mapping", "Startup applications", "Homebrew declarations"]) {
      findings.push({ check: name, status: "UNKNOWN", detail: "could not evaluate declarations" });
    }
  }
  script("Editor symlinks", "check-vscode-family-symlinks.sh", [repo], "Run just apply-to-machine dotfiles.");
  symlink(
    "Handy settings",
    join(home, "Library/Application Support/com.pais.handy/settings_store.json"),
    join(repo, "home/.dotfiles/handy/settings_store.json"),
  );
  script("Handy model", "setup-handy.sh", [repo, "check"], "Run just apply-to-machine dotfiles, then reopen Handy.");
  check("Karabiner settings", () => {
    const live = join(home, ".config/karabiner/karabiner.json");
    const source = join(repo, "home/.dotfiles/karabiner/karabiner.json");
    try {
      if (lstatSync(live).isFile() && readFileSync(live).equals(readFileSync(source))) {
        return { status: "OK", detail: "regular config file matches the repository" };
      }
    } catch (e) {
      if ((e as NodeJS.ErrnoException).code !== "ENOENT") throw e;
    }
    return {
      status: "FAIL",
      detail: "regular config file is missing, is a symlink, or differs from the repository",
      action: "Run just apply-to-machine dotfiles so Karabiner can detect future config changes.",
    };
  });
  check("AeroSpace config", () => {
    const active = required("aerospace", ["config", "--config-path"]);
    return realpathSync(active) === realpathSync(join(repo, "home/.dotfiles/aerospace.toml"))
      ? { status: "OK", detail: "server responds and uses the repo config path; unsaved/reload drift is not verified" }
      : {
        status: "FAIL",
        detail: "server uses another config path",
        action: "Inspect aerospace config --config-path and the chezmoi symlink.",
      };
  });
  check("Codex configuration", () => {
    const output = required("bash", ["scripts/check-codex-config.sh", repo]);
    const drift = /^\[DIFF\] codex\./m.test(output);
    return {
      status: drift ? "WARN" : "OK",
      detail: output || "Managed Codex keys match",
      ...(drift
        ? { action: "Review with just import-from-machine; run just apply-to-machine for missing managed keys." }
        : {}),
    };
  });
  check("Thaw confirmation", () => {
    const output = required("bash", ["scripts/thaw-profile-sync.sh", "check"]);
    const pending = output.includes("[DIFF] thaw.profile.confirmedSha256:");
    return {
      status: pending ? "WARN" : "OK",
      detail: output || "Saved profile matches its last confirmed apply",
      ...(pending
        ? { action: "Run just apply-to-machine and complete or confirm the native Thaw profile apply." }
        : {}),
    };
  });
  check("Time Machine", () => {
    // Destination inventory only: do not mount a backup disk to inspect its history.
    const r = run("tmutil", ["destinationinfo"]);
    if (/No destinations configured/.test(r.out + r.error)) {
      return {
        status: "WARN",
        detail: "no Time Machine destination configured; other backup tools are not assessed",
        action: "Confirm your backup strategy; configure Time Machine if wanted.",
      };
    }
    if (r.code !== 0) throw new Error(r.error || r.out);
    return {
      status: "UNKNOWN",
      detail: "Time Machine destination configured; backup freshness and restore success not verified",
    };
  });
  const counts = Object.fromEntries(
    ["OK", "WARN", "FAIL", "UNKNOWN"].map(s => [s, findings.filter(f => f.status === s).length]),
  );
  const report = {
    timestamp: new Date().toISOString(),
    host,
    counts,
    findings,
    scope:
      "Operational health only; no vulnerability/advisory scan, full app-version audit, or physical input/restore test.",
  };
  if (args.includes("--json")) console.log(JSON.stringify(report, null, 2));
  else {
    console.log(`Machine doctor — ${host} — ${report.timestamp}\n`);
    for (const f of findings) {
      console.log(`[${f.status}] ${f.check}: ${f.detail.replaceAll("\n", "\n    ")}`);
      if (f.action) console.log(`    Next: ${f.action}`);
    }
    console.log(
      `\nSummary: ${counts.OK} OK, ${counts.WARN} warnings, ${counts.FAIL} failures, ${counts.UNKNOWN} unverified.`,
    );
    console.log(report.scope);
    console.log("No settings changed. For security advisories and upgrade review, use the review-machine-repo skill.");
  }
  process.exitCode = exitCode(findings);
}

if (import.meta.main) main();
