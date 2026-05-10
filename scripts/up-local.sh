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
  info "Running just up"
  export MACHINE_HOST
  nix_cmd shell nixpkgs#just -c just up
}

main "$@"
