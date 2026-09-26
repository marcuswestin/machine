import { describe, expect, test } from "bun:test";
import { appArtifactPath, backgroundItems, backgroundStatus, exitCode, hasMappings, launchdStatus } from "./doctor";

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
  test("does not confuse disallowed with allowed, or use another user's approval", () => {
    const items = backgroundItems(`
Records for UID -2 : system
 #1:
 Disposition: [enabled, disallowed, notified] (0x9)
 Identifier: 16.org.nixos.activate-system
 Embedded Item Identifiers:
    #1: 8.an.embedded.identifier
Records for UID 502 : other user
 #1:
 Disposition: [enabled, allowed, notified] (0xb)
 Identifier: 8.org.nixos.machine-login-startup
Records for UID 501 : current user
 #1:
 Disposition: [enabled, allowed, notified] (0xb)
 Identifier: 8.org.nixos.machine-login-startup
`);
    expect(items).toHaveLength(3);
    expect(backgroundStatus(items, "org.nixos.activate-system", 501).status).toBe("FAIL");
    expect(backgroundStatus(items, "org.nixos.machine-login-startup", 501).status).toBe("OK");
    expect(backgroundStatus(items, "org.nixos.machine-login-startup", 503).status).toBe("UNKNOWN");
    expect(backgroundStatus([], "org.nixos.activate-system", 501).status).toBe("UNKNOWN");
  });
  test("disabled jobs and conflicting records never pass", () => {
    const items = [
      { uid: 501, identifier: "job", disposition: ["enabled", "allowed"] },
      { uid: 501, identifier: "job", disposition: ["disabled", "allowed"] },
    ];
    expect(backgroundStatus(items, "job", 501).status).toBe("FAIL");
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
