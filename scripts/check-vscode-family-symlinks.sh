#!/usr/bin/env bash
# Ensures VS Code / Cursor user settings and keybindings resolve to the repo
# canonical files under home/.dotfiles/vscode-family/ (chezmoi symlink_* targets).
set -euo pipefail

REPO="${1:?usage: check-vscode-family-symlinks.sh <repo-root>}"

canonical_settings="$(realpath "${REPO}/home/.dotfiles/vscode-family/settings.json")"
canonical_keybindings="$(realpath "${REPO}/home/.dotfiles/vscode-family/keybindings.json")"

err=0

check_resolves() {
  local label="$1" path="$2" expected="$3"
  if [[ ! -e "$path" ]]; then
    printf 'vscode-family symlink check: missing %s — run: just chezmoi-apply\n' "$label" >&2
    err=1
    return
  fi
  local got
  got="$(realpath "$path")"
  if [[ "$got" != "$expected" ]]; then
    printf 'vscode-family symlink check: %s drifts from repo canonical copy.\n' "$label" >&2
    printf '  %s\n  resolves to: %s\n  expected:      %s\n' "$path" "$got" "$expected" >&2
    printf 'Replace with chezmoi symlinks: just chezmoi-apply\n' >&2
    err=1
  fi
}

check_resolves '~/.config/vscode-family/settings.json' \
  "${HOME}/.config/vscode-family/settings.json" "$canonical_settings"
check_resolves '~/.config/vscode-family/keybindings.json' \
  "${HOME}/.config/vscode-family/keybindings.json" "$canonical_keybindings"
check_resolves 'Cursor User/settings.json' \
  "${HOME}/Library/Application Support/Cursor/User/settings.json" "$canonical_settings"
check_resolves 'VS Code User/settings.json' \
  "${HOME}/Library/Application Support/Code/User/settings.json" "$canonical_settings"
check_resolves 'Cursor User/keybindings.json' \
  "${HOME}/Library/Application Support/Cursor/User/keybindings.json" "$canonical_keybindings"
check_resolves 'VS Code User/keybindings.json' \
  "${HOME}/Library/Application Support/Code/User/keybindings.json" "$canonical_keybindings"

exit "$err"
