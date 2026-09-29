---
name: apply-full-machine
description: Run a requested full apply of the machine repo, including affected app restarts and native Raycast and Thaw imports. Use for `just apply-full` or completing its deferred native steps; use diff-tracked-machine for read-only drift review.
---

# Full machine apply

Work in `/Users/ro/code/machine`. Read `AGENTS.md` and the current `Justfile` and scripts before running the recipe. Check `git status --short`, Codex managed-key preflight, and `MACHINE_RESTART_STRICT=1 just _restart-plan`. Ask for unresolved consequential choices before starting; an explicit choice to include Docker authorizes its restart and possible container interruption. Never run `just prune` as part of this workflow.

Run `just apply-full` from a user-accessible Terminal when sudo requires the user's password. Ask the user to type it in Terminal, never in chat. Monitor the command through its own output or a task-specific log. Keep app windows in the background when possible, and tell the user before native UI requires focus. Do not confirm a prompt until its action is complete. If a guided command is blocked by a prompt or permission, leave its confirmation pending and report the exact blocker.

## Raycast native export and import

Use computer control for Raycast's `Export Settings & Data` and `Import Settings & Data` commands. Before an import, make a full native backup of the live state, including the categories selected by default. Save it outside the repo and restrict file permissions to the user. The export password is stored in the user's login Keychain as service `machine.raycast.export-password`, account `ro`. Retrieve it only when the native export requires it; do not put it in this skill, repo files, shell history, logs, or the final response. If Keychain access or a native credential prompt requires the user, hand off that prompt. The user asked to reuse this credential for future Raycast exports.

Import `/Users/ro/code/machine/config/raycast/settings.rayconfig` through Raycast's UI. Review Raycast's overwrite warning, then verify its `Import Completed` screen before recording the hash of `config/raycast/settings.json` in `~/.local/state/machine/raycast-settings-confirmed.sha256`. That hash records completion, not live equality. If the import fails or is cancelled, leave the hash pending. Do not import the encrypted backup as the repo declaration.

## Thaw native profile

Use `thaw://open-settings` only to expose Thaw's settings window, then computer control in Profiles to import `/Users/ro/code/machine/config/thaw/profile.json` and apply the newly imported profile. Confirm the toolbar shows it active. Native import creates a new profile; distinguish it from older profiles with the same name. Do not write Thaw's private profile files or preferences directly, and do not delete older profiles without a separate review. Only after the native Apply succeeds, record the normalized JSON hash in `~/.local/state/machine/thaw-profile.sha256`.

After the recipe and native actions, run `just settings-check` and `just doctor --json`. Report matches, differences, warnings, deferred checks, app restarts, and `git status --short` separately. Do not call the run complete while a required native import or final apply prompt is still pending.
