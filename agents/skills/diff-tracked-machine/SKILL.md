---
name: diff-tracked-machine
description: Runs `just diff-tracked` in the machine repo (`import-inventory tracked`, tracked Homebrew/MAS/editor/chezmoi drift, then `merge-in-settings` report), interprets machine-vs-repo output, recommends `just merge-in-settings` write flags when merging live JSON into chezmoi sources is appropriate, and only runs write/import commands after explicit user confirmation. Use when the user wants tracked declarative drift review plus safe import guidance, or mentions diff-tracked with merge-in-settings, diff-tracked-machine, or promoting local app JSON into `home/.dotfiles`.
disable-model-invocation: true
---

# diff-tracked-machine

## Scope

`just diff-tracked` is **not** a Git worktree diff. It compares **this Mac** to **what the repo declares**:

1. **`import-inventory tracked`** — snapshots declared review inputs into **`inventory-tracked/`** (brew, MAS list, selected defaults with sidecars, extensions, display layout when replayable).

2. **Tracked drift sections** — Homebrew vs flake brewfile, Mac App Store apps vs `homebrew.masApps`, editor extensions vs `vscode-family/extensions.txt`, and **`chezmoi diff`**.

3. **`just merge-in-settings`** (report only) — live app JSON/JSONC vs `home/.dotfiles/` (see `scripts/repo-settings-import.ts`).

Use **`git diff` / `git status`** separately when the task is ordinary version control on the machine repo.

## Workflow

1. **Run** from the machine repo root:

   ```sh
   just diff-tracked
   ```

2. **Interpret output**
   - **Tracked drift sections:** Homebrew leaves/casks, Mac App Store apps, undeclared editor extensions, and **chezmoi diff** — template or target edits live in `home/` (then `just chezmoi-apply` after updating the repo).
   - **`merge-in-settings` section:** keys or files only on the machine vs repo-owned JSON; symlink-OK lines mean live already resolves to the repo file.

3. **Recommend JSON merge into repo** when live `Application Support` (or `~/.continue`, etc.) **diverges** from the canonical repo file (broken symlink or edits outside the repo copy). Point to:

   | Goal                                      | Command                                                                                                                                                      |
   | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
   | Report only                               | `just merge-in-settings` or `just merge-in-settings --json`                                                                                                  |
   | Merge object JSON (repo wins on same key) | `just merge-in-settings --write-lossy`                                                                                                                       |
   | Include Docker store                      | add `--write-docker`                                                                                                                                         |
   | VS Code/Cursor family JSONC               | `just merge-in-settings --write-jsonc-vscode` (strips `//` and block comments in `settings.json`; keybindings can be replaced from live — see script header) |

4. **Confirm before any write:** Ask explicitly (“Run `just merge-in-settings …` with these flags? yes/no”) and list the **exact** command. Do not pass `--write-lossy`, `--write-jsonc-vscode`, or `--write-docker` until the user says yes.

5. **After yes:** Run only what was confirmed.

## Constraints

- Follow **AGENTS.md**: no secrets, no blind promotion of inventory snapshots into active config.
- **`merge-in-settings`** does not replace **`just discover-global`** or Raycast’s export flow; excluded paths are documented in `scripts/repo-settings-import.ts`.
