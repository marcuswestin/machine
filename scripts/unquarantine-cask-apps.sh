#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -gt 2 ]; then
  printf 'usage: %s [repo-dir] [host]\n' "$0" >&2
  exit 2
fi

repo_dir="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
host="${2:-${MACHINE_HOST:-machine}}"
nix_flags=(--extra-experimental-features "nix-command flakes")

brew_prefix="$(brew --prefix)"
caskroom="${brew_prefix}/Caskroom"

casks_file="$(mktemp)"
apps_file="$(mktemp)"
trap 'rm -f "$casks_file" "$apps_file"' EXIT

nix "${nix_flags[@]}" eval --json "${repo_dir}#darwinConfigurations.${host}.config.homebrew.casks" \
  | jq -r '.[].name | split("/")[-1]' \
  | sort -u > "$casks_file"

while IFS= read -r cask; do
  receipt="${caskroom}/${cask}/.metadata/INSTALL_RECEIPT.json"
  if [ ! -f "$receipt" ]; then
    printf 'No Homebrew cask receipt for %s; skipping quarantine cleanup.\n' "$cask" >&2
    continue
  fi

  jq -r '
    .uninstall_artifacts[]?
    | (
        (.app? // empty | .[]),
        (.uninstall? // empty | .[]?.delete? // empty | .[])
      )
    | select(endswith(".app"))
  ' "$receipt" | while IFS= read -r artifact; do
    if [[ "$artifact" = /* ]]; then
      printf '%s\n' "$artifact"
    else
      printf '/Applications/%s\n' "$(basename "$artifact")"
    fi
  done >> "$apps_file"
done < "$casks_file"

sort -u "$apps_file" | while IFS= read -r app_path; do
  if [ ! -d "$app_path" ]; then
    printf 'Declared cask app is not present: %s\n' "$app_path" >&2
    continue
  fi

  printf 'Clearing Gatekeeper quarantine from %s\n' "$app_path"
  sudo /usr/bin/xattr -dr com.apple.quarantine "$app_path"
done
