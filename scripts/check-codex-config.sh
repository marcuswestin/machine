#!/usr/bin/env bash
# Report drift in Codex's tracked system layer without importing local trust state.
set -euo pipefail

repo_dir="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
declared="${repo_dir}/config/codex/config.toml"
system="/etc/codex/config.toml"
user="${HOME}/.codex/config.toml"

if [[ ! -e "$system" ]]; then
  printf 'System defaults are absent; run just apply.\n'
elif cmp -s "$declared" "$system"; then
  printf 'System defaults match the repository.\n'
else
  printf 'System defaults differ from the repository; run just apply.\n'
fi

if [[ -L "$user" ]]; then
  printf 'User config is still a symlink; migrate it to a writable local file.\n'
elif [[ -e "$user" ]]; then
  taplo lint "$user"
  if [[ -e "$system" ]]; then
    overlaps="$(
      jq -r -s '
        .[0] as $system | .[1] as $user |
        $system | paths(scalars) as $path |
        select((try ($user | getpath($path)) catch null) != null) |
        $path | map(tostring) | join(".")
      ' <(taplo get -o json -f "$system") <(taplo get -o json -f "$user")
    )"
    if [[ -n "$overlaps" ]]; then
      printf 'User config overrides tracked defaults:\n%s\n' "$overlaps"
    else
      printf 'Writable user config has no tracked-setting overrides.\n'
    fi
  fi
else
  printf 'No user config yet; Codex will create one as needed.\n'
fi
