#!/usr/bin/env bash
set -euo pipefail

aerospace_process="/Applications/AeroSpace.app/Contents/MacOS/AeroSpace"
aerospace_server_disabled="AeroSpace server is disabled and doesn't accept commands"

if ! pgrep -x AeroSpace >/dev/null 2>&1 && ! pgrep -f "$aerospace_process" >/dev/null 2>&1; then
  printf 'AeroSpace is not running; config will load on next launch.\n'
  exit 0
fi

last_output=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if last_output="$(aerospace reload-config --no-gui 2>&1)"; then
    [ -z "$last_output" ] || printf '%s\n' "$last_output"
    exit 0
  fi

  if printf '%s\n' "$last_output" | grep -Fq "$aerospace_server_disabled"; then
    printf 'AeroSpace server is disabled; config will load when AeroSpace is enabled.\n'
    exit 0
  fi

  sleep 1
done

if printf '%s\n' "$last_output" | grep -Fq "Can't connect to AeroSpace server"; then
  printf 'AeroSpace is running, but its server is not accepting reload-config yet; config will load when AeroSpace is ready.\n'
  exit 0
fi

printf '%s\n' "$last_output" >&2
exit 1
