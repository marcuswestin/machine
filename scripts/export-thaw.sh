#!/usr/bin/env bash
# Capture a native Thaw profile export for the guided import/apply step in just apply-to-machine full.
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
destination="${repo_dir}/config/thaw/profile.json"
suggested="${HOME}/Desktop/Thaw Profiles.json"
source="${1:-}"

if [[ -z "$source" ]]; then
  cat <<EOF
Export the CURRENT Thaw configuration

1. Open Thaw Settings > Profiles.
2. Enter a profile name and choose Save Current. If reusing a profile,
   choose Update > Update All first, so it includes today's layout AND settings.
3. In that profile's more-actions menu (...), choose Export.
4. Save as: $suggested
   In the save dialog, Cmd-Shift-G lets you enter the Desktop folder.

Thaw remembers the save-dialog folder; the path above is our suggested location.
This recipe saves the export to:
  $destination
It replaces the previous repo snapshot. Review its git diff before committing;
profiles can include custom names, display identifiers, and automation settings.
Run just apply-to-machine full to open the guided Thaw import/apply step when this export changes.

EOF
  if [[ ! -t 0 ]]; then
    printf 'After exporting, tell Codex it is ready and where you saved the file.\n'
    printf 'Or run: just import-from-machine thaw\n'
    exit 0
  fi
  printf 'When exported, press Enter for the suggested path or enter another unquoted path: '
  IFS= read -r source
  source="${source:-$suggested}"
fi

# Expand a literal ~/ entered at the prompt without evaluating shell input.
if [[ "$source" == '~/'* ]]; then
  source="${HOME}/${source:2}"
fi

scratch="$(mktemp -d)"
output_tmp=""
trap 'rm -rf "$scratch"; if [[ -n "$output_tmp" ]]; then rm -f "$output_tmp"; fi' EXIT
cat < "$source" > "$scratch/input.json"

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
      (.menuBarLayout | type == "object")
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
