import { expect, test } from "bun:test";
import { parseTimingProcesses, readTimingSample, selectTimingApps, timingFindings } from "./timing-machine";

const apps = [{
  name: "Stats",
  bundleIdentifier: "eu.exelban.Stats",
  executable: "/Applications/Stats.app/Contents/MacOS/Stats",
}];
const cpu = "CPU usage: 1% user, 1% sys, 98% idle\nCPU usage: 0.5% user, 0.5% sys, 99% idle";
const battery = "Now drawing from 'AC Power'";
const power = "Battery Power:\n powermode 1\nAC Power:\n powermode 0";
const thermal = "No thermal warning level has been recorded\nNo performance warning level has been recorded";

test("timing shutdown eligibility requires an explicit declaration", () => {
  const network = {
    name: "Network",
    bundleIdentifier: "example.network",
    executable: "/Applications/Network.app/Contents/MacOS/Network",
  };
  expect(selectTimingApps([{ ...apps[0], timingOptional: true }, network])).toEqual([
    { ...apps[0], timingOptional: true },
  ]);
  expect(() => selectTimingApps([network])).toThrow("explicitly timing-optional");
  expect(() => selectTimingApps([{ ...network, executable: "/usr/sbin/sshd", timingOptional: true }])).toThrow(
    "Invalid",
  );
  expect(() => selectTimingApps([null])).toThrow("Invalid");
});

test("timing readiness identifies exact declared executables without matching other names", () => {
  const processes = parseTimingProcesses(
    " 42 4.2 /Applications/Stats.app/Contents/MacOS/Stats\n 43 0.0 /tmp/Stats\n 44 20.0 /tmp/build worker",
  );
  const sample = readTimingSample(apps, processes, cpu, battery, power, thermal);
  expect(sample.optionalApps[0].pids).toEqual([42]);
  expect(sample.otherBusyProcesses.map(process => process.pid)).toEqual([44]);
  expect(sample.cpuIdlePercent).toBe(99);
  expect(timingFindings(sample).filter(finding => finding.status === "WARN").map(finding => finding.check)).toEqual([
    "Optional startup apps",
    "Other busy processes",
  ]);
});

test("timing status does not certify missing CPU or thermal evidence", () => {
  expect(() => readTimingSample(apps, [], "", battery, power, thermal)).toThrow("incomplete");
  expect(() => readTimingSample(apps, [], cpu, battery, power, "permission denied")).toThrow("unverified");
  expect(() => parseTimingProcesses("unrecognized output")).toThrow("Unrecognized");
  const warning = readTimingSample(apps, [], cpu, battery, power, "thermal warning level = 1");
  expect(timingFindings(warning).find(finding => finding.check === "Thermal")?.status).toBe("WARN");
});

test("timing readiness distinguishes battery power and low CPU headroom from a quiet AC sample", () => {
  const quiet = readTimingSample(apps, [], cpu, battery, power, thermal);
  expect(timingFindings(quiet).every(finding => finding.status === "OK")).toBe(true);
  const busy = readTimingSample(apps, [], "CPU usage: 30% user, 5% sys, 65% idle", "Battery Power", power, thermal);
  expect(timingFindings(busy).filter(finding => finding.status === "WARN").map(finding => finding.check)).toEqual([
    "Power",
    "CPU",
  ]);
});
