---
name: apply-full-machine
description: Run a requested full apply of the machine repo, including affected app restarts and native Thaw import. Raycast native sync is paused during the Spotlight trial. Use for `just apply-to-machine` or completing its deferred native steps; use diff-tracked-machine for read-only drift review.
---

# Full machine apply

Work in `/Users/ro/code/machine`. Read `AGENTS.md` and the current `Justfile` and scripts before running the recipe. Check `git status --short`, Codex managed-key preflight, and `MACHINE_RESTART_STRICT=1 just _restart-plan`. Ask for unresolved consequential choices before starting; an explicit choice to include Docker authorizes its restart and possible container interruption. Never run `just prune` as part of this workflow.

Run `just apply-to-machine` from a user-accessible Terminal when sudo requires the user's password. Ask the user to type it in Terminal, never in chat. Monitor the command through its own output or a task-specific log. Keep app windows in the background when possible, and tell the user before native UI requires focus. Do not confirm a prompt until its action is complete. If a guided command is blocked by a prompt or permission, leave its confirmation pending and report the exact blocker.

## Raycast during the Spotlight trial

Native Raycast export/import is paused. The full apply prints a reminder and must not open an export or import prompt. Its declared Control-Space hotkey still comes from `config/raycast/settings.json` through nix-darwin, and the restart plan relaunches Raycast when that saved preference differs. Verify Control-Space opens Raycast and Command-Space opens Spotlight; do not claim that other Raycast preferences were synchronized. See `config/raycast/README.md` for the deferred native procedure.

Before importing Thaw, instruct the user to save the current configuration into a profile and export that profile to Desktop, then press Enter in the full apply prompt. Keep backups outside the repo and restrict their permissions to the user. Do not automate this backup. Look on Desktop for the resulting file first; if missing, check other likely export folders before asking where it was saved. Never substitute an older export just because its name looks right. The installed Thaw 3.0.0-alpha.7 `thaw://` API exposes individual settings but not complete profile export/import or saved menu item order.

## Thaw native profile

Use `thaw://open-settings` only to expose Thaw's settings window, then computer control in Profiles to import `/Users/ro/code/machine/config/thaw/profile.json` and apply the newly imported profile. Confirm the toolbar shows it active. Native import creates a new profile; distinguish it from older profiles with the same name. Do not write Thaw's private profile files or preferences directly, and do not delete older profiles without a separate review. Only after the native Apply succeeds, record the normalized JSON hash in `~/.local/state/machine/thaw-profile.sha256`.

After the recipe and native actions, run `just diff settings` and `just check machine --json`. Report matches, differences, warnings, deferred checks, app restarts, and `git status --short` separately. Do not call the run complete while a required native import or final apply prompt is still pending.
