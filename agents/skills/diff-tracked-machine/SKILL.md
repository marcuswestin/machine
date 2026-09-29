---
name: diff-tracked-machine
description: Runs `just diff` in the machine repo to compare tracked declarations with this Mac, interprets drift, and recommends reviewed imports where appropriate. Use when the user wants tracked declarative drift review or safe guidance for promoting local app JSON into `home/.dotfiles`.
disable-model-invocation: true
---

# diff-tracked-machine

## Scope

`just diff` is **not** a Git worktree diff. It compares **this Mac** to **what the repo declares** without writing inventory:

1. **Optional `just discover snapshot tracked`** — captures review inputs into ignored **`inventory-tracked/`** when a saved snapshot is requested.

2. **Tracked drift sections** — Homebrew vs flake brewfile, Mac App Store apps vs `homebrew.masApps`, editor extensions vs `vscode-family/extensions.txt`, and **`chezmoi diff`**.

3. **Live app JSON/JSONC report** — compares disk state with `home/.dotfiles/` (see `scripts/repo-settings-import.ts`).

Use **`git diff` / `git status`** separately when the task is ordinary version control on the machine repo.

## Workflow

1. **Run** from the machine repo root:

   ```sh
   just diff
   ```

2. **Interpret output**
   - **Tracked drift sections:** Homebrew leaves/casks, Mac App Store apps, undeclared editor extensions, and **chezmoi diff** — template or target edits live in `home/` (then `just apply-to-machine dotfiles` after updating the repo).
   - **`merge-in-settings` section:** keys or files only on the machine vs repo-owned JSON; symlink-OK lines mean live already resolves to the repo file.

3. **Recommend JSON merge into repo** when live `Application Support` (or `~/.continue`, etc.) **diverges** from the canonical repo file (broken symlink or edits outside the repo copy). Start with the guided command; use the hidden expert command only for a reviewed special case:

   | Goal                                      | Command                                                                                                                                                      |
   | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
   | Report only                               | `just diff` or the hidden expert `just merge-in-settings --json`                                                                                             |
   | Guided per-file import                    | `just import-from-machine files`                                                                                                                             |
   | Merge object JSON (repo wins on same key) | `just merge-in-settings --write-lossy`                                                                                                                       |
   | Include Docker store                      | add `--write-docker`                                                                                                                                         |
   | VS Code/Cursor family JSONC               | `just merge-in-settings --write-jsonc-vscode` (strips `//` and block comments in `settings.json`; keybindings can be replaced from live — see script header) |

4. **Confirm before any expert write:** Ask explicitly (“Run `just merge-in-settings …` with these flags? yes/no”) and list the **exact** command. Do not pass `--write-lossy`, `--write-jsonc-vscode`, or `--write-docker` until the user says yes. The guided `import-from-machine files` command prompts for each file itself.

5. **After yes:** Run only what was confirmed.

## Constraints

- Follow **AGENTS.md**: no secrets, no blind promotion of inventory snapshots into active config.
- **`merge-in-settings`** does not replace **`just discover global`** or `just import-from-machine raycast`; excluded paths are documented in `scripts/repo-settings-import.ts`.
