import { describe, expect, test } from "bun:test";
import { appArtifactPath, backgroundStatus, exitCode, hasMappings, launchdStatus } from "./doctor";

describe("machine doctor evidence", () => {
  test("cask archive subdirectories do not become installed app paths", () => {
    expect(appArtifactPath(["AeroSpace-v0.21.3-Beta/AeroSpace.app"], "/Applications")).toBe(
      "/Applications/AeroSpace.app",
    );
    expect(appArtifactPath(["Original.app", { target: "Renamed.app" }], "/Users/test/Applications")).toBe(
      "/Users/test/Applications/Renamed.app",
    );
    expect(appArtifactPath(["Original.app", { target: "/opt/Custom.app" }], "/Applications")).toBe("/opt/Custom.app");
  });
  test("reports Service Management approval and missing states without assuming success", () => {
    expect(backgroundStatus("job", "enabled").status).toBe("OK");
    expect(backgroundStatus("job", "requiresApproval").status).toBe("FAIL");
    expect(backgroundStatus("job", "notRegistered").status).toBe("FAIL");
    expect(backgroundStatus("job", "notFound").status).toBe("UNKNOWN");
    expect(backgroundStatus("job", "").status).toBe("UNKNOWN");
  });
  test("completed one-shot launchd jobs are healthy, missing evidence is not", () => {
    expect(launchdStatus("state = not running\nlast exit code = 0").status).toBe("OK");
    expect(launchdStatus("state = not running\nlast exit code = 78").status).toBe("FAIL");
    expect(launchdStatus("state = not running").status).toBe("UNKNOWN");
    expect(launchdStatus("state = running").status).toBe("OK");
    expect(launchdStatus("").status).toBe("UNKNOWN");
  });
  test("keyboard mapping source and destination must belong to the same pair", () => {
    const expected = [{ HIDKeyboardModifierMappingSrc: 30064771129, HIDKeyboardModifierMappingDst: 30064771296 }];
    expect(hasMappings("(null)", expected)).toBe(false);
    expect(hasMappings("(null)", [])).toBe(true);
    expect(hasMappings("()", [])).toBe(true);
    expect(
      hasMappings("{ HIDKeyboardModifierMappingSrc = 30064771129; HIDKeyboardModifierMappingDst = 30064771296; }", []),
    ).toBe(false);
    expect(
      hasMappings(
        "{ HIDKeyboardModifierMappingSrc = 30064771129; HIDKeyboardModifierMappingDst = 30064771296; }",
        expected,
      ),
    ).toBe(true);
    expect(
      hasMappings(
        "{ HIDKeyboardModifierMappingSrc = 0x700000039; HIDKeyboardModifierMappingDst = 0x7000000e0; }",
        expected,
      ),
    ).toBe(true);
    expect(
      hasMappings(
        "{ HIDKeyboardModifierMappingSrc = 30064771129; HIDKeyboardModifierMappingDst = 1; }\n{ HIDKeyboardModifierMappingSrc = 2; HIDKeyboardModifierMappingDst = 30064771296; }",
        expected,
      ),
    ).toBe(false);
  });
  test("failures take precedence over incomplete coverage", () => {
    expect(exitCode([{ status: "OK", detail: "" }])).toBe(0);
    expect(exitCode([{ status: "WARN", detail: "" }])).toBe(2);
    expect(exitCode([{ status: "UNKNOWN", detail: "" }])).toBe(2);
    expect(exitCode([{ status: "UNKNOWN", detail: "" }, { status: "FAIL", detail: "" }])).toBe(1);
  });
});
