import { expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { compareBrowserExtensions } from "./browser-extension-review";

const passwordExtension = {
  browser: "chrome",
  profile: "Default",
  id: "pejdijmoenmkgeppbflobdenhhabjlaj",
  name: "iCloud Passwords",
};

test("a repo extension absent from the Mac is missing locally, not a removal instruction", () => {
  expect(compareBrowserExtensions([passwordExtension], [])).toEqual({ missing: [passwordExtension], extra: [] });
  expect(compareBrowserExtensions([], [passwordExtension])).toEqual({ missing: [], extra: [passwordExtension] });
});

test("semantic diff reports only changed extension values without changing the repo", () => {
  const root = mkdtempSync(join(tmpdir(), "machine-browser-review-"));
  try {
    const repo = join(root, "repo");
    const live = join(root, "live");
    mkdirSync(join(repo, "config/browser-extensions"), { recursive: true });
    mkdirSync(live);
    for (const browser of ["chrome", "firefox", "safari"]) {
      writeFileSync(
        join(repo, "config/browser-extensions", `${browser}.json`),
        JSON.stringify(browser === "chrome" ? [passwordExtension] : []),
      );
      writeFileSync(join(live, `${browser}.json`), "[]");
    }
    const before = readFileSync(join(repo, "config/browser-extensions/chrome.json"), "utf8");
    const result = Bun.spawnSync(["bun", join(import.meta.dir, "browser-extension-review.ts"), "diff", repo, live], {
      stdout: "pipe",
      stderr: "pipe",
    });
    expect(result.exitCode).toBe(0);
    expect(result.stdout.toString()).toBe(
      "[DIFF] browser.chrome.Default.pejdijmoenmkgeppbflobdenhhabjlaj: current=<absent> -> repo=\"iCloud Passwords\"\n",
    );
    expect(readFileSync(join(repo, "config/browser-extensions/chrome.json"), "utf8")).toBe(before);
  } finally {
    rmSync(root, { recursive: true });
  }
});
