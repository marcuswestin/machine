# Agent Instructions

This repo is a personal declarative macOS machine setup. Treat it as an
operational repo: small changes, concrete validation, and no broad rewrites
unless asked.

## Primary Workflow

- Run `just help` to list all recipes.
- Fresh-machine entrypoint: `up.sh`.
- Daily command surface: `just`.
- `just check machine` is the read-only operational health summary (`--json` for structured
  results). Exit 1 means a detected failure; exit 2 means warnings or unverified
  checks. It does not replace the `review-machine-repo` security/upgrade review.
  Validate changes with `bun test scripts/doctor.test.ts` and a live `just check machine`;
  access failures must remain unverified, never healthy.
- Steady-state apply command: `just apply-to-machine` (full: asks `[Y/n]`, default
  yes, before restarting affected apps). `just partial-apply-to-machine` applies the
  same declarations without quitting apps; `just update` uses it, and `up.sh` runs it
  before the full apply so the declared tools exist. Both install missing Homebrew
  packages but does not upgrade already-installed formulae or casks
  (`homebrew.onActivation.upgrade = false`), so app self-updates are left
  alone. `just update casks` upgrades outdated Homebrew-managed casks; name a
  self-updating cask explicitly for a deliberate Homebrew upgrade. It preserves
  tap-qualified cask names and skips targets older than installed receipts.
  `just update` bumps Homebrew tap pins in `flake.lock`, applies, then upgrades
  declared formulae and Homebrew-managed casks. Local cask versions and checksums
  are verified fresh-install baselines, not copies of self-updated live versions.
- Public commands are the grouped recipes shown by `just --list`; implementation
  recipes are prefixed with `_` and compatibility recipes have `[private]`.
  **`just _audit-login-items`** reports enabled Login Items outside
  `machine.startupApps` plus `com.apple.*` / `org.pqrs.*`; it is not part
  of `just check repo` until the allowlist matches live helpers.
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
  `~/.config/vscode-family/*`. Edit the repo files only; run `just apply-to-machine dotfiles` so the
  symlinks stay authoritative (`just check repo` checks resolution). **`just merge-in-settings`**
  compares live app JSON/JSONC on disk to those repo files and can merge new keys (see
  `scripts/repo-settings-import.ts`).
