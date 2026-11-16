#!/usr/bin/env bun
// Read-only benchmark status; prepare quits only declared optional startup apps.
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

export type TimingApp = { name: string; bundleIdentifier: string; executable: string };
export type TimingProcess = { pid: number; cpuPercent: number; executable: string };
export type TimingSample = {
  onAcPower: boolean;
  powerMode: number;
  cpuIdlePercent: number;
  thermalWarning: boolean;
  optionalApps: { name: string; bundleIdentifier: string; pids: number[] }[];
  otherBusyProcesses: TimingProcess[];
};
type Finding = { check: string; status: "OK" | "WARN"; detail: string };
const MinimumIdlePercent = 95;
const BusyProcessPercent = 10;
const ProcessRow = /^\s*(\d+)\s+([\d.]+)\s+(.+)$/;
const CpuIdle = /CPU usage:[^\n]*?([\d.]+)% idle/g;
const AcPowerMode = /AC Power:\s*\n[\s\S]*?\bpowermode\s+(\d+)/;
const ThermalWarnings = /(?:thermal|performance) warning level (?:has been recorded|=\s*[1-9])/i;

function output(repo: string, command: string, args: string[]): string {
  const result = spawnSync(command, args, { cwd: repo, encoding: "utf8", timeout: 60_000, maxBuffer: 4 * 1024 * 1024 });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(command + ": " + (result.stderr.trim() || result.stdout.trim() || result.status));
  }
  return result.stdout.trim();
}

export function parseTimingProcesses(text: string): TimingProcess[] {
  return text.split("\n").filter(line => line.trim()).map(line => {
    const fields = line.match(ProcessRow);
    if (!fields) throw new Error("Unrecognized process inventory row: " + line);
    return { pid: Number(fields[1]), cpuPercent: Number(fields[2]), executable: fields[3] };
  });
}

export function readTimingSample(
  apps: TimingApp[],
  processes: TimingProcess[],
  cpu: string,
  battery: string,
  power: string,
  thermal: string,
): TimingSample {
  const idle = [...cpu.matchAll(CpuIdle)].at(-1)?.[1];
  const mode = power.match(AcPowerMode)?.[1];
  if (idle === undefined || mode === undefined) {
    throw new Error("Power or CPU evidence is incomplete; readiness is unverified.");
  }
  const noWarnings = thermal.includes("No thermal warning level has been recorded")
    && thermal.includes("No performance warning level has been recorded");
  const thermalWarning = thermal.split("\n").some(line => !line.includes("No ") && ThermalWarnings.test(line));
  if (!noWarnings && !thermalWarning) throw new Error("Thermal readiness is unverified: " + thermal);
  const optionalApps = apps.map(app => ({
    name: app.name,
    bundleIdentifier: app.bundleIdentifier,
    pids: processes.filter(process => process.executable === app.executable).map(process => process.pid),
  }));
  const optionalPids = new Set(optionalApps.flatMap(app => app.pids));
  const otherBusyProcesses = processes.filter(process =>
    process.cpuPercent >= BusyProcessPercent && !optionalPids.has(process.pid)
  );
  return {
    onAcPower: battery.includes("Now drawing from 'AC Power'"),
    powerMode: Number(mode),
    cpuIdlePercent: Number(idle),
    thermalWarning,
    optionalApps,
    otherBusyProcesses,
  };
}

export function timingFindings(sample: TimingSample): Finding[] {
  const running = sample.optionalApps.filter(app => app.pids.length);
  return [
    {
      check: "Power",
      status: sample.onAcPower && sample.powerMode === 0 ? "OK" : "WARN",
      detail: "AC=" + sample.onAcPower + ", AC power mode=" + sample.powerMode,
    },
    {
      check: "CPU",
      status: sample.cpuIdlePercent >= MinimumIdlePercent ? "OK" : "WARN",
      detail: sample.cpuIdlePercent + "% idle in the final sampled interval",
    },
    {
      check: "Thermal",
      status: sample.thermalWarning ? "WARN" : "OK",
      detail: sample.thermalWarning ? "recorded warning" : "no recorded thermal/performance warnings",
    },
    {
      check: "Optional startup apps",
      status: running.length ? "WARN" : "OK",
      detail: running.length ? running.map(app => app.name).join(", ") : "all declared startup utilities are stopped",
    },
    {
      check: "Other busy processes",
      status: sample.otherBusyProcesses.length ? "WARN" : "OK",
      detail: sample.otherBusyProcesses.length
        ? sample.otherBusyProcesses.map(process =>
          process.pid + " " + process.executable + " (" + process.cpuPercent + "%)"
        ).join("; ")
        : "none at or above " + BusyProcessPercent + "% of one CPU in the process snapshot",
    },
  ];
}

