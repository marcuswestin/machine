#!/usr/bin/env bash
# Optional live snippets not declared under home/ (chezmoi). For drift on managed
# files use `chezmoi diff`. File-based app and CLI prefs live in home/.dotfiles/.
# Auth/session files such as ~/.codex/auth.json and ~/.config/gh/hosts.yml stay unmanaged.
set -euo pipefail

dest="${1:?missing destination dir}"
mkdir -p "$dest"

copy_if_exists() {
  local src=$1
  local dst=$2
  if [[ -f "$src" ]]; then
    cp "$src" "$dst"
  fi
}

copy_if_exists "${HOME}/.zprofile" "${dest}/zprofile"
copy_if_exists "${HOME}/.zshenv" "${dest}/zshenv"