- `inventory-tracked/` and `inventory-global/`: optional local snapshots for human review;
  do not blindly promote them into active config. **`just diff snapshot`**
  compares captured files under one of those folders to current machine output when those files exist
  (Brewfile, `mas.json`, `defaults/*.plist`, `display-layout.sh` vs the canonical
  script). **`just _plist-sidecars`** (`scripts/plist-sidecars.sh`)
  writes readable sidecars next to plist paths (`.xml`, `.json`, `.toml`, plus
  `.error.txt` files when a conversion fails). With no paths it reads
  `inventory-global/defaults/`; pass explicit paths as `just _plist-sidecars path …`
  when needed. Managed config—including Antigravity,
  Continue, Claude Code (`~/.claude/settings.json` → `home/.dotfiles/claude/`),
  Cursor (`~/.cursor/cli-config.json` → `home/.dotfiles/cursor/cli-config.json`,
  `~/.cursor/permissions.json` → `home/.dotfiles/cursor/permissions.json`; the
  permissions file must not define `terminalAllowlist` or `approvalMode` or it
  locks the IDE out of Auto-review, plus
  vscode-family `chatgpt.*` / `cursor.*` keys), Karabiner-Elements
  (`~/.config/karabiner/karabiner.json` → `home/.dotfiles/karabiner/karabiner.json`),
  GitHub CLI, and iTerm2 Dynamic Profiles—lives
  under `home/` / `home/.dotfiles/` with
  chezmoi; use `chezmoi diff` for drift. Karabiner's JSON must render as a
  regular file because it cannot detect changes through a direct file symlink.
  Codex app keybindings (`~/.codex/keybindings.json` → `home/.dotfiles/codex/`)
  are symlinked by chezmoi. Codex portable defaults live in `config/codex/config.toml`. Its declared
  keys are merged into the current user's writable `~/.codex/config.toml`;
  project trust, hook trust, app-generated paths, and other local keys stay
  there. Never symlink or import that whole file. `just import-from-machine`
  reviews changed declared keys before promoting them into the repo. Apply
  overwrites differing declared keys from the repo; its preflight only validates.
  Local Homebrew casks live under
  `homebrew/local/` and are exposed as the `machine/local` tap. Thaw
  replaces Ice; `just import-from-machine thaw` saves one native export in
  `config/thaw/profile.json`. `just apply-to-machine` opens a guided native import/apply step
  when that file changes and records completion only after the user confirms.
  Thaw 3.0.0-alpha.6 has no supported full-profile import/apply URI; do not replace
  this with writes to its private database or permission grants. Use
  `just _thaw-profile-sync force` to repeat the step for an unchanged export.
  Tracked drift reports the last confirmation, not live layout equivalence.
  Keep Thaw settings in the profile rather than competing macOS defaults writes.
  AeroSpace staggered window assignment
  uses `scripts/aerospace-stagger-app-window.sh` from `aerospace.toml`. Auth/session files (`~/.codex/auth.json`,
  `~/.claude.json`, `~/.config/gh/hosts.yml`), caches, logs, and SQLite state stay
  unmanaged. Treat captured paths as potentially sensitive and scrub or omit before
  committing anything derived from them. When you add new declaration surfaces
  that should show up in tracked drift review, extend `scripts/diff-tracked.sh`
  (and keep `just diff prune` in sync if those items are also prune candidates).
  **`just discover snapshot tracked`** (`scripts/import-inventory.sh`) refreshes
  `inventory-tracked/` (Brewfile, `mas.json`, `defaults/` with readable sidecars,
  editor extension lists, and display layout via **`just _display-layout-capture`**).
  `scripts/display-layout.sh` identifies screens by displayplacer serial ids
  (`id:s…`), not persistent UUIDs, because macOS can reassign persistent ids
  when external displays wake in a different order; the capture recipe rewrites
  them. Do not hand-paste `displayplacer list` output into it.
  **`just discover snapshot global`** refreshes `inventory-global/` with the
  same tracked snapshot. Raycast native export/import is paused during the
  Spotlight trial; the public apply and import workflows print a reminder.
  **`just diff`** reports tracked drift without refreshing inventory:
  Homebrew, Mac App Store apps, editor extensions, chezmoi, and live app JSON vs
  repo. **`just discover global`** is the separate discovery mode for unmanaged
  candidates into `inventory-global/discovery/`: `/Applications`, defaults domains
  outside the tracked list, preference plists, LaunchAgents/LaunchDaemons, fonts,
  system extensions, and unmanaged shell snippets. **`just discover apps`** lists
  key names and config-file paths for declared cask apps without preference
  values; its results are review candidates, not automatically untracked settings.
  Use `git diff` / `git status` separately for version-control work on the repo itself.
  Local editor extensions listed in `config/editor-extensions/local-only.txt`
  are installed from source, never requested from the marketplace, and preserved
  by editor prune in both VS Code and Cursor. Keep this list separate from the
  marketplace extension declaration files.
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
bash -n scripts/check-codex-config.sh
bun test scripts/codex-config-sync.test.ts scripts/restart-plan.test.ts scripts/settings-apply.test.ts
scripts/check-codex-config.sh
just --list
just --dry-run apply-to-machine
just check repo
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

- `just apply-to-machine` may install apps, apply macOS defaults, apply chezmoi dotfiles, and
  install editor extensions.
- `just prune plan` should show removals before `just prune apply` executes
  them.
- Prune commands should stay conservative: only remove undeclared Homebrew
  leaves/casks and undeclared editor extensions.
- Keep sudo usage explicit. The sudo keepalive wrapper should prompt up front
  and only preserve the timestamp for commands that still invoke `sudo`
  themselves.
