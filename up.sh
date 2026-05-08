#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${MACHINE_REPO_URL:-https://github.com/marcuswestin/machine.git}"
REPO_DIR="${MACHINE_REPO_DIR:-$HOME/code/machine}"
REPO_REF="${MACHINE_REPO_REF:-main}"
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

install_git() {
  local existing=""

  if command -v git >/dev/null 2>&1; then
    existing="$(command -v git)"
    if [ "${existing#/usr/bin/}" = "$existing" ]; then
      info "git already available at $existing"
      return
    fi

    info "Ignoring Apple developer-tools shim at $existing"
  fi

  info "Installing git with Nix"
  nix_cmd profile add nixpkgs#git
  load_nix
  hash -r
}

clone_repo() {
  if [ -d "$REPO_DIR/.git" ]; then
    info "Repo already cloned at $REPO_DIR"
    info "Updating repo to latest $REPO_REF"
    git -C "$REPO_DIR" fetch origin "$REPO_REF"
    git -C "$REPO_DIR" checkout "$REPO_REF"
    git -C "$REPO_DIR" pull --ff-only origin "$REPO_REF"
    return
  fi

  if [ -e "$REPO_DIR" ]; then
    printf 'Refusing to clone into existing non-git path: %s\n' "$REPO_DIR" >&2
    exit 1
  fi

  info "Cloning machine repo into $REPO_DIR"
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone --branch "$REPO_REF" "$REPO_URL" "$REPO_DIR"
}

setup_machine() {
  info "Running repo machine setup"
  cd "$REPO_DIR"
  MACHINE_HOST="$MACHINE_HOST" bash scripts/up-local.sh
}

main() {
  load_nix
  install_nix
  install_git
  clone_repo
  setup_machine

  info "Machine setup complete"
}

main "$@"
