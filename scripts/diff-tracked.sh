#!/usr/bin/env bash
# Read-only comparison of repo-declared surfaces against this Mac.
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
host="${1:-${MACHINE_HOST:-machine}}"
nix_flags=(--extra-experimental-features 'nix-command flakes')
export HOMEBREW_NO_AUTO_UPDATE=1
unverified=0
brewfile=""
tmp_browser_ext=""
trap '[[ -z "$brewfile" ]] || rm -f "$brewfile"; [[ -z "$tmp_browser_ext" ]] || rm -rf "$tmp_browser_ext"' EXIT

printf '\n━━ Nix system generation (covers first-class system declarations) ━━\n'
expected_system="$(cd "$repo_dir" && nix "${nix_flags[@]}" eval --offline --no-write-lock-file --raw ".#darwinConfigurations.${host}.config.system.build.toplevel.drvPath")"
active_system="$(nix-store -q --deriver /run/current-system)"
if [[ "$expected_system" == "$active_system" ]]; then
  printf 'Active generation matches the current repo derivation. Live defaults can still drift.\n'
else
  printf 'Active generation differs from this repo:\n  repo: %s\n  active: %s\n' "$expected_system" "$active_system"
fi

printf '\n━━ Homebrew declarations vs installed packages ━━\n'
(cd "$repo_dir" && just _prune-homebrew-diff)
brewfile="$(mktemp)"
(cd "$repo_dir" && nix "${nix_flags[@]}" eval --offline --no-write-lock-file --raw ".#darwinConfigurations.${host}.config.homebrew.brewfile") > "$brewfile"
# Apply installs missing packages but intentionally leaves installed app versions
# alone, including self-updated casks. Match that policy in drift reporting.
if brew bundle check --no-upgrade --verbose --file "$brewfile"; then
  printf 'All declared Homebrew packages are installed.\n'
else
  printf 'Homebrew check did not pass; inspect missing-package or tap errors above.\n'
fi

printf '\n━━ Mac App Store declarations vs installed apps ━━\n'
desired_ids="$(
  nix "${nix_flags[@]}" eval --offline --no-write-lock-file --json ".#darwinConfigurations.${host}.config.homebrew.masApps" \
    | jq -r 'to_entries | map(.value | tostring) | .[]' | sort -nu
)"
extra_mas=()
mas_output="$(mas list)"
while read -r line; do
  [[ -n "$line" ]] || continue
  # mas list: "<id>  <name>  (version)" — id is first field.
  read -r id _ <<<"$line"
  [[ "$id" =~ ^[0-9]+$ ]] || continue
  if ! grep -qx "$id" <<<"$desired_ids"; then
    extra_mas+=("$line")
  fi
done <<< "$mas_output"
if [ "${#extra_mas[@]}" -eq 0 ]; then
  printf 'None.\n'
else
  printf '%s\n' "${extra_mas[@]}"
fi
installed_ids="$(awk '/^[0-9]+[[:space:]]/ { print $1 }' <<< "$mas_output" | sort -nu)"
missing_mas="$(comm -23 <(printf '%s\n' "$desired_ids") <(printf '%s\n' "$installed_ids"))"
if [[ -n "$missing_mas" ]]; then printf 'Missing declared App Store IDs:\n%s\n' "$missing_mas"; fi

printf '\n━━ Editor extensions (installed but not in vscode-family extension lists) ━━\n'
(cd "$repo_dir" && just _prune-editor-extensions-diff)
for editor in code cursor; do
  case "$editor" in
    code) cli="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"; editor_file="${repo_dir}/home/.dotfiles/vscode-family/extensions.code.txt" ;;
    cursor) cli="/Applications/Cursor.app/Contents/Resources/app/bin/cursor"; editor_file="${repo_dir}/home/.dotfiles/vscode-family/extensions.cursor.txt" ;;
  esac
  installed="$("$cli" --list-extensions | sort -fu)"
  desired="$(cat "${repo_dir}/home/.dotfiles/vscode-family/extensions.txt" "$editor_file" | sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' | sort -fu)"
  missing="$(comm -23 <(printf '%s\n' "$desired") <(printf '%s\n' "$installed"))"
  if [[ -n "$missing" ]]; then printf 'Missing %s extensions:\n%s\n' "$editor" "$missing"; fi
done

printf '\n━━ Browser extensions (live vs config/browser-extensions) ━━\n'
tmp_browser_ext="$(mktemp -d)"
if "${repo_dir}/scripts/browser-extensions.sh" capture "$tmp_browser_ext"; then
  bun "${repo_dir}/scripts/browser-extension-review.ts" diff "$repo_dir" "$tmp_browser_ext"
else
  printf 'Browser extension drift is unverified on this Mac.\n'
  unverified=1
fi
rm -rf "$tmp_browser_ext"
tmp_browser_ext=""

printf '\n━━ Chezmoi (repo vs home drift) ━━\n'
(cd "$repo_dir" && just _prune-dotfiles-diff)

printf '\n━━ Live app JSON vs repo (merge-in-settings report) ━━\n'
bun "${repo_dir}/scripts/repo-settings-import.ts" "${repo_dir}"
bun "${repo_dir}/scripts/app-preferences.ts" check

printf '\n━━ Handy transcription model (configured download pin) ━━\n'
bash "${repo_dir}/scripts/setup-handy.sh" "${repo_dir}" check

printf '\n━━ Codex managed user settings ━━\n'
bun "${repo_dir}/scripts/codex-config-sync.ts" check

printf '\n━━ Declared app/user defaults (including Stats and CodexBar) ━━\n'
/usr/bin/python3 "${repo_dir}/scripts/check-app-defaults.py" "$host"

printf '\n━━ CodexBar provider toggles ━━\n'
bash "${repo_dir}/scripts/codexbar-settings-sync.sh" check

printf '\n━━ Thaw saved profile confirmation ━━\n'
bash "${repo_dir}/scripts/thaw-profile-sync.sh" check

printf '\n━━ Raycast saved import confirmation ━━\n'
bash "${repo_dir}/scripts/raycast-settings-sync.sh" "${repo_dir}" check

printf '\nLive first-class macOS defaults, app runtime state, native UI layout, and privacy consent are not fully inspectable here.\n'
if (( unverified )); then exit 2; fi
