#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  printf 'usage: %s diff|apply host\n' "$0" >&2
  exit 64
fi

mode="$1"
host="$2"
nix_flags=(--extra-experimental-features 'nix-command flakes')

case "$mode" in
  diff | apply) ;;
  *)
    printf 'unknown mode: %s\n' "$mode" >&2
    exit 64
    ;;
esac

brewfile="$(mktemp)"
desired_casks="$(mktemp)"
desired_formulae="$(mktemp)"
trap 'rm -f "$brewfile" "$desired_casks" "$desired_formulae"' EXIT

nix "${nix_flags[@]}" eval --raw ".#darwinConfigurations.${host}.config.homebrew.brewfile" > "$brewfile"

awk -F'"' '/^cask "/ { print $2 }' "$brewfile" | sort -fu > "$desired_casks"
desired_cask_aliases="$(
  awk -F'"' '/^cask "/ { print $2 }' "$brewfile" \
    | awk '{ print; sub(/^.*\//, ""); print }' \
    | sort -fu
)"
extra_casks="$(comm -23 <(brew list --cask | sort -fu) <(printf '%s\n' "$desired_cask_aliases"))"

awk -F'"' '/^brew "/ { print $2 }' "$brewfile" | sort -fu > "$desired_formulae"
installed_formulae="$(
  brew leaves --installed-on-request 2>/dev/null || brew leaves
)"
extra_formulae="$(comm -23 <(printf '%s\n' "$installed_formulae" | sort -fu) "$desired_formulae")"

if [ "$mode" = diff ]; then
  if [ -n "$extra_casks" ]; then
    printf 'Would uninstall casks:\n%s\n' "$extra_casks"
  fi

  if [ -n "$extra_formulae" ]; then
    printf 'Would uninstall formulae leaves:\n%s\n' "$extra_formulae"
  fi

  exit 0
fi

if [ -n "$extra_casks" ]; then
  while IFS= read -r cask; do
    # Avoid Homebrew's JSON cask API here; cask metadata bugs can break uninstall lookup.
    HOMEBREW_NO_AUTOREMOVE=1 HOMEBREW_NO_INSTALL_FROM_API=1 brew uninstall --cask --force "$cask"
  done <<< "$extra_casks"
fi

if [ -n "$extra_formulae" ]; then
  while IFS= read -r formula; do
    HOMEBREW_NO_AUTOREMOVE=1 brew uninstall --force "$formula"
  done <<< "$extra_formulae"
fi
