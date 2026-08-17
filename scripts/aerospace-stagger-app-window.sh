#!/usr/bin/env bash
# Assign an app's windows to workspaces in open order (by AeroSpace window-id).
# Used from aerospace.toml on-window-detected / after-startup-command for staggered
# layouts (e.g. Codex → 1,2,3…; Cursor → A,B,C…).
set -euo pipefail

usage() {
  printf 'usage: %s --app-id BUNDLE_ID --workspaces WS[,WS...]\n' "$0" >&2
  exit 2
}

app_id=""
workspaces_csv=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-id)
      app_id="${2:?}"
      shift 2
      ;;
    --workspaces)
      workspaces_csv="${2:?}"
      shift 2
      ;;
    -h | --help)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

[[ -n "$app_id" && -n "$workspaces_csv" ]] || usage

IFS=',' read -r -a workspaces <<< "$workspaces_csv"
((${#workspaces[@]} > 0)) || usage

if ! pgrep -x AeroSpace >/dev/null 2>&1 \
  && ! pgrep -f '/Applications/AeroSpace.app/Contents/MacOS/AeroSpace' >/dev/null 2>&1; then
  exit 0
fi

# mkdir is the lock: macOS has no flock(1). A second detection exits instead of racing.
lock_dir="/tmp/aerospace-stagger-${app_id//./-}.lock"
if ! mkdir "$lock_dir" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT

mapfile -t window_ids < <(
  aerospace list-windows --monitor all --app-bundle-id "$app_id" \
    --format '%{window-id}' 2>/dev/null | sort -n
)

for i in "${!window_ids[@]}"; do
  ws_index=$i
  if ((ws_index >= ${#workspaces[@]})); then
    ws_index=$((${#workspaces[@]} - 1))
  fi
  target_ws="${workspaces[$ws_index]}"
  wid="${window_ids[$i]}"
  aerospace move-node-to-workspace --window-id "$wid" "$target_ws" 2>/dev/null || true
done
