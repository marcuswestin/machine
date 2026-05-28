#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  printf 'usage: %s title message [-- command [args...]]\n' "$0" >&2
  exit 64
fi

title="$1"
message="$2"
shift 2

if [ "${1:-}" = "--" ]; then
  shift
fi

printf '\n'
printf '========================================================================\n' >&2
printf 'ATTENTION REQUIRED: %s\n' "$title" >&2
printf '%s\n' "$message" >&2
printf '========================================================================\n' >&2
printf '\a' >&2

/usr/bin/osascript - "$title" "$message" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  set notificationTitle to item 1 of argv
  set notificationBody to item 2 of argv
  display notification notificationBody with title notificationTitle sound name "Glass"
end run
APPLESCRIPT

if [ "$#" -gt 0 ]; then
  exec "$@"
fi