function declaredApps(repo: string): TimingApp[] {
  const host = process.env.MACHINE_HOST ?? "machine";
  const value: unknown = JSON.parse(output(repo, "nix", [
    "eval",
    "--extra-experimental-features",
    "nix-command flakes",
    "--offline",
    "--no-write-lock-file",
    "--json",
    repo + "#darwinConfigurations." + host + ".config.machine.startupApps",
  ]));
  return selectTimingApps(value);
}

export function selectTimingApps(value: unknown): TimingApp[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw new Error("No declared optional startup apps; nothing will be terminated.");
  }
  for (const app of value) {
    if (
      !app || typeof app.name !== "string" || typeof app.bundleIdentifier !== "string"
      || typeof app.executable !== "string"
      || !app.executable.startsWith("/Applications/")
    ) {
      throw new Error("Invalid startup app declaration; nothing will be terminated.");
    }
  }
  const selected = value.filter(app => app.timingOptional === true);
  if (selected.length === 0) {
    throw new Error("No startup apps are explicitly timing-optional; nothing will be terminated.");
  }
  return selected as TimingApp[];
}

function inspect(repo: string, apps: TimingApp[]) {
  // The observer's own startup CPU is not competing background work.
  const processes = parseTimingProcesses(output(repo, "/bin/ps", ["-axo", "pid=,%cpu=,comm="]))
    .filter(candidate => candidate.pid !== process.pid);
  const cpu = output(repo, "/usr/bin/top", ["-l", "2", "-s", "1", "-n", "1", "-o", "cpu", "-stats", "pid,command,cpu"]);
  const battery = output(repo, "/usr/bin/pmset", ["-g", "batt"]);
  const power = output(repo, "/usr/bin/pmset", ["-g", "custom"]);
  const thermal = output(repo, "/usr/bin/pmset", ["-g", "therm"]);
  const sample = readTimingSample(apps, processes, cpu, battery, power, thermal);
  const findings = timingFindings(sample);
  return {
    timestamp: new Date().toISOString(),
    ready: findings.every(finding => finding.status === "OK"),
    sample,
    findings,
  };
}

export function runTimingMachine(args: string[], repo = resolve(import.meta.dir, "..")): void {
  const action = args[0] ?? "status";
  if (!["status", "prepare"].includes(action) || args.slice(1).some(arg => arg !== "--json")) {
    throw new Error("Usage: just timing [status|prepare] [--json]; just check machine --timing [--json]");
  }
  const apps = declaredApps(repo);
  const before = inspect(repo, apps);
  let shutdown: unknown = undefined;
  if (action === "prepare") {
    const active = before.sample.optionalApps.filter(app => app.pids.length);
    shutdown = active.length
      ? JSON.parse(output(repo, "/usr/bin/swift", [
        resolve(repo, "scripts/timing-quit-apps.swift"),
        ...active.map(app => app.bundleIdentifier),
      ]))
      : [];
  }
  const report = action === "prepare" ? inspect(repo, apps) : before;
  const result = { action, ...report, ...(action === "prepare" ? { before, shutdown, restore: false } : {}) };
  if (args.includes("--json")) console.log(JSON.stringify(result, null, 2));
  else {
    console.log("Timing readiness — " + report.timestamp);
    for (const finding of report.findings) {
      console.log("[" + finding.status + "] " + finding.check + ": " + finding.detail);
    }
    if (action === "prepare") {
      console.log("Requested declared startup utilities to quit. They will not be restored automatically.");
    }
    console.log(
      "This is a short readiness sample, not proof of isolation throughout a benchmark. Other apps/services are untouched.",
    );
  }
  process.exitCode = report.ready ? 0 : 2;
}

if (import.meta.main) {
  try {
    runTimingMachine(process.argv.slice(2));
  } catch (error) {
    console.error(String(error));
    process.exitCode = 1;
  }
}
