#!/usr/bin/env bash
# Warn when enabled Login Items / background tasks fall outside the repo allowlist.
# Uses sfltool dumpbtm (Background Task Management database). See `just _audit-login-items`.
set -euo pipefail

REPO="${1:?usage: audit-login-items.sh <repo-root>}"
HOST="${MACHINE_HOST:-machine}"

mapfile -t startup_bundle_ids < <(
  nix --extra-experimental-features 'nix-command flakes' \
    eval --json "${REPO}#darwinConfigurations.${HOST}.config.machine.startupApps" \
    | jq -r '.[].bundleIdentifier'
)

# Background helpers declared in the repo but not launched via startupApps.
extra_allowed_prefixes=(
  "com.apple."
  "org.pqrs."
)

issues=0
btm_dump="$(mktemp)"
trap 'rm -f "$btm_dump"' EXIT

is_allowed_bundle() {
  local bundle_id="$1"
  local allowed prefix
  for allowed in "${startup_bundle_ids[@]}"; do
    [[ "$bundle_id" == "$allowed" ]] && return 0
  done
  for prefix in "${extra_allowed_prefixes[@]}"; do
    [[ "$bundle_id" == "${prefix}"* ]] && return 0
  done
  return 1
}

if ! /usr/bin/sfltool dumpbtm >"$btm_dump" 2>/dev/null; then
  printf 'login-items audit: skipped (sfltool dumpbtm failed)\n' >&2
  exit 0
fi

record_disposition=""
record_bundle=""

flush_record() {
  if [[ -z "$record_bundle" ]]; then
    return
  fi
  if [[ "$record_disposition" != *enabled* ]]; then
    return
  fi
  if is_allowed_bundle "$record_bundle"; then
    return
  fi
  printf 'login-items audit: unexpected enabled item: %s\n' "$record_bundle" >&2
  issues=$((issues + 1))
}

while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*[0-9]+: ]]; then
    flush_record
    record_disposition=""
    record_bundle=""
    continue
  fi
  if [[ "$line" =~ Bundle[[:space:]]Identifier:[[:space:]](.+) ]]; then
    record_bundle="${BASH_REMATCH[1]}"
  fi
  if [[ "$line" =~ Disposition:[[:space:]]\[(.*)\] ]]; then
    record_disposition="${BASH_REMATCH[1]}"
  fi
done <"$btm_dump"
flush_record

if ((issues > 0)); then
  printf 'login-items audit: %d unexpected enabled item(s). Allowlist: machine.startupApps + %s\n' \
    "$issues" "${extra_allowed_prefixes[*]}" >&2
  printf 'Inspect: sfltool dumpbtm | less\n' >&2
  printf 'Disable duplicates in System Settings → General → Login Items, or add prefs in home/.dotfiles/.\n' >&2
  exit 1
fi

printf 'login-items audit: ok (%d startup bundle id(s) allowlisted)\n' "${#startup_bundle_ids[@]}"
