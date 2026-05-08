#!/usr/bin/env bash
set -euo pipefail

MACHINE_HOST="${MACHINE_HOST:-machine}"

info() {
  printf '\n==> %s\n' "$*"
}

load_nix() {
  if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi

  if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
  fi
}

developer_tools_installed() {
  if [ -x /Library/Developer/CommandLineTools/usr/bin/clang ] \
    && pkgutil --pkg-info com.apple.pkg.CLTools_Executables >/dev/null 2>&1; then
    return 0
  fi

  if [ -x /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild ] \
    && /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -version >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

install_command_line_tools() {
  local marker="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  local label=""

  if developer_tools_installed; then
    info "Apple developer tools already installed"
    return
  fi

  info "Installing Apple Command Line Tools"
  touch "$marker"
  label="$(
    { softwareupdate --list 2>&1 || true; } \
      | awk -F': ' '/Label: Command Line Tools/ { label=$2 } END { print label }'
  )"

  if [ -z "$label" ]; then
    rm -f "$marker"
    info "Requesting Apple Command Line Tools install"
    xcode-select --install || true
    printf 'Complete the Command Line Tools installer, then rerun this command.\n' >&2
    exit 1
  fi

  if ! sudo softwareupdate --install "$label" --verbose; then
    rm -f "$marker"
    exit 1
  fi

  sudo xcode-select --switch /Library/Developer/CommandLineTools
  rm -f "$marker"

  if ! developer_tools_installed; then
    printf 'Apple Command Line Tools still do not look installed; rerun this command after the installer finishes.\n' >&2
    exit 1
  fi
}

main() {
  load_nix
  install_command_line_tools
  MACHINE_HOST="$MACHINE_HOST" just up
}

main "$@"
