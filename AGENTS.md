# Agent Instructions

This repo is a personal declarative macOS machine setup. Treat it as an
operational repo: small changes, concrete validation, and no broad rewrites
unless asked.

## Primary Workflow

- Run `just help` to list all recipes.
- Fresh-machine entrypoint: `up.sh`.
- Daily command surface: `just`.
- Steady-state apply command: `just apply`.
- Public commands are the recipes shown by `just --list`; implementation
  recipes are prefixed with `_` and should stay private.
- `up.sh` should remain minimal: install/load base Nix, ensure enough tooling to
  clone/update this repo, then hand off to `scripts/up-local.sh`.
- `scripts/up-local.sh` should invoke the declarative apply path with minimal
  bootstrap, not inspect and repair unexpected local state.

## Ownership Boundaries

- `nix-darwin`: system configuration, macOS defaults, Nix packages.
- `nix-homebrew` / Homebrew: GUI apps and Brew-specific packages.
- Home Manager: minimal PATH/env/session integration only.
- `chezmoi`: actual dotfiles under `home/`; editable configs live in `home/.dotfiles/`
  (hidden so chezmoi does not copy them) and are symlinked into `$HOME` via `symlink_*`
  templates. **VS Code / Cursor user `settings.json` and `keybindings.json`** are not edited
  in Application Support directly: chezmoi writes symlinks
  `~/.config/vscode-family/*` → `home/.dotfiles/vscode-family/*`, and
  `~/Library/Application Support/{Code,Cursor}/User/{settings,keybindings}.json` →
  `~/.config/vscode-family/*`. Edit the repo files only; run `just chezmoi-apply` so the
  symlinks stay authoritative (`just verify` checks resolution). **`just merge-in-settings`**
  compares live app JSON/JSONC on disk to those repo files and can merge new keys (see
  `scripts/repo-settings-import.ts`).
- `inventory-tracked/` and `inventory-global/`: optional local snapshots for human review;
  do not blindly promote them into active config. **`just _snapshot-diff`**
  compares captured files under one of those folders to current machine output when those files exist
  (Brewfile, `mas.json`, `defaults/*.plist`, `display-layout.sh` vs the canonical
  script). **`just _plist-sidecars`** (`scripts/plist-sidecars.sh`)
  writes readable sidecars next to plist paths (`.xml`, `.json`, `.toml`, plus
  `.error.txt` files when a conversion fails). With no paths it reads
  `inventory-global/defaults/`; pass explicit paths as `just _plist-sidecars path …`
  when needed. Managed config—including Antigravity,
  Continue, Claude Code (`~/.claude/settings.json` → `home/.dotfiles/claude/`), Codex CLI
  (`~/.codex/config.toml` → `home/.dotfiles/codex/config.toml`),
  Cursor (`~/.cursor/cli-config.json` and `~/.cursor/permissions.json` share one source, plus
  vscode-family `chatgpt.*` / `cursor.*` keys), GitHub CLI, and iTerm2 Dynamic Profiles—lives
  under `home/` / `home/.dotfiles/` with
  chezmoi; use `chezmoi diff` for drift. Auth/session files (`~/.codex/auth.json`,
  `~/.claude.json`, `~/.config/gh/hosts.yml`), caches, logs, and SQLite state stay
  unmanaged. Treat captured paths as potentially sensitive and scrub or omit before
  committing anything derived from them. When you add new declaration surfaces
  that should show up in tracked drift review, extend `scripts/diff-tracked.sh`
  (and keep `just prune-diff` in sync if those items are also prune candidates).
  **`just import-inventory tracked`** (`scripts/import-inventory.sh`) refreshes
  `inventory-tracked/` (Brewfile, `mas.json`, `defaults/` with readable sidecars,
  editor extension lists, and display layout via **`just _display-layout-capture`**).
  **`just import-inventory global`** refreshes `inventory-global/` (the same tracked snapshot, and
  **`scripts/raycast-settings-sync.sh`** when `config/raycast/settings.json` changed).
  **`just diff-tracked`** runs the tracked import, then reports tracked drift:
  Homebrew, Mac App Store apps, editor extensions, chezmoi, and live app JSON vs
  repo. **`just discover-global`** is the separate discovery mode for unmanaged
  candidates into `inventory-global/discovery/`: `/Applications`, defaults domains
  outside the tracked list, preference plists, LaunchAgents/LaunchDaemons, fonts,
  system extensions, and unmanaged shell snippets. Use `git diff` / `git status` separately for
  version-control work on the repo itself.
  When plist review output changes, update `scripts/plist-sidecars.sh` together with
  **`just _plist-sidecars`** when testing paths manually.

