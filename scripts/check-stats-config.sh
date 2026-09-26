#!/usr/bin/env bash
# Compare only declared Stats preferences; never import private or transient state.
set -euo pipefail

repo_dir="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
host="${2:-${MACHINE_HOST:-machine}}"
desired="$(nix --extra-experimental-features 'nix-command flakes' eval \
  --offline --no-write-lock-file --json \
  "${repo_dir}#darwinConfigurations.${host}.config.system.defaults.CustomUserPreferences" \
  --apply 'prefs: prefs."eu.exelban.Stats"')"
# A Stats plist also contains Data-valued file-dialog bookmarks, which plutil
# cannot convert to JSON. Parse the plist and select declared keys first.
actual="$(defaults export eu.exelban.Stats - | /usr/bin/python3 -c '
import json, plistlib, sys
declared = json.loads(sys.argv[1])
saved = plistlib.loads(sys.stdin.buffer.read())
print(json.dumps({key: saved[key] for key in declared if key in saved}))
' "$desired")"

differences="$(jq -nr --argjson desired "$desired" --argjson actual "$actual" '
  $desired | to_entries[] |
  .key as $key | .value as $expected |
  select(($actual | has($key) | not) or $actual[$key] != $expected) |
  "\($key): declared=\($expected | tojson); saved=" +
    (if $actual | has($key) then ($actual[$key] | tojson) else "<unset; app default applies>" end)
')"
if [[ -n "$differences" ]]; then
  printf 'Stats preferences differ from the repository:\n%s\n' "$differences"
  printf 'Quit Stats, run just apply, then reopen Stats to load the declared preferences.\n'
else
  printf 'Saved Stats preferences match all declared keys.\n'
fi
printf 'This checks saved preferences, not running widgets, hardware support, or macOS/Thaw visibility.\n'
