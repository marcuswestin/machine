#!/usr/bin/env bash
set -euo pipefail

MACHINE_HOST="${MACHINE_HOST:-machine}"

info() {
  printf '\n==> %s\n' "$*"
}

nix_cmd() {
  nix --extra-experimental-features 'nix-command flakes' "$@"
}

main() {
  bash "$(dirname "${BASH_SOURCE[0]}")/../up.sh" --check-os
  export MACHINE_HOST
  # Pass 1 installs the declared toolchain. Its pre-switch Codex preflight and
  # restart plan already need bun, taplo, and chezmoi, so borrow them from nixpkgs.
  info "Running just partial-apply-to-machine"
  nix_cmd shell nixpkgs#just nixpkgs#bun nixpkgs#taplo nixpkgs#chezmoi -c just partial-apply-to-machine
  # Pass 2 is the guided full apply (Thaw import, display layout, verification);
  # the Justfile PATH now finds the declared tools in /run/current-system/sw/bin.
  info "Running just apply-to-machine"
  nix_cmd shell nixpkgs#just -c just apply-to-machine
}

main "$@"