Prefer first-class nix-darwin options over custom activation scripts. Use custom
activation only when the option does not exist or macOS requires a special path.

## Editing Rules

- Use `apply_patch` for file edits.
- Keep active config conservative and deterministic for fresh machines.
- Do not import current-machine state into active config unless explicitly asked.
- Do not add secrets, auth files, histories, caches, telemetry, SQLite DBs,
  workspace storage, model caches, or session state.
- Keep branch/default install references pointed at `main` unless the user is
  explicitly testing another branch.
- Preserve the `MACHINE_*` environment overrides in scripts where present.
- Do not add safety checks, fallback branches, or workaround paths for
  unexpected machine state. This repo is declarative: if state is unexpected,
  fix the owning nix-darwin, Homebrew, Home Manager, or chezmoi declaration so
  every managed machine converges to the same expected state.
- Do not gate scripts on **installation** probes for apps or CLIs that this repo
  already declares (nix-darwin, nix-homebrew, Home Manager, chezmoi): no
  `command -v …`, no `[ -x … ]` on those bundle paths before invoking them, and
  no `test -f` / `[ -e … ]` on declared `.app` bundles solely to skip a
  declared tool. After bootstrap, recipes should call declared tools directly
  and let failures surface. Exception: `up.sh` and similar **pre-Nix** entrypoints
  may still test whether Nix itself is present before installing it. Probes for
  **runtime state** unrelated to “is this package installed?” remain fine (for
  example `pgrep` to avoid launching a startup app twice, or `gh auth status`
  before `gh auth login`).
- Comment non-obvious settings where they are declared. For numeric or encoded
  values such as macOS defaults IDs, modifier bitmasks, key codes, separator
  characters, and state-version pins, look up what the value means and record
  that meaning in an adjacent comment. Do the same for **opaque or symbolic**
  option values that are not self-explanatory English prose—Finder four-letter
  view codes (for example `icnv`), symbolic hotkey IDs, locale or bundle
  identifier spellings, and similar Apple vocabulary—so the next reader does not
  have to reverse-engineer them.

## Validation

Run the smallest useful validation for the change. Common checks:

```sh
bash -n up.sh
bash -n scripts/up-local.sh
bash -n scripts/with-sudo-keepalive.sh
bash -n scripts/discover-global.sh
bash -n scripts/snapshot-diff.sh
bash -n scripts/plist-sidecars.sh
bash -n scripts/import-inventory.sh
bash -n scripts/diff-tracked.sh
bun scripts/repo-settings-import.ts . --json >/dev/null
just --list
just --dry-run apply
just verify
```

For macOS defaults changes, also inspect the relevant nix-darwin option when
possible:

```sh
nix eval --extra-experimental-features 'nix-command flakes' \
  .#darwinConfigurations.machine.config.system.defaults
```

## Git

- Don't stage or commit changes unless asked to do so.
- Before committing, check `git status --short`.
- Commit only the files relevant to the completed fix.
- Push the current branch after a successful commit.
- If the worktree contains unrelated user changes, leave them alone, unless relevant to your change.

## Fresh-Machine Safety

- `just apply` may install apps, apply macOS defaults, apply chezmoi dotfiles, and
  install editor extensions.
- `just prune-diff` should show removals before `just prune` executes
  them.
- Prune commands should stay conservative: only remove undeclared Homebrew
  leaves/casks and undeclared editor extensions.
- Keep sudo usage explicit. The sudo keepalive wrapper should prompt up front
  and only preserve the timestamp for commands that still invoke `sudo`
  themselves.
