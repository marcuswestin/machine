#!/usr/bin/env bash
# Use CodexBar's public CLI to change toggles while preserving local credentials.
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:-check}"
case "$mode" in
  apply|check) ;;
  *) printf 'usage: %s [apply|check]\n' "$0" >&2; exit 64 ;;
esac
desired="$(jq -ce '
  if (type == "array" and length > 0 and all(.[]; type == "string") and (unique | length) == length)
  then . else error("Expected a nonempty array of unique provider IDs") end
' "${repo_dir}/config/codexbar/providers.json")"
actual="$(codexbar config providers --json)"
if ! jq -en --argjson desired "$desired" --argjson actual "$actual" \
  '$actual | map(.provider) as $known | all($desired[]; . as $id | $known | index($id) != null)' >/dev/null; then
  printf 'CodexBar does not recognize a declared provider; review the installed version.\n' >&2
  exit 1
fi
changes="$(jq -nr --argjson desired "$desired" --argjson actual "$actual" '
  $actual[] | .provider as $id |
  ($desired | index($id) != null) as $enabled |
  select(.enabled != $enabled) |
  [$id, (if $enabled then "enable" else "disable" end)] | @tsv
')"
if [[ -z "$changes" ]]; then
  [[ "$mode" == check ]] || printf 'CodexBar provider toggles match the repository.\n'
elif [[ "$mode" == check ]]; then
  jq -nr --argjson desired "$desired" --argjson actual "$actual" '
    $actual[] | .provider as $id |
    ($desired | index($id) != null) as $wanted |
    select(.enabled != $wanted) |
    "[DIFF] codexbar.provider.\($id): current=\(.enabled) -> repo=\($wanted)"
  '
else
  while IFS=$'\t' read -r provider action; do
    codexbar config "$action" --provider "$provider"
  done <<< "$changes"
fi
[[ "$mode" == check ]] || printf 'Provider login and usage availability remain local to each Mac.\n'
