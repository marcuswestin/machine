---
name: apply-full-machine
description: Run a requested full apply of the machine repo, including affected app restarts and native Raycast and Thaw imports. Use for `just apply-to-machine full` or completing its deferred native steps; use diff-tracked-machine for read-only drift review.
---

# Full machine apply

Work in `/Users/ro/code/machine`. Read `AGENTS.md` and the current `Justfile` and scripts before running the recipe. Check `git status --short`, Codex managed-key preflight, and `MACHINE_RESTART_STRICT=1 just _restart-plan`. Ask for unresolved consequential choices before starting; an explicit choice to include Docker authorizes its restart and possible container interruption. Never run `just prune` as part of this workflow.

Run `just apply-to-machine full` from a user-accessible Terminal when sudo requires the user's password. Ask the user to type it in Terminal, never in chat. Monitor the command through its own output or a task-specific log. Keep app windows in the background when possible, and tell the user before native UI requires focus. Do not confirm a prompt until its action is complete. If a guided command is blocked by a prompt or permission, leave its confirmation pending and report the exact blocker.

## Raycast native export and import

Before importing, instruct the user to manually export the current Raycast Settings & Data and Thaw profile to Desktop, then press Enter in the full apply prompt. Do not automate these backups. Keep them outside the repo and restrict their permissions to the user. Use export password `1234567890` for Raycast exports and imports. This shared export password is deliberately public in the repository at the user's request; do not use it for account authentication. Hand off native password entry to the user when computer-control policy requires it. Use computer control for Raycast's `Import Settings & Data` command only after the manual backups are complete.

For new native exports, direct the user to Desktop. Look there for the resulting file first. If it is missing, search other likely user export folders before asking where the user saved it. Never substitute an older export just because its name looks right. For a portable Raycast snapshot destined for the repo, instruct the user to select **Settings, Aliases & Hotkeys** only; the native encrypted export is opaque, so ask them to confirm the category selection before saving it. Raycast remembers the export passphrase, so later exports may not prompt for it. For Thaw, instruct the user to save the current configuration into a profile first, export that profile to Desktop, and keep only that profile if a bulk export contains several. The installed Thaw 3.0.0-alpha.7 `thaw://` API exposes individual settings but not complete profile export/import or saved menu item order.

Import `/Users/ro/code/machine/config/raycast/settings-native.rayconfig` through Raycast's UI when present; otherwise use the generated `config/raycast/settings.rayconfig`. Enter the public export password above for a native encrypted file. On Raycast's import checklist select only Settings, review its overwrite warning, then verify its `Import Completed` screen before recording the hash of the file selected by `scripts/raycast-settings-sync.sh` in `~/.local/state/machine/raycast-settings-confirmed.sha256`. That hash records completion, not live equality. If the import fails or is cancelled, leave the hash pending. Never commit a full backup with chats, history, snippets, credentials, or other private data to this public repo.

## Thaw native profile

Use `thaw://open-settings` only to expose Thaw's settings window, then computer control in Profiles to import `/Users/ro/code/machine/config/thaw/profile.json` and apply the newly imported profile. Confirm the toolbar shows it active. Native import creates a new profile; distinguish it from older profiles with the same name. Do not write Thaw's private profile files or preferences directly, and do not delete older profiles without a separate review. Only after the native Apply succeeds, record the normalized JSON hash in `~/.local/state/machine/thaw-profile.sha256`.

After the recipe and native actions, run `just diff settings` and `just check machine --json`. Report matches, differences, warnings, deferred checks, app restarts, and `git status --short` separately. Do not call the run complete while a required native import or final apply prompt is still pending.
