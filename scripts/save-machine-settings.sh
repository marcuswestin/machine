#!/usr/bin/env bash
# Guided Mac -> repo promotion of portable settings. No apply or restart here.
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
scope="${1:-all}"
case "$scope" in
  all|browser) ;;
  *) printf 'usage: just save-machine-settings [all|browser]\n' >&2; exit 64 ;;
esac
if [[ ! -t 0 ]]; then
  printf 'Run just save-machine-settings in an interactive terminal.\n' >&2
  exit 2
fi

printf 'Existing repo changes (left in place):\n'
git status --short
if [[ "$scope" == browser ]]; then
  printf '\nResolve browser extensions one at a time:\n'
  bun scripts/browser-extension-review.ts resolve "$repo_dir"
  printf '\nReview git diff before applying; nothing was applied or restarted.\n'
  exit 0
fi
printf '\n1. Review Codex settings that changed in the app.\n'
bun scripts/codex-config-sync.ts save
printf '\n2. Review declared Claude Desktop preferences.\n'
bun scripts/app-preferences.ts save

printf '\n3. Resolve declared browser extensions one at a time.\n'
bun scripts/browser-extension-review.ts resolve "$repo_dir"

printf '\n4. Thaw: export the current profile through its native UI if its layout changed.\n'
printf '   Save it as ~/Desktop/Thaw Profiles.json. Enter its path to import, or press Enter to skip: '
IFS= read -r thaw_path || exit 1
if [[ -n "$thaw_path" ]]; then
  [[ "$thaw_path" == '~/'* ]] && thaw_path="${HOME}/${thaw_path:2}"
  bash scripts/export-thaw.sh "$thaw_path"
fi

printf '\n5. Raycast: export Settings from Raycast if they changed.\n'
printf '   Enter the .rayconfig or JSON export path to review existing portable preference keys, or press Enter to skip: '
IFS= read -r raycast_path || exit 1
if [[ -n "$raycast_path" ]]; then
  [[ "$raycast_path" == '~/'* ]] && raycast_path="${HOME}/${raycast_path:2}"
  bun scripts/raycast-settings-save.ts "$raycast_path"
fi

printf '\n6. Repo-backed files already record edits through their symlinks. Review their diffs:\n'
taplo lint config/codex/config.toml
jq -e . config/app-preferences.json config/raycast/settings.json config/thaw/profile.json > /dev/null
git status --short
git diff --stat -- config/codex/config.toml config/app-preferences.json config/thaw/profile.json config/raycast/settings.json
printf '\nCustom macOS defaults and unlisted app keys require a deliberate declaration change.\n'
printf 'Run just diff to identify those; no unknown app state was copied into the repo.\n'
printf 'Review git diff before committing. Nothing was applied, restarted, staged, or pushed.\n'
