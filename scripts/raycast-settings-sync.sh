#!/usr/bin/env bash
# Sync Raycast declarative settings: if config/raycast/settings.json changed since
# last run, gzip it to .rayconfig and open it for Raycast import.
set -euo pipefail

repo_root="${1:?missing repo root}"
force="${2:-}"

json="$repo_root/config/raycast/settings.json"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/machine"
state_file="$state_dir/raycast-settings.sha256"
out="$repo_root/config/raycast/settings.rayconfig"

if [[ ! -f "$json" ]]; then
  if [[ "$force" == "force" ]]; then
    printf 'missing %s\n' "$json" >&2
    exit 1
  fi
  exit 0
fi

mkdir -p "$state_dir"
current="$(shasum -a 256 "$json" | awk '{print $1}')"

if [[ "$force" != "force" ]] && [[ -f "$state_file" ]] && [[ "$(cat "$state_file")" == "$current" ]]; then
  exit 0
fi

gzip -cn "$json" >"$out"
printf 'Raycast settings.json changed; opened %s for import.\n' "$out" >&2
"$repo_root/scripts/attention.sh" \
  "Raycast import needs attention" \
  "Raycast settings changed; a .rayconfig import is about to open."
open "$out"
echo "$current" >"$state_file"
