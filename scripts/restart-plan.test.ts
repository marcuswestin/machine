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

test("disabled Docker settings never enter the restart plan", () => {
  expect(appsForChanges("", "", "", "", deniedDocker, { skipDocker: false }))
    .toEqual([]);
  expect(appsForChanges("", "", "", "", deniedDocker, { strict: true })).toEqual([]);
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
