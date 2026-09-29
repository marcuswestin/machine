import { expect, test } from "bun:test";
import { appsForChanges } from "./restart-plan";

const deniedDocker = JSON.stringify([{ id: "docker-settings-store", status: "permission_denied" }]);
const brokenHandy = JSON.stringify([{ id: "handy-settings-store", status: "parse_error" }]);

test("only changed app settings enter the restart plan", () => {
  expect(appsForChanges("Codex: 1 matching, 0 missing", "[MATCH] claude", "", "[MATCH] eu.exelban.Stats", "[]"))
    .toEqual([]);
  expect(
    appsForChanges(
      "  MISSING desktop.followUpQueueMode",
      "[DIFF] claude-appearance",
      "diff --git a/home/.dotfiles/aerospace.toml b/home/.dotfiles/aerospace.toml",
      "[DIFF] eu.exelban.Stats",
      "[]",
    ),
  )
    .toEqual(["AeroSpace", "ChatGPT", "Claude", "Stats"]);
});

test("a changed Raycast hotkey restarts Raycast during full apply", () => {
  expect(appsForChanges("", "", "", "[DIFF] com.raycast.macos: 4 declared keys, 1 differing/unset", "[]"))
    .toEqual(["Raycast"]);
});

test("unreadable Docker settings never count as matching", () => {
  expect(appsForChanges("", "", "", "", deniedDocker, { skipDocker: false }))
    .toEqual(["Docker"]);
  expect(() =>
    appsForChanges("", "", "", "", deniedDocker, {
      skipDocker: false,
      strict: true,
    })
  ).toThrow("unverified");
});

test("explicit Docker skip leaves other restart checks strict", () => {
  expect(appsForChanges("", "", "", "", deniedDocker, {
    skipDocker: true,
    strict: true,
  })).toEqual([]);
  expect(() =>
    appsForChanges("", "", "", "", brokenHandy, {
      skipDocker: true,
      strict: true,
    })
  ).toThrow("handy-settings-store settings are unverified");
});
