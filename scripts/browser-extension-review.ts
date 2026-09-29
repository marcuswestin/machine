#!/usr/bin/env bun
// Explain browser-extension drift in repo -> Mac terms. Interactive resolution
// supports declared Chrome Web Store extensions; native Chrome approval remains
// with the user.
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, readSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

type Extension = {
  browser: string;
  profile?: string;
  id?: string;
  bundle_id?: string;
  name?: string;
  from_webstore?: boolean;
  update_url?: string;
};

function entries(file: string): Extension[] {
  const parsed: unknown = JSON.parse(readFileSync(file, "utf8"));
  if (
    !Array.isArray(parsed)
    || !parsed.every((item) => item && typeof item === "object" && typeof item.browser === "string")
  ) {
    throw new Error(`Invalid browser extension inventory: ${file}`);
  }
  return parsed as Extension[];
}

function identity(item: Extension): string {
  return [item.browser, item.profile ?? "", item.id ?? item.bundle_id ?? ""].join("\0");
}

export function compareBrowserExtensions(
  repo: Extension[],
  live: Extension[],
): { missing: Extension[]; extra: Extension[] } {
  const repoIds = new Set(repo.map(identity));
  const liveIds = new Set(live.map(identity));
  return {
    missing: repo.filter((item) => !liveIds.has(identity(item))),
    extra: live.filter((item) => !repoIds.has(identity(item))),
  };
}

function answerLine(): string {
  const byte = Buffer.alloc(1);
  let answer = "";
  while (readSync(0, byte, 0, 1, null) === 1 && byte[0] !== 10) answer += byte.toString();
  return answer.trim().toLowerCase();
}

function removeChromeDeclaration(repo: string, extension: Extension): void {
  const id = extension.id;
  if (!id || !/^[a-p]{32}$/.test(id)) throw new Error("Invalid Chrome extension ID; repo left unchanged");
  const declaration = join(repo, "config/browser-extensions/chrome.json");
  const remaining = entries(declaration).filter((item) => identity(item) !== identity(extension));
  writeFileSync(declaration, JSON.stringify(remaining, null, 2) + "\n");
  console.log(`Removed ${extension.name ?? id} from repo declarations; review git diff before applying.`);
}

function review(repo: string, liveDir: string, interactive: boolean): void {
  let differences = 0;
  for (const browser of ["chrome", "firefox", "safari"]) {
    const declared = entries(join(repo, "config/browser-extensions", `${browser}.json`));
    const live = entries(join(liveDir, `${browser}.json`));
    const { missing, extra } = compareBrowserExtensions(declared, live);
    differences += missing.length + extra.length;
    for (const item of missing) {
      const label = `${item.browser}/${item.profile ?? "default"}: ${item.name ?? item.id ?? item.bundle_id}`;
      console.log(`[MISSING ON MAC] ${label} is declared in the repo.`);
      if (item.browser === "chrome") {
        console.log(
          `  Install it from https://chromewebstore.google.com/detail/${item.id} in Chrome's ${
            item.profile ?? "Default"
          } profile. Apply does not remove it.`,
        );
      }
      if (!interactive || item.browser !== "chrome") continue;
      process.stdout.write("  Keep it in the repo [Enter], remove its declaration [r], or skip [s]? ");
      const answer = answerLine();
      if (answer === "r") removeChromeDeclaration(repo, item);
      else if (answer === "" || answer === "k") {
        console.log("  Kept in the repo. Run just apply-to-machine full for a guided Chrome Web Store install.");
      } else console.log("  Skipped; repo unchanged.");
    }
    for (const item of extra) {
      console.log(
        `[ONLY ON MAC] ${item.browser}/${item.profile ?? "default"}: ${
          item.name ?? item.id ?? item.bundle_id
        }. Apply does not remove browser extensions.`,
      );
      if (interactive) {
        console.log("  Importing a new extension needs an explicit reviewed declaration; repo unchanged.");
      }
    }
  }
  if (!differences) console.log("Browser extension declarations match the captured Mac inventory.");
}

if (import.meta.main) {
  const mode = process.argv[2];
  const repo = resolve(process.argv[3] ?? join(import.meta.dir, ".."));
  if (mode === "diff") {
    if (!process.argv[4]) throw new Error("usage: browser-extension-review.ts diff <repo> <capture-dir>");
    review(repo, resolve(process.argv[4]), false);
  } else if (mode === "resolve") {
    if (!process.stdin.isTTY) throw new Error("Run this review in an interactive terminal; repo left unchanged");
    const temporary = mkdtempSync(join(tmpdir(), "machine-browser-extensions-"));
    try {
      const result = spawnSync("bash", [join(repo, "scripts/browser-extensions.sh"), "capture", temporary], {
        stdio: "inherit",
      });
      if (result.status !== 0) throw new Error("Could not capture browser extensions; repo left unchanged");
      review(repo, temporary, true);
    } finally {
      rmSync(temporary, { recursive: true, force: true });
    }
  } else {
    throw new Error("usage: browser-extension-review.ts diff|resolve <repo> [capture-dir]");
  }
}
