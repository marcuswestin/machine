#!/usr/bin/env bash
# Show only actionable differences between repo declarations and this Mac.
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
host="${1:-${MACHINE_HOST:-machine}}"
nix_flags=(--extra-experimental-features 'nix-command flakes' --option warn-dirty false)
export HOMEBREW_NO_AUTO_UPDATE=1
brewfile="$(mktemp)"
browser_capture="$(mktemp -d)"
browser_error="$(mktemp)"
bundle_output="$(mktemp)"
trap 'rm -f "$brewfile" "$browser_error" "$bundle_output"; rm -rf "$browser_capture"' EXIT

expected_system="$(cd "$repo_dir" && nix "${nix_flags[@]}" eval --offline --no-write-lock-file --raw ".#darwinConfigurations.${host}.config.system.build.toplevel.drvPath")"
active_system="$(nix-store -q --deriver /run/current-system)"
if [[ "$expected_system" != "$active_system" ]]; then
  printf '[DIFF] nix.system.derivation: current=%s -> repo=%s\n' "$active_system" "$expected_system"
fi

(cd "$repo_dir" && just _prune-homebrew-diff)
(cd "$repo_dir" && nix "${nix_flags[@]}" eval --offline --no-write-lock-file --raw ".#darwinConfigurations.${host}.config.homebrew.brewfile") > "$brewfile"
if ! brew bundle check --no-upgrade --file "$brewfile" > "$bundle_output" 2>&1; then
  missing_count=0
  installed_formulae="$(brew list --formula --full-name)"
  installed_casks="$(brew list --cask 2>/dev/null)"
  installed_taps="$(brew tap)"
  while IFS= read -r formula; do
    [[ -n "$formula" ]] || continue
    if ! grep -Fqx "$formula" <<< "$installed_formulae" \
      && ! grep -Fqx "${formula##*/}" <<< "$installed_formulae"; then
      printf '[DIFF] homebrew.formula.%s: current=<absent> -> repo=installed\n' "$formula"
      ((missing_count += 1))
    fi
  done < <(awk -F'"' '/^brew "/ { print $2 }' "$brewfile")
  while IFS= read -r cask; do
    [[ -n "$cask" ]] || continue
    if ! grep -Fqx "${cask##*/}" <<< "$installed_casks"; then
      printf '[DIFF] homebrew.cask.%s: current=<absent> -> repo=installed\n' "$cask"
      ((missing_count += 1))
    fi
  done < <(awk -F'"' '/^cask "/ { print $2 }' "$brewfile")
  while IFS= read -r tap; do
    [[ -n "$tap" ]] || continue
    if ! grep -Fqx "$tap" <<< "$installed_taps"; then
      printf '[DIFF] homebrew.tap.%s: current=<absent> -> repo=tapped\n' "$tap"
      ((missing_count += 1))
    fi
  done < <(awk -F'"' '/^tap "/ { print $2 }' "$brewfile")
  if (( missing_count == 0 )); then
    printf '[UNVERIFIED] homebrew.bundle: check failed without a missing declared item; inspect brew bundle check\n'
  fi
fi

# The repo declares Mac App Store apps to install, not every app this user may
# have installed. Only missing declared IDs are drift.
desired_ids="$(
  nix "${nix_flags[@]}" eval --offline --no-write-lock-file --json ".#darwinConfigurations.${host}.config.homebrew.masApps" \
    | jq -r 'to_entries[].value | tostring' | sort -nu
)"
installed_ids="$(mas list | awk '/^[0-9]+[[:space:]]/ { print $1 }' | sort -nu)"
if [[ -n "$desired_ids" ]]; then
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    if ! grep -qx "$id" <<< "$installed_ids"; then
      printf '[DIFF] mas.%s: current=<absent> -> repo=installed\n' "$id"
    fi
  done <<< "$desired_ids"
fi

(cd "$repo_dir" && just _prune-editor-extensions-diff)
for editor in code cursor; do
  case "$editor" in
    code) cli="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"; editor_file="${repo_dir}/home/.dotfiles/vscode-family/extensions.code.txt" ;;
    cursor) cli="/Applications/Cursor.app/Contents/Resources/app/bin/cursor"; editor_file="${repo_dir}/home/.dotfiles/vscode-family/extensions.cursor.txt" ;;
  esac
  installed="$("$cli" --list-extensions | sort -fu)"
  desired="$(cat "${repo_dir}/home/.dotfiles/vscode-family/extensions.txt" "$editor_file" | sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' | sort -fu)"
  missing="$(comm -23 <(printf '%s\n' "$desired") <(printf '%s\n' "$installed"))"
  if [[ -n "$missing" ]]; then
    while IFS= read -r extension; do
      printf '[DIFF] editor.%s.%s: current=<absent> -> repo=installed\n' "$editor" "$extension"
    done <<< "$missing"
  fi
done

browser_status=0
"${repo_dir}/scripts/browser-extensions.sh" capture "$browser_capture" 2> "$browser_error" || browser_status=$?
if (( browser_status == 0 )); then
  bun "${repo_dir}/scripts/browser-extension-review.ts" diff "$repo_dir" "$browser_capture"
elif (( browser_status == 2 )); then
  printf '[UNVERIFIED] browser.extensions: profile access denied; run from a Terminal with browser-profile access\n'
else
  cat "$browser_error" >&2
  exit "$browser_status"
fi

chezmoi_diff="$(chezmoi diff --source "${repo_dir}/home" || true)"
if [[ -n "$chezmoi_diff" ]]; then
  printf '%s\n' "$chezmoi_diff" | awk '
    /^diff --git a\// { path=$3; sub(/^a\//, "", path); print "[DIFF] chezmoi:" path; next }
    /^old mode / { current=$3; next }
    /^new mode / { print "  mode: current=0" substr(current, 3) " -> repo=0" substr($3, 3); next }
    /^--- / || /^\+\+\+ / || /^@@/ || /^index / { next }
    /^-/ { print "  current: " substr($0, 2); next }
    /^\+/ { print "  repo: " substr($0, 2); next }
  '
fi

if ! bash "${repo_dir}/scripts/setup-handy.sh" "$repo_dir" check > "$bundle_output" 2>&1; then
  printf '[DIFF] handy.model: current=missing or checksum differs -> repo=%s\n' \
    "$(jq -r '.settings.selected_model' "${repo_dir}/home/.dotfiles/handy/settings_store.json")"
fi

(cd "$repo_dir" && just _settings-check)
