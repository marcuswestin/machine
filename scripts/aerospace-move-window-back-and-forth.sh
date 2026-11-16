#!/usr/bin/env bash
# Move the focused window to the workspace alt-tab would switch to, then focus it.
# AeroSpace has no move-node-to-workspace back-and-forth
# (https://github.com/nikitabobko/AeroSpace/issues/434). Switch there first so the
# focused workspace is the target, then move the original window by id.
set -euo pipefail

window_id=$(aerospace list-windows --focused --format '%{window-id}')
[[ -n "$window_id" ]] || exit 0

# mkdir is the lock: macOS has no flock(1). A second press exits instead of
# interleaving workspace-back-and-forth with another invocation.
lock_dir="/tmp/aerospace-move-window-back-and-forth.lock"
if ! mkdir "$lock_dir" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT

aerospace workspace-back-and-forth
target=$(aerospace list-workspaces --focused)
aerospace move-node-to-workspace --focus-follows-window --window-id "$window_id" -- "$target"
