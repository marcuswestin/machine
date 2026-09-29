# Configuration workflow

Run `just help` to see the grouped public recipes. Commands that compare or
validate state do not apply settings. `just discover` writes only ignored local
reports; it never promotes a candidate into active configuration.

- `just apply-to-machine [normal|full|dotfiles]`: repo → Mac. Normal installs
  missing packages and applies declarations without intentionally quitting apps.
  Full guides native imports and restarts affected apps. Dotfiles limits the
  scope to chezmoi, Handy's pinned model, and AeroSpace reload.
- `just import-from-machine [all|browser|codex|claude|thaw|raycast|files]`: Mac → repo.
  Interactively reviews portable values and writes only selected declarations.
  It never applies, stages, commits, or pushes.
- `just diff [all|settings|prune|snapshot [tracked|global]]`: read-only
  comparison. Snapshot compares an earlier ignored capture with this Mac.
- `just check [all|repo|machine]`: validate repo source and machine health.
  `just check machine --json` emits structured health results.
- `just discover [global|apps|snapshot [tracked|global]]`: find unmanaged
  candidates or capture ignored local inventory for later review.
- `just update [all|casks [cask…]]`: update Homebrew pins and packages, or
  upgrade managed casks only.
- `just prune [plan|apply]`: preview undeclared Homebrew packages and editor
  extensions by default; `apply` removes them. Changed dotfiles are not prune
  candidates.

## Apply and conflicts

The Codex repo file `config/codex/config.toml` lists keys managed for the
**current user**. Apply merges missing values into regular, writable
`~/.codex/config.toml` while preserving unknown fields, local trust decisions,
hooks, and app-generated state. A conflicting managed value stops apply before
sudo or the system switch. Use `just import-from-machine codex` to review a UI
change. To keep the repo value, edit the local value deliberately.

`just apply-to-machine` does not intentionally quit desktop apps. Some changed
settings only take effect when their app next starts; the command prints pending
restart work. `just apply-to-machine full` plans affected app restarts, shows the
plan, and waits for Enter. It also guides Thaw and Raycast imports and native
consent. Run it from Terminal.app if it needs to quit your current terminal.
It does not reboot, prune, upgrade, commit, or push.

If a detector cannot read a managed setting, it reports an unknown state or
stops the full pass. A recorded Thaw or Raycast import confirms the user
completed the step; it does not prove live UI layout. macOS privacy and login
item consent remain native user actions. Docker settings import, export, and
apply are disabled for now; the commands print a notice and leave Docker
running with its settings unchanged.

## Import settings from this Mac

`just import-from-machine` displays existing worktree changes and reviews
declared Codex and Claude preferences and browser extensions one at a time.
Account, trust, session, and other local fields are excluded. Browser extension
review can preserve a missing declaration, remove it, or skip it; a missing
Chrome Web Store extension still needs native Chrome installation during a
full apply. The command can also guide Thaw and Raycast exports. Use a scope
argument to review only one app.

Repo-backed symlinks already record edits directly in the repo. Review their
`git diff`; no copy is needed. For other live JSON/JSONC, the hidden expert
`merge-in-settings` recipe remains available for expert use. The explicit
`just import-from-machine files` scope offers changed JSON/JSONC files
individually, shows the machine-only keys, and
asks for an explicit `yes` before writing each one. Repo values win for existing
keys; importing JSONC strips comments, and importing keybindings replaces the
whole array. Unreadable files and text-only configs remain for manual review.
The default `all` scope does not import these unknown keys. Review their values
for private data before committing. Custom macOS defaults and unknown app
schemas require an explicit declaration edit.

`just discover snapshot tracked` or `just discover snapshot global` writes
ignored inventory files for human review; it does not import their contents
into managed configuration. After changing declarations, review `git diff`,
validate with `just check repo`, and apply on the intended Mac.
