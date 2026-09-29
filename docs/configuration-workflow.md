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
- `just prune`: list undeclared Homebrew packages and editor extensions, then
  ask whether to remove them (default: no). `just prune plan` only previews;
  `just prune apply` removes them explicitly without a prompt. Changed
  dotfiles are not prune candidates.

## Apply and conflicts

The Codex repo file `config/codex/config.toml` lists keys managed for the
**current user**. Apply merges missing values into regular, writable
`~/.codex/config.toml` while preserving unknown fields, local trust decisions,
hooks, and app-generated state. A conflicting managed value prompts before
sudo or the system switch whether to use the Mac value in the repo declaration
(default: yes). Answer no to keep the repo value and apply it to the Mac.
Noninteractive applies stop at unresolved conflicts; use
`just import-from-machine codex` to review them in a terminal.

`just apply-to-machine` does not intentionally quit desktop apps. Some changed
settings only take effect when their app next starts; the command prints pending
restart work. `just apply-to-machine full` plans affected app restarts, shows the
plan, and waits for Enter. It also guides Thaw import and native
consent. Run it from Terminal.app if it needs to quit your current terminal.
It does not reboot, prune, upgrade, commit, or push.

Raycast uses Control-Space and Spotlight search uses Command-Space. The full
apply reserves the former from macOS input-source switching, restores the
latter, and relaunches Raycast when its saved hotkey differs. Native Raycast
export/import is paused for the Spotlight trial; the scripts print a reminder
instead of prompting for a Raycast backup or import. No Mac restart or separate
keyboard setting is required after a successful full apply. See
`config/raycast/README.md`.

If a detector cannot read a managed setting, it reports an unknown state or
stops the full pass. A recorded Thaw import confirms the user
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
full apply. The command can also guide a Thaw export. Use a scope
argument to review only one app.

If macOS blocks a browser profile during the combined import, that browser
review remains **UNVERIFIED** and the command continues to Thaw.
`just import-from-machine browser` still stops until the terminal has access;
neither path changes browser declarations based on an unreadable profile.

For native exports, choose Desktop in the save panel. Look for the fresh file
there first; if absent, check the folder shown in the panel and other likely
export folders, then ask where it was saved. Do not substitute an older file.
For Thaw, save the live layout and configuration into a profile before export.
The global **Export Profiles** action can include several profiles;
`just import-from-machine thaw` asks which one to keep in the repo. Thaw
exports include `menuBarLayout.itemOrder` and `itemSectionMap`, so the saved
profile records item order and which items are hidden or visible. The diff
checks whether this export was confirmed as applied on this Mac; it cannot
compare Thaw's current live layout to the file. Thaw 3.0.0-alpha.7 exposes
individual allowlisted settings through `thaw://`, but
not a complete profile or menu item order export/import, so the native profile
file is required for the full transfer.

Raycast native import/export is paused during the Spotlight trial.
`just import-from-machine raycast` prints a reminder and does not request an
export; full apply does not import one. The declared hotkey still comes from
`config/raycast/settings.json` through nix-darwin. See
`config/raycast/README.md` for the deferred native transfer procedure.

`just discover global` writes ignored candidate reports under
`inventory-global/discovery/` for unmanaged apps, defaults domains, preference
plists, launch items, fonts, system extensions, and shell snippets. It finds
candidate surfaces rather than proving which individual preference keys should
be tracked. `just discover apps` lists preference key names and config-file
paths for declared cask apps, omitting values and known sensitive files. Use
`just discover snapshot global` when readable defaults plists are needed for
manual key-level review. None of these commands promotes values into config;
review each candidate before declaring it.

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
