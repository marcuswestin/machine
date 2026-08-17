#!/usr/bin/env bash
# Upgrade outdated declared Homebrew formulae only.
# Casks (including auto-updating ones) go through `just upgrade`.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  printf 'usage: %s host\n' "$0" >&2
  exit 64
fi

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
host="$1"
nix_flags=(--extra-experimental-features 'nix-command flakes')
homebrew_env=(HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1)

desired_formulae="$(mktemp)"
outdated_formulae="$(mktemp)"
trap 'rm -f "$desired_formulae" "$outdated_formulae"' EXIT

nix "${nix_flags[@]}" eval --json "${repo_dir}#darwinConfigurations.${host}.config.homebrew.brews" \
  | jq -r '.[] | .name | ., split("/")[-1]' \
  | sort -fu >"$desired_formulae"

env "${homebrew_env[@]}" brew update
env "${homebrew_env[@]}" brew outdated --formula \
  | awk '{ print $1 }' \
  | sort -fu >"$outdated_formulae"

mapfile -t upgrade_formulae < <(comm -12 "$outdated_formulae" "$desired_formulae")

if [ "${#upgrade_formulae[@]}" -eq 0 ]; then
  printf 'No outdated declared Homebrew formulae.\n'
  exit 0
fi

printf 'Upgrading Homebrew formulae:\n'
printf '  %s\n' "${upgrade_formulae[@]}"
env "${homebrew_env[@]}" brew upgrade --formula "${upgrade_formulae[@]}"
