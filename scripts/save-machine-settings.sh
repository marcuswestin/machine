#!/usr/bin/env bash
# Guided Mac -> repo promotion of portable settings. No apply or restart here.
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
scope="${1:-all}"
case "$scope" in
  all|browser|codex|claude|thaw|raycast|files) ;;
  *) printf 'usage: just import-from-machine [all|browser|codex|claude|thaw|raycast|files]\n' >&2; exit 64 ;;
esac
if [[ ! -t 0 ]]; then
  printf 'Run just import-from-machine in an interactive terminal.\n' >&2
  exit 2
fi

printf 'Existing repo changes (left in place):\n'
git status --short
if [[ "$scope" == all || "$scope" == codex ]]; then
  printf '\nReview Codex settings that changed in the app.\n'
  bun scripts/codex-config-sync.ts save
fi
if [[ "$scope" == all || "$scope" == claude ]]; then
  printf '\nReview declared Claude Desktop preferences.\n'
  bun scripts/app-preferences.ts save
fi
if [[ "$scope" == all || "$scope" == browser ]]; then
  printf '\nResolve declared browser extensions one at a time.\n'
  bun scripts/browser-extension-review.ts resolve "$repo_dir"
fi
if [[ "$scope" == all || "$scope" == thaw ]]; then
  if [[ "$scope" == thaw ]]; then
    bash scripts/export-thaw.sh
  else
    printf '\nThaw: export the current profile through its native UI if its layout changed.\n'
    printf 'Save it as ~/Desktop/Thaw Profiles.json. Enter its path to import, or press Enter to skip: '
    IFS= read -r thaw_path || exit 1
    if [[ -n "$thaw_path" ]]; then
      [[ "$thaw_path" == '~/'* ]] && thaw_path="${HOME}/${thaw_path:2}"
      bash scripts/export-thaw.sh "$thaw_path"
    fi
  fi
fi
if [[ "$scope" == all || "$scope" == raycast ]]; then
  printf '\nRaycast: export Settings from Raycast if they changed.\n'
  printf 'Enter the .rayconfig or JSON export path to review existing portable preference keys, or press Enter to skip: '
  IFS= read -r raycast_path || exit 1
  if [[ -n "$raycast_path" ]]; then
    [[ "$raycast_path" == '~/'* ]] && raycast_path="${HOME}/${raycast_path:2}"
    bun scripts/raycast-settings-save.ts "$raycast_path"
  fi
fi
if [[ "$scope" == files ]]; then
  printf '\nReview live app JSON/JSONC that does not already resolve to the repo.\n'
  printf 'Unknown machine-only keys can contain private data. Inspect each target before committing.\n'
  report="$(bun scripts/repo-settings-import.ts "$repo_dir" --json)"
  while IFS= read -r row; do
    id="$(jq -r '.id' <<< "$row")"
    status="$(jq -r '.status' <<< "$row")"
    repo_file="$(jq -r '.repo' <<< "$row")"
    live_file="$(jq -r '.live' <<< "$row")"
    printf '\n%s: %s\n  machine: %s\n  repo: %s\n' "$id" "$status" "$live_file" "$repo_file"
    if [[ "$status" == json_differs ]]; then
      printf 'This replaces the entire repo array with the live copy and strips JSONC comments.\n'
    else
      jq -r '.only_live_keys[] | "  new key: " + .' <<< "$row"
      printf 'Repo values win for keys already declared; JSON formatting may change.\n'
    fi
    printf 'Import this one file into the repo? Type yes to proceed: '
    IFS= read -r answer < /dev/tty || exit 1
    [[ "$answer" == yes ]] || continue
    case "$id" in
      antigravity-ide-settings|vscode-family-settings|vscode-family-keybindings)
        bun scripts/repo-settings-import.ts "$repo_dir" --only "$id" --write-jsonc-vscode
        ;;
      docker-settings-store)
        bun scripts/repo-settings-import.ts "$repo_dir" --only "$id" --write-lossy --write-docker
        ;;
      *)
        bun scripts/repo-settings-import.ts "$repo_dir" --only "$id" --write-lossy
        ;;
    esac
    git diff --stat -- "$repo_file"
  done < <(jq -c '.[] | select((.status == "report" and (.only_live_keys | length > 0)) or .status == "json_differs")' <<< "$report")
  printf 'Unreadable and text-only settings remain unimported; inspect just diff for those.\n'
fi

printf '\nRepo-backed files already record edits through their symlinks. Review their diffs:\n'
taplo lint config/codex/config.toml
jq -e . config/app-preferences.json config/raycast/settings.json config/thaw/profile.json > /dev/null
git status --short
git diff --stat -- config/codex/config.toml config/app-preferences.json config/thaw/profile.json config/raycast/settings.json
printf '\nCustom macOS defaults and unlisted app keys require a deliberate declaration change.\n'
printf 'Run just diff to identify those; no unknown app state was copied into the repo.\n'
printf 'Review git diff before committing. Nothing was applied, restarted, staged, or pushed.\n'
