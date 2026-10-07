#!/usr/bin/env bash
# Capture a native Thaw profile export for the guided import/apply step in just apply-to-machine.
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
destination="${repo_dir}/config/thaw/profile.json"
suggested="${HOME}/Desktop/Thaw Profiles.json"
source="${1:-}"
export_marker=""

if [[ -z "$source" ]]; then
  export_marker="$(mktemp)"
  trap 'rm -f "$export_marker"' EXIT
  cat <<EOF
Export the CURRENT Thaw configuration

1. Open Thaw Settings > Profiles.
2. Enter a profile name and choose Save Current. If reusing a profile,
   choose Update > Update All first, so it includes today's layout AND settings.
3. In that profile's more-actions menu (...), choose Export, or choose
   Export Profiles if the menu is unavailable. A multi-profile file will
   prompt you to choose one profile for the repo.
4. Save as: $suggested
   (Cmd-Shift-G in the save dialog lets you type the folder. Thaw remembers
   the last folder used, so check where it actually saves.)

Two separate files (no symlink):
  Handoff (Thaw writes):  $suggested
  Repo copy (we write):   $destination
After you press Enter, this recipe reads the handoff file, keeps the one profile
you pick, sorts its keys, and overwrites the repo copy. The handoff file is left
untouched; delete it whenever you like. At the Desktop path, only a file newer
than this prompt is accepted, so an older export there is never reused.

Then review git diff -- config/thaw/profile.json before committing (profiles
can include custom names, display identifiers, and automation settings), and
run just apply-to-machine to open the guided Thaw import/apply step.

EOF
  if [[ ! -t 0 ]]; then
    printf 'After exporting, tell Codex it is ready and where you saved the file.\n'
    printf 'Or run: just import-from-machine thaw\n'
    exit 0
  fi
  printf 'Press Enter when the Desktop export is complete, enter another path, or type skip: '
  IFS= read -r source
  if [[ "$source" == skip ]]; then
    printf 'Thaw export skipped; the repo profile was not changed.\n'
    exit 0
  fi
  source="${source:-$suggested}"
  if [[ "$source" == "$suggested" && ! "$source" -nt "$export_marker" ]]; then
    printf 'No new Thaw Profiles.json was found on Desktop. Check the save dialog folder, then enter the new export path: '
    IFS= read -r source
    [[ -n "$source" ]] || { printf 'A fresh Thaw export path is required.\n' >&2; exit 1; }
  fi
fi

# Expand a literal ~/ entered at the prompt without evaluating shell input.
if [[ "$source" == '~/'* ]]; then
  source="${HOME}/${source:2}"
fi

scratch="$(mktemp -d)"
output_tmp=""
trap 'rm -rf "$scratch"; if [[ -n "$output_tmp" ]]; then rm -f "$output_tmp"; fi; if [[ -n "$export_marker" ]]; then rm -f "$export_marker"; fi' EXIT
cat < "$source" > "$scratch/input.json"

# Export Profiles... can include several profiles. Keep exactly the one the
# user wants to replicate on another Mac.
entry_count="$(jq -er 'select(.version == 1 and (.entries | type == "array")) | .entries | length' "$scratch/input.json")"
if (( entry_count > 1 )); then
  if [[ ! -t 0 ]]; then
    printf 'Export contains %s profiles. Run just import-from-machine thaw in a terminal to select one.\n' "$entry_count" >&2
    exit 1
  fi
  printf 'The native export contains %s profiles. Select one for the repo:\n' "$entry_count"
  jq -r '.entries | to_entries[] | "  \(.key + 1). \(.value.profile.name)"' "$scratch/input.json"
  printf 'Profile number: '
  IFS= read -r profile_number
  if [[ ! "$profile_number" =~ ^[1-9][0-9]*$ ]] || (( profile_number > entry_count )); then
    printf 'Choose a number from 1 to %s.\n' "$entry_count" >&2
    exit 1
  fi
  jq --argjson index "$((profile_number - 1))" '{version, entries: [.entries[$index]]}' "$scratch/input.json" > "$scratch/selected.json"
  mv "$scratch/selected.json" "$scratch/input.json"
fi

# Thaw 3 native exports wrap profiles as {version: 1, entries: [{profile: ...}]}.
# Check the identifying fields without discarding additional native fields.
if ! jq -e -s '
  length == 1 and
  (.[0] | type == "object" and .version == 1 and
    (.entries | type == "array" and length == 1 and all(.[];
      .profile | type == "object" and
      (.name | type == "string") and
      (.generalSettings | type == "object") and
      (.appearanceConfiguration | type == "object") and
      (.menuBarLayout |
        type == "object" and
        (.itemOrder | type == "object" and
          (.visible | type == "array") and
          (.hidden | type == "array")) and
        (.itemSectionMap | type == "object"))
    )))
' "$scratch/input.json" > /dev/null; then
  printf 'Expected a native export containing one Thaw profile. Export that profile, then retry.\n' >&2
  exit 1
fi

mkdir -p "$(dirname -- "$destination")"
output_tmp="$(mktemp "${destination}.XXXXXX")"
jq --sort-keys . "$scratch/input.json" > "$output_tmp"
chmod 0644 "$output_tmp"
mv -f -- "$output_tmp" "$destination"
output_tmp=""
printf 'Saved Thaw profile export: %s\n' "$destination"
printf 'Review with: git diff -- config/thaw/profile.json (or open it if newly added).\n'
