#!/usr/bin/env bash
# Stop hook: post a macOS desktop notification (with sound) when a turn finishes.
# Title  = feature (git branch, else directory name)
# Subtitle = project directory
# Body   = short summary taken from the final assistant message.
set -uo pipefail

input=$(cat)

jqr() { printf '%s' "$input" | jq -r "$1" 2>/dev/null; }

transcript=$(jqr '.transcript_path // empty')
cwd=$(jqr '.cwd // empty')
[ -n "$cwd" ] || cwd=$PWD

project=$(basename "$cwd")
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
feature=${branch:-$project}

summary=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  summary=$(
    tail -n 600 "$transcript" 2>/dev/null |
      jq -rs '
        map(
          select(.type == "assistant")
          | (.message.content? // [])
          | (if type == "array" then . else [] end)
          | map(select(.type == "text") | .text)
          | join(" ")
        )
        | map(select(. != null and . != ""))
        | last // ""
      ' 2>/dev/null
  )
fi

# Flatten to a single line, drop the noisiest markdown, and clip for the banner.
summary=$(
  printf '%s' "$summary" |
    tr '\n\t' '  ' |
    sed -e 's/`//g' -e 's/\*\*//g' -e 's/  */ /g' -e 's/^ //' -e 's/ $//'
)
[ -n "$summary" ] || summary="Turn finished."
if [ "${#summary}" -gt 180 ]; then
  summary="${summary:0:177}..."
fi

title="Claude Code · $feature"
subtitle="$project"

# macOS draws the posting app's icon on banners; osascript always shows Script Editor.
# Claude Notify.app is a tiny UserNotifications helper (LSUIElement — no Dock tile)
# with the Claude mark plus a gold bell badge so it is distinct from Claude.app.
# Rebuild with notify/build.sh if the icon drifts.
notify_bin=$(CDPATH= cd -- "$(dirname "$0")" && pwd)/notify/Claude\ Notify.app/Contents/MacOS/claude-notify
# Background so the Stop hook does not wait on Notification Center / TCC.
"$notify_bin" -title "$title" -subtitle "$subtitle" -message "$summary" -sound Glass >/dev/null 2>&1 &

exit 0
