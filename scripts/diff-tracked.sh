#!/usr/bin/env bash
# Refresh inventory-tracked/, then show drift for repo-declared surfaces only.
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
host="${1:-${MACHINE_HOST:-machine}}"
nix_flags=(--extra-experimental-features 'nix-command flakes')

(cd "$repo_dir" && just import-inventory tracked)

printf '\n━━ Homebrew (extra casks / formula leaves vs flake brewfile) ━━\n'
(cd "$repo_dir" && just _prune-homebrew-diff)

printf '\n━━ Mac App Store (mas installs not listed in homebrew.masApps) ━━\n'
desired_ids="$(
  nix "${nix_flags[@]}" eval --json ".#darwinConfigurations.${host}.config.homebrew.masApps" \
    | jq -r 'to_entries | map(.value | tostring) | .[]' | sort -nu
)"
extra_mas=()
while read -r line; do
  [[ -n "$line" ]] || continue
  # mas list: "<id>  <name>  (version)" — id is first field.
  read -r id _ <<<"$line"
  [[ "$id" =~ ^[0-9]+$ ]] || continue
  if ! grep -qx "$id" <<<"$desired_ids"; then
    extra_mas+=("$line")
  fi
done < <(mas list 2>/dev/null || true)
if [ "${#extra_mas[@]}" -eq 0 ]; then
  printf 'None (or mas list empty).\n'
else
  printf '%s\n' "${extra_mas[@]}"
fi

printf '\n━━ Editor extensions (installed but not in vscode-family/extensions.txt) ━━\n'
(cd "$repo_dir" && just _prune-editor-extensions-diff)

printf '\n━━ Chezmoi (repo vs home drift) ━━\n'
(cd "$repo_dir" && just _prune-dotfiles-diff)

printf '\n━━ Live app JSON vs repo (merge-in-settings report) ━━\n'
bun "${repo_dir}/scripts/repo-settings-import.ts" "${repo_dir}"
