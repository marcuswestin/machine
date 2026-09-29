#!/usr/bin/env bash
# Guided repo -> Mac apply. All system mutation still uses the owning private apply recipe.
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "${repo_dir}/scripts/settings-prompt.sh"
cd "$repo_dir"

# The full pass closes only apps with a saved setting that currently differs.
printf 'Checking Codex configuration before the full apply...\n'
bun "${repo_dir}/scripts/codex-config-sync.ts" preflight
printf 'Preparing the app restart plan (this can take several seconds)...\n'
plan="$(MACHINE_RESTART_STRICT=1 just _restart-plan)"
printf 'Docker settings import, export, and apply are disabled for now.\n'
restart_apps=()
if [[ -n "$plan" ]]; then
  while IFS= read -r app; do
    if [[ "$app" == Docker ]]; then continue; fi
    restart_apps+=("$app")
  done <<< "$plan"
fi
if { [[ "${TERM_PROGRAM:-}" == iTerm.app ]] && [[ " $plan " == *"iTerm"* ]]; } \
  || { [[ "${TERM_PROGRAM:-}" == Codex || "${TERM_PROGRAM:-}" == ChatGPT ]] && [[ " $plan " == *"ChatGPT"* ]]; }; then
  printf 'Run just apply-to-machine full from Terminal.app; this terminal may close during app restart.\n' >&2
  exit 2
fi

settings_prompt "Step 1 of 4 — Prepare this Mac

1. Run this command from Terminal.app if it plans to quit your current terminal;
   save work in affected apps.
2. Changed settings require restarting these apps if running:
${plan:-   None detected.}
   Docker settings import, export, and apply are disabled for now.
3. Be ready for sudo and native permission/import prompts. This runs the full
   apply-to-machine: system defaults, missing packages, dotfiles, and editor extensions.
4. The command will relaunch previously running affected apps in the background
   after applying.
5. Before pressing Enter, save the current Thaw layout and configuration into
   a profile and export that profile to Desktop as a backup. Keep the backup
   outside the repo. On a fresh Mac with no Thaw setup, there is nothing to
   back up. Raycast native export/import is paused for the Spotlight trial.

Nothing has been applied or quit yet. Press Enter after completing those exports
to start the shutdown and apply."

app_running() {
  local app="$1" state
  if [[ "$app" == Claude ]] && pgrep -f '^/Applications/Claude[.]app/Contents/MacOS/Claude( |$)' >/dev/null; then
    return 0
  fi
  state="$(osascript -e 'on run argv' -e 'set appName to item 1 of argv' -e 'if application appName is running then return "running"' -e 'return "stopped"' -e 'end run' "$app")" || {
    printf 'Could not check whether %s is running.\n' "$app" >&2
    exit 1
  }
  [[ "$state" == running ]]
}

quit_app() {
  local app="$1" attempt limit=20
  [[ "$app" == Docker ]] && limit=60
  printf 'Quitting %s...\n' "$app"
  osascript -e 'on run argv' -e 'set appName to item 1 of argv' -e 'tell application appName to quit' -e 'end run' "$app"
  for (( attempt = 1; attempt <= limit; attempt++ )); do
    if ! app_running "$app"; then
      return 0
    fi
    if (( attempt == limit )); then
      printf '%s did not quit; close it and rerun just apply-to-machine full.\n' "$app" >&2
      return 1
    fi
    sleep 1
  done
}

previously_running=()
for app in "${restart_apps[@]}"; do
  if app_running "$app"; then
    previously_running+=("$app")
    quit_app "$app"
  fi
done

printf '\nStep 2 of 4 — Apply repository settings\n'
# Native imports retain their content hashes; only the acknowledgement UI changes.
export MACHINE_SETTINGS_INTERACTIVE=1 MACHINE_APPLY_MODE=full
if ! just _apply-to-machine; then
  printf '\nApply stopped. The failed step above remains incomplete.\n' >&2
  for app in "${previously_running[@]}"; do
    printf 'Restoring %s in the background...\n' "$app"
    open -gj -a "$app"
  done
  printf 'Resolve its reported issue, then rerun just apply-to-machine full.\n' >&2
  printf 'Approve any native permission or import prompts through macOS; no consent is bypassed.\n' >&2
  exit 1
fi

printf '\nStep 3 of 4 — Restart apps and run settings checks\n'
for app in "${previously_running[@]}"; do
  if ! app_running "$app"; then
    printf 'Restoring %s in the background...\n' "$app"
    open -gj -a "$app"
  fi
done
just diff settings
printf 'Settings checks finished. Preparing the final visual checklist...\n'

docker_review='Docker settings import, export, and apply are disabled for now.'

settings_prompt "Step 4 of 4 — Verify the visible result

The report above checked saved preferences. These steps cover live appearance,
app behavior and choices that are local to this Mac.

1. Review the report above. Resolve DIFF, MISSING, or UNVERIFIED items before
   confirming, except Docker while its settings sync is disabled. A command completing
   does not mean all settings match.
2. Menu bar: Stats appears as one group ordered GPU → Network → Disk → Sensors
   → RAM → CPU → Battery; CodexBar shows one branded percentage item; Weather
   and Sound are visible. In Thaw, Handy, ChatGPT/Codex and Cursor should be
   hidden after its rehide interval. Adjust display associations if needed.
3. Local choices: sign into desired CodexBar providers, choose Weather's first
   location and this Mac's sound output. Complete native location consent if wanted.
4. Raycast: Control-Space opens Raycast; Command-Space opens Spotlight. Native
   Raycast export/import is paused for this trial; check its hotkey manually.
5. iTerm2: open a new window to inspect the Machine profile, fonts and colors.
   Chrome: in your Default profile, open
   https://chromewebstore.google.com/detail/pejdijmoenmkgeppbflobdenhhabjlaj
   and install iCloud Passwords if missing. Approve the native Chrome prompts,
   then confirm it is enabled at chrome://extensions.
6. Codex: the managed number-shortcut setting was checked above. Confirm that
   Command-1–9 switches chats if you need functional proof. If ChatGPT/Codex was
   restarted, start a new task to load updated global instructions.
${docker_review}

If a mismatch remains, Ctrl-C leaves verification unfinished. Full checklist:
docs/reviews/2026-09-27-settings-acceptance.md"

printf '\nApply completed and you confirmed the visual checklist.\n'
printf 'This acknowledgement is not an automated proof of every app setting.\n'
printf 'No reboot was requested by this recipe. Review any macOS logout/restart prompts.\n'
printf 'No changes were committed or pushed.\n'
