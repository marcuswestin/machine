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
  info "Running just apply-to-machine"
  export MACHINE_HOST
  nix_cmd shell nixpkgs#just -c just apply-to-machine
}

main "$@"
