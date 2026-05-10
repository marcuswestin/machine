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

start_sudo_keepalive() {
  if [ "${MACHINE_SUDO_KEEPALIVE_ACTIVE:-}" = 1 ]; then
    return
  fi

  export MACHINE_SUDO_KEEPALIVE_ACTIVE=1

  # Prompt once up front. Later privileged commands still need to invoke `sudo`
  # explicitly; this only keeps the timestamp warm while setup runs.
  sudo -v

  # Refresh the sudo timestamp without prompting. If the timestamp is revoked or
  # expires unexpectedly, the next sudo command will ask normally.
  while true; do
    sudo -n -v 2>/dev/null || exit
    sleep 30
  done &
  sudo_keepalive_pid="$!"

  cleanup_sudo_keepalive() {
    kill "$sudo_keepalive_pid" 2>/dev/null || true
    sudo -k
  }
  trap cleanup_sudo_keepalive EXIT
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

git_cmd() {
  nix_cmd shell nixpkgs#git -c git "$@"
}

clone_repo() {
  if [ -d "$REPO_DIR/.git" ]; then
    info "Repo already cloned at $REPO_DIR"
    info "Updating repo to latest $REPO_REF"
    git_cmd -C "$REPO_DIR" fetch origin "$REPO_REF"
    git_cmd -C "$REPO_DIR" checkout "$REPO_REF"
    git_cmd -C "$REPO_DIR" pull --ff-only origin "$REPO_REF"
    return
  fi

  if [ -e "$REPO_DIR" ]; then
    printf 'Refusing to clone into existing non-git path: %s\n' "$REPO_DIR" >&2
    exit 1
  fi

  info "Cloning machine repo into $REPO_DIR"
  mkdir -p "$(dirname "$REPO_DIR")"
  git_cmd clone --branch "$REPO_REF" "$REPO_URL" "$REPO_DIR"
}

setup_machine() {
  info "Running repo machine setup"
  cd "$REPO_DIR"
  MACHINE_HOST="$MACHINE_HOST" bash scripts/up-local.sh
}

main() {
  start_sudo_keepalive
  load_nix
  install_nix
  clone_repo
  setup_machine

  info "Machine setup complete"
}

main "$@"
