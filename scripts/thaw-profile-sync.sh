#!/usr/bin/env bash
# Thaw profiles have native import/apply UI, but no documented full-profile URI API.
# Keep confirmation state locally; never write Thaw's private profile database.
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
profile="${repo_dir}/config/thaw/profile.json"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/machine"
state_file="${state_dir}/thaw-profile.sha256"
mode="${1:-apply}"
case "$mode" in
  apply|force|check) ;;
  *) printf 'usage: %s [apply|force|check]\n' "$0" >&2; exit 64 ;;
esac

# A single profile makes the intended configuration unambiguous.
if ! jq -e -s '
  length == 1 and (.[0] |
    .version == 1 and (.entries | type == "array" and length == 1) and
    (.entries[0].profile |
      (.name | type == "string" and length > 0) and
      (.generalSettings | type == "object") and
      (.appearanceConfiguration | type == "object") and
      (.menuBarLayout |
        type == "object" and
        (.itemOrder | type == "object" and
          (.visible | type == "array") and
          (.hidden | type == "array")) and
        (.itemSectionMap | type == "object"))))
' "$profile" > /dev/null; then
  printf 'Expected one native Thaw profile in %s; run just import-from-machine thaw.\n' "$profile" >&2
  exit 1
fi
name="$(jq -r '.entries[0].profile.name' "$profile")"
# Hash JSON content, so formatting changes alone do not prompt another import.
current="$(jq -cS . "$profile" | shasum -a 256 | awk '{print $1}')"
confirmed=""
if [[ -f "$state_file" ]]; then
  confirmed="$(cat "$state_file")"
fi

if [[ "$mode" == check ]]; then
  if [[ "$current" != "$confirmed" ]]; then
    printf '[DIFF] thaw.profile.confirmedSha256: current=%s -> repo=%s (saved export includes item visibility and order; run just apply-to-machine to import and confirm)\n' \
      "${confirmed:-<never confirmed>}" "$current"
  fi
  exit 0
fi
if [[ "$mode" != force && "$current" == "$confirmed" ]]; then
  printf 'Thaw profile unchanged since the last confirmed apply.\n'
  exit 0
fi

message="$(cat <<EOF
Apply the saved Thaw profile "$name":

1. In Thaw Settings > Profiles, choose Import Profile(s).
2. Press Cmd-Shift-G in the file dialog and paste:
$profile
3. Apply the newly imported "$name" profile.
4. Check the menu bar layout and settings, then confirm completion below.

If this exact export is already applied on this Mac, confirm without importing
another copy. Native imports create new profiles; remove obsolete imported copies
in Thaw when replacing an older export. On another Mac, adjust display associations
and complete any permissions Thaw requests.

Cancel leaves this step pending. Unchanged exports will not prompt again.
EOF
)"
open "thaw://open-settings"
open -R "$profile"
if [[ "${MACHINE_SETTINGS_INTERACTIVE:-}" == 1 ]]; then
  source "${repo_dir}/scripts/settings-prompt.sh"
  settings_prompt "$message"
else
bash "${repo_dir}/scripts/attention.sh" "Apply saved Thaw profile" "$message"
osascript - "$message" <<'APPLESCRIPT' > /dev/null
on run argv
  display dialog (item 1 of argv) with title "Apply saved Thaw profile" buttons {"Cancel", "Applied"} default button "Cancel" cancel button "Cancel"
end run
APPLESCRIPT
fi

# Record only after the user confirms the native import AND apply completed.
mkdir -p "$state_dir"
printf '%s\n' "$current" > "$state_file"
printf 'Recorded confirmation that Thaw profile "%s" was applied.\n' "$name"
