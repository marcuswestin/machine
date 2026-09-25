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
export HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_INSTALL_FROM_API=1 HOMEBREW_NO_AUTO_UPDATE=1

desired_casks="$(mktemp)"
outdated_casks="$(mktemp)"
outdated_rows="$(mktemp)"
trap 'rm -f "$desired_casks" "$outdated_casks" "$outdated_rows"' EXIT

nix "${nix_flags[@]}" eval --json "${repo_dir}#darwinConfigurations.${host}.config.homebrew.casks" \
  | jq -r '.[].name' >"$desired_casks"

resolve_declared_cask() {
  local requested="$1" declared match=""
  while IFS= read -r declared; do
    if [ "$requested" = "$declared" ] || [ "$requested" = "${declared##*/}" ]; then
      if [ -n "$match" ]; then
        printf 'Ambiguous declared cask: %s\n' "$requested" >&2
        return 1
      fi
      match="$declared"
    fi
  done <"$desired_casks"
  if [ -z "$match" ]; then
    printf 'Cask is not declared: %s\n' "$requested" >&2
    return 1
  fi
  printf '%s\n' "$match"
}

requested_casks=()
for requested in "$@"; do
  requested_casks+=("$(resolve_declared_cask "$requested")")
done

brew outdated --cask --json=v2 >"$outdated_casks"
jq -r '.casks[] | [.name, .current_version, (.installed_versions | join("|"))] | @tsv' \
  "$outdated_casks" >"$outdated_rows"

upgrade_casks=()
while IFS=$'\t' read -r token current_version installed_versions; do
  [ -n "$token" ] || continue
  declared=""
  while IFS= read -r candidate; do
    if [ "$token" = "${candidate##*/}" ]; then
      declared="$candidate"
      break
    fi
  done <"$desired_casks"
  [ -n "$declared" ] || continue

  if [ "${#requested_casks[@]}" -gt 0 ]; then
    selected=false
    for requested in "${requested_casks[@]}"; do
      if [ "$declared" = "$requested" ]; then
        selected=true
        break
      fi
    done
    [ "$selected" = true ] || continue
  else
    auto_updates="$(brew info --cask --json=v2 "$declared" | jq -r '.casks[0].auto_updates // false')"
    [ "$auto_updates" = true ] && continue
  fi

  # Homebrew can report an older tap version as outdated when a receipt is newer.
  IFS='|' read -r -a installed <<<"$installed_versions"
  if ! brew ruby -r rubygems -e '
    begin
      target = Gem::Version.new(ARGV.shift.split(",", 2).first)
      installed = ARGV.map { |value| Gem::Version.new(value.split(",", 2).first) }
      exit(installed.all? { |version| target > version } ? 0 : 1)
    rescue ArgumentError
      exit 2
    end
  ' "$current_version" "${installed[@]}"; then
    printf 'Skipping %s: cask version %s is not newer than installed %s.\n' \
      "$declared" "$current_version" "$installed_versions" >&2
    continue
  fi

  upgrade_casks+=("$declared")
done <"$outdated_rows"

if [ "${#upgrade_casks[@]}" -eq 0 ]; then
  printf 'No outdated declared casks selected for Homebrew upgrade.\n'
  exit 0
fi

printf 'Upgrading Homebrew casks:\n'
printf '  %s\n' "${upgrade_casks[@]}"
# Use the declared tap-qualified names, so local casks do not resolve to public casks.
# Match nix-darwin Homebrew activation: tapped cask files avoid JSON API DSL issues.
brew upgrade --cask "${upgrade_casks[@]}"
