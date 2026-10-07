#!/usr/bin/env bash
# Guided repo -> Mac apply. All system mutation still uses the owning private apply recipe.
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "${repo_dir}/scripts/settings-prompt.sh"
cd "$repo_dir"

# The full pass closes only apps with a saved setting that currently differs.
partial_hint='To apply without quitting or restarting any apps, run: just partial-apply-to-machine'
printf '%s\n' "$partial_hint"
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
  printf 'Run just apply-to-machine from Terminal.app; this terminal may close during app restart.\n' >&2
  printf '%s\n' "$partial_hint" >&2
  exit 2
fi

confirm_status=0
confirm_prompt "Step 1 of 4 — Prepare this Mac

1. This will quit these running apps, apply their changed settings, and reopen
   them in the background:
${plan:-   None detected.}
   Save work in those apps first. Run from Terminal.app if your current
   terminal is listed.
2. ${partial_hint}
   Docker settings import, export, and apply are disabled for now.
3. Be ready for sudo and native permission/import prompts. This runs the full
   apply-to-machine: system defaults, missing packages, dotfiles, and editor extensions.
4. Before continuing, save the current Thaw layout and configuration into
   a profile and export that profile to Desktop as a backup. Keep the backup
   outside the repo. On a fresh Mac with no Thaw setup, there is nothing to
   back up. Raycast native export/import is paused for the Spotlight trial.

Nothing has been applied or quit yet." "Restart the apps above and apply?" || confirm_status=$?
if (( confirm_status == 2 )); then
  printf 'Nothing was applied or quit. %s\n' "$partial_hint"
  exit 0
fi
(( confirm_status == 0 )) || exit 1

app_running() {
  local app="$1" state
  # -a: macOS pgrep otherwise skips its ancestors, missing Claude when run from Claude Code.
  if [[ "$app" == Claude ]] && pgrep -a -f '^/Applications/Claude[.]app/Contents/MacOS/Claude( |$)' >/dev/null; then
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
      printf '%s did not quit; close it and rerun just apply-to-machine.\n' "$app" >&2
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
  printf 'Resolve its reported issue, then rerun just apply-to-machine.\n' >&2
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

The report above checked saved preferences.

1. Review the report above. Resolve DIFF, MISSING, or UNVERIFIED items before
   confirming, except Docker while its settings sync is disabled. A command completing
   does not mean all settings match.
${docker_review}

If a mismatch remains, Ctrl-C leaves verification unfinished. Full checklist:
docs/reviews/2026-09-27-settings-acceptance.md"

printf '\nApply completed and you confirmed the visual checklist.\n'
printf 'This acknowledgement is not an automated proof of every app setting.\n'
printf 'No reboot was requested by this recipe. Review any macOS logout/restart prompts.\n'
printf 'No changes were committed or pushed.\n'
