#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
  printf 'usage: %s command [args...]\n' "$0" >&2
  exit 64
fi

# Prompt once up front. Later privileged commands still need to invoke `sudo`
# explicitly; this only keeps the timestamp warm while the wrapped command runs.
sudo -v

# Refresh the sudo timestamp without prompting. If the timestamp is revoked or
# expires unexpectedly, the keepalive exits and the next sudo command will ask.
while true; do
  sudo -n -v 2>/dev/null || exit
  sleep 30
done &
sudo_keepalive_pid="$!"

cleanup() {
  kill "$sudo_keepalive_pid" 2>/dev/null || true
  sudo -k
}
trap cleanup EXIT

"$@"
