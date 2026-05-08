#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${MACHINE_REPO_URL:-https://github.com/marcuswestin/machine.git}"
REPO_DIR="${MACHINE_REPO_DIR:-$HOME/code/machine}"
MACHINE_HOST="${MACHINE_HOST:-machine}"
NIX_INSTALL_URL="${NIX_INSTALL_URL:-https://install.determinate.systems/nix}"

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

nix_cmd() {
  nix --extra-experimental-features 'nix-command flakes' "$@"
}

install_nix() {
  if command -v nix >/dev/null 2>&1; then
    info "Nix already installed"
    return
  fi

  info "Installing Nix with Determinate Nix Installer"
  curl --proto '=https' --tlsv1.2 -sSf -L "$NIX_INSTALL_URL" | sh -s -- install --determinate --no-confirm
  load_nix
}

install_nix_tool() {
  local cmd="$1"
  local pkg="$2"

  if command -v "$cmd" >/dev/null 2>&1; then
    info "$cmd already available"
    return
  fi

  info "Installing $cmd with Nix"
  nix_cmd profile install "$pkg"
}

clone_repo() {
  if [ -d "$REPO_DIR/.git" ]; then
    info "Repo already cloned at $REPO_DIR"
    return
  fi

  if [ -e "$REPO_DIR" ]; then
    printf 'Refusing to clone into existing non-git path: %s\n' "$REPO_DIR" >&2
    exit 1
  fi

  info "Cloning machine repo into $REPO_DIR"
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone "$REPO_URL" "$REPO_DIR"
}

switch_machine() {
  info "Running repo machine setup"
  cd "$REPO_DIR"
  MACHINE_HOST="$MACHINE_HOST" just up
}

main() {
  load_nix
  install_nix
  install_nix_tool git nixpkgs#git
  install_nix_tool just nixpkgs#just
  clone_repo
  switch_machine

  info "Machine setup complete"
}

main "$@"
