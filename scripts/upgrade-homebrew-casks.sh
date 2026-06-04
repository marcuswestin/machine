#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  printf 'usage: %s host [cask ...]\n' "$0" >&2
  exit 64
fi

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
host="$1"
shift
nix_flags=(--extra-experimental-features 'nix-command flakes')

upgrade_casks=()
if [ "$#" -gt 0 ]; then
  while [ "$#" -gt 0 ]; do
    upgrade_casks+=("$1")
    shift
  done
else
  desired_casks="$(mktemp)"
  outdated_casks="$(mktemp)"
  trap 'rm -f "$desired_casks" "$outdated_casks"' EXIT

  nix "${nix_flags[@]}" eval --json "${repo_dir}#darwinConfigurations.${host}.config.homebrew.casks" \
    | jq -r '.[] | .name | ., split("/")[-1]' \
    | sort -fu >"$desired_casks"

  HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1 brew update
  HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1 brew outdated --cask --greedy \
    | sort -fu >"$outdated_casks"

  while IFS= read -r cask; do
    [ -n "$cask" ] || continue
    upgrade_casks+=("$cask")
  done < <(comm -12 "$outdated_casks" "$desired_casks")
fi

if [ "${#upgrade_casks[@]}" -eq 0 ]; then
  printf 'No outdated declared Homebrew casks.\n'
  exit 0
fi

printf 'Upgrading Homebrew casks:\n'
printf '  %s\n' "${upgrade_casks[@]}"
HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1 brew upgrade --cask --greedy "${upgrade_casks[@]}"
