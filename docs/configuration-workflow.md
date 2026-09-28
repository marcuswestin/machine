# Configuration workflow

| Command                      | Purpose                                                                                                                                           | Writes or interruptions                                                                                                                                                    |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `just diff`                  | Compare declared packages, editor/browser extensions, dotfiles, selected app settings, Codex keys, and native import confirmations with this Mac. | Read-only report. Temporary capture files are removed. An import confirmation is not proof of live UI state.                                                               |
| `just apply`                 | Install missing packages and apply declarations without intentionally quitting desktop apps.                                                      | System switch and dotfile writes; launchd services may reload. Prints app settings still needing a restart or full apply. Weather and native imports wait for full apply.  |
| `just apply-full`            | Guided apply with native imports and app restarts.                                                                                                | Shows the affected app list and waits for Enter before quitting anything. Docker containers may be interrupted. Previously running affected apps reopen in the background. |
| `just save-machine-settings` | Review portable changes made in this Mac's app UIs and promote selected values into the repo.                                                     | Writes only selected Codex, Claude, Thaw, and Raycast declarations; never applies them back to the Mac.                                                                    |

`just apply-settings`, `just settings-apply`, and `just diff-tracked` remain
compatibility aliases. `just settings-check` performs the focused saved-settings
checks and opens System Settings to inspect Weather without changing its checkbox.
`just doctor` reports operational health. `just import-inventory tracked` writes
an optional local snapshot; `just discover-global` is for unmanaged candidates.

## Apply and conflicts

The Codex repo file `config/codex/config.toml` is the list of keys this repo
manages for the **current user**. Apply merges missing values into regular,
writable `~/.codex/config.toml`; it preserves unknown fields, local trust
decisions, hooks, and app-generated state. If a managed key already has another
value, `just apply` and `just apply-full` stop before sudo or the system switch.
Use `just save-machine-settings` to review that value and choose whether to
promote it. If you want the repo value instead, edit the local key deliberately
or choose another repo value; the tool never silently overwrites a UI change.

`just apply` does not intentionally quit desktop apps. Some changed settings
will only take effect when their app next starts. Its system switch can still
reload launchd services, and startup app setup can open declared apps that are
not running. Use `just apply-full` when the report lists pending app restarts,
Docker settings, Thaw/Raycast imports, or Weather setup. It plans restarts from
saved drift, prints the plan, and waits for Enter. The terminal stays out of the
restart set; if it would be closed, run from Terminal.app. The full pass then
checks settings and asks for visual verification. No automatic reboot, prune,
upgrade, commit, or push occurs.

If a detector cannot read a managed setting, it reports an unknown state or
stops the full pass. It never treats lack of access as a match. Native Thaw and
Raycast imports still need their own UI and confirmation; a confirmation hash
only records that the user finished that step. macOS privacy and login-item
consent remain native user actions.

To defer Docker for one full apply when its Group Container is inaccessible,
run `MACHINE_SKIP_DOCKER=1 just apply-full`. This skips the Docker settings write
and Docker restart, while keeping all other checks and app restarts. The final
settings report still shows Docker as unverified; run an ordinary `just apply-full`
later to apply and verify its saved settings.

## Save changes made in an app

`just save-machine-settings` first displays existing worktree changes. It
reviews **already-declared** Codex and Claude preference leaves, asking before
each changed value is copied. Codex trust and Claude account/session fields are
excluded. Use `just save-machine-settings browser` to review only browser
extensions. It reviews declared browser extensions one at a time: keep a missing
Chrome extension in the repo, remove its declaration, or skip. A kept Chrome Web
Store extension is installed through Chrome's UI during the guided full apply;
the repo does not write to Chrome's protected profile directory.
An extension found only on the Mac is never removed by apply. If browser profile
access is denied, the command stops without treating it as an empty extension
list. Repo-backed symlinks already reflect edits and are shown in `git status`;
the command does not recopy their files. For Thaw, export a single
native profile to `~/Desktop/Thaw Profiles.json`, then enter that path. For
Raycast, enter a native `.rayconfig` or JSON export; only existing portable
preference keys are offered. Raycast extensions, snippets, account data, and
unknown fields are excluded. Both native export steps can be skipped.

Custom macOS defaults declared in Nix and app settings without a known safe
schema need an explicit repo edit. Run `just diff` to find them. Package version
pins, credentials, device identifiers, permissions, sessions, histories, and
caches are never imported by this command. Review `git diff` and validate before
committing. On another Mac, pull and run `just apply` or `just apply-full`.
