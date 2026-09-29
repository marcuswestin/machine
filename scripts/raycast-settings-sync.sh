#!/usr/bin/env bash
# Open the saved native Raycast Settings export for a guided import. Older
# setups without one still use the generated gzip JSON fallback.
set -euo pipefail

repo_root="${1:?missing repo root}"
force="${2:-}"

json="$repo_root/config/raycast/settings.json"
native="$repo_root/config/raycast/settings-native.rayconfig"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/machine"
# Older stamps recorded opening the file, not completing the native import.
state_file="$state_dir/raycast-settings-confirmed.sha256"
out="$repo_root/config/raycast/settings.rayconfig"

if [[ ! -f "$json" ]]; then
  if [[ "$force" == "force" ]]; then
    printf 'missing %s\n' "$json" >&2
    exit 1
  fi
  exit 0
fi

if [[ -f "$native" ]]; then
  source_file="$native"
else
  source_file="$json"
fi
current="$(shasum -a 256 "$source_file" | awk '{print $1}')"

if [[ "$force" == check ]]; then
  if [[ -f "$state_file" ]] && [[ "$(cat "$state_file")" == "$current" ]]; then
    printf 'Raycast export matches the last confirmed import (not a live settings comparison).\n'
  else
    printf 'Raycast export awaits native import confirmation; run just apply-to-machine full.\n'
  fi
  exit 0
fi

if [[ "$force" != "force" ]] && [[ -f "$state_file" ]] && [[ "$(cat "$state_file")" == "$current" ]]; then
  exit 0
fi

if [[ "$source_file" == "$json" ]]; then
  gzip -cn "$json" >"$out"
else
  out="$native"
fi
printf 'Raycast settings export changed; opened %s for import.\n' "$out" >&2
open "$out"
if [[ "${MACHINE_SETTINGS_INTERACTIVE:-}" == 1 ]]; then
  source "${repo_root}/scripts/settings-prompt.sh"
  settings_prompt "Apply saved Raycast settings:

1. In the Raycast import window, review the settings being imported.
2. Complete the native import from:
$out
3. Check the hotkey and appearance. Return here after the import completes.

Ctrl-C leaves this import pending."
else
"$repo_root/scripts/attention.sh" \
  "Raycast import needs attention" \
  "Raycast settings changed; a .rayconfig import is about to open."
osascript <<'APPLESCRIPT' > /dev/null
display dialog "Complete the Raycast settings import in Raycast, then click Imported here. Cancel leaves this import pending for the next apply." with title "Confirm Raycast import" buttons {"Cancel", "Imported"} default button "Cancel" cancel button "Cancel"
APPLESCRIPT
fi
mkdir -p "$state_dir"
echo "$current" >"$state_file"
