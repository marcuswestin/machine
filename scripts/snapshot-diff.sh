#!/usr/bin/env bash
# Diff optional captured files under inventory-tracked/ or inventory-global/ against the current machine.
# Inventory folders are gitignored by default; snapshots are local review material.
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
scope="${1:-global}"
case "$scope" in
  tracked)
    inv_name="inventory-tracked"
    ;;
  global)
    inv_name="inventory-global"
    ;;
  *)
    printf 'usage: %s [tracked|global]\n' "$(basename "$0")" >&2
    exit 64
    ;;
esac
inv="${repo_dir}/${inv_name}"

section() {
  printf '\n━━ %s ━━\n' "$1"
}

failed=0

# Keep this domain list aligned with whatever captures inventory-global/defaults
# (defaults export per domain).
defaults_domains=(
  NSGlobalDomain
  com.apple.dock
  com.apple.finder
  com.apple.AppleMultitouchTrackpad
  com.apple.driver.AppleBluetoothMultitouch.trackpad
  app.monitorcontrol.MonitorControl
  bobko.aerospace
  com.openai.chat
  com.apple.symbolichotkeys
  com.apple.universalaccess
  com.apple.HIToolbox
  com.apple.WindowManager
  com.apple.controlcenter
)
current_host_defaults_domains=(
  com.apple.Spotlight
  com.apple.controlcenter
)

section "${inv_name}/Brewfile vs brew bundle dump"
inv_bf="${inv}/Brewfile"
if [[ -f "$inv_bf" ]]; then
  tmp="$(mktemp)"
  brew bundle dump --force --file "$tmp"
  if diff -u "$inv_bf" "$tmp"; then
    printf 'No differences.\n'
  else
    failed=1
  fi
  rm -f "$tmp"
else
  printf 'Skip: %s not found.\n' "$inv_bf"
fi

section "${inv_name}/mas.json vs mas list (JSON)"
inv_mas="${inv}/mas.json"
if [[ -f "$inv_mas" ]]; then
  tmp="$(mktemp)"
  mas list | jq -Rs '[split("\n")[] | select(length > 0 and test("\\S"))]' >"$tmp"
  if diff -u "$inv_mas" "$tmp"; then
    printf 'No differences.\n'
  else
    failed=1
  fi
  rm -f "$tmp"
else
  printf 'Skip: %s not found.\n' "$inv_mas"
fi

section "${inv_name}/defaults/*.plist vs defaults export"
inv_def="${inv}/defaults"
if [[ -d "$inv_def" ]] && [[ -n "$(find "$inv_def" -maxdepth 1 -name '*.plist' -print -quit 2>/dev/null)" ]]; then
  tmp="$(mktemp -d)"
  for domain in "${defaults_domains[@]}"; do
    defaults export "$domain" "${tmp}/${domain}.plist" 2>/dev/null || true
  done
  for domain in "${current_host_defaults_domains[@]}"; do
    defaults -currentHost export "$domain" "${tmp}/${domain}.currentHost.plist" 2>/dev/null || true
  done
  if diff -ru "$inv_def" "$tmp"; then
    printf 'No differences.\n'
  else
    failed=1
  fi
  rm -rf "$tmp"
else
  printf 'Skip: %s has no captured .plist files.\n' "$inv_def"
fi

section "${inv_name}/display-layout.sh vs scripts/display-layout.sh (if both exist)"
inv_dl="${inv}/display-layout.sh"
canon_dl="${repo_dir}/scripts/display-layout.sh"
if [[ -f "$inv_dl" ]] && [[ -f "$canon_dl" ]]; then
  if diff -u "$inv_dl" "$canon_dl"; then
    printf 'No differences.\n'
  else
    failed=1
  fi
else
  printf 'Skip: need both %s and %s.\n' "$canon_dl" "$inv_dl"
fi

section "${inv_name}/browser-extensions/*.json vs current browser extension capture"
inv_browser_ext="${inv}/browser-extensions"
if [[ -d "$inv_browser_ext" ]] && [[ -n "$(find "$inv_browser_ext" -maxdepth 1 -name '*.json' -print -quit 2>/dev/null)" ]]; then
  tmp="$(mktemp -d)"
  "${repo_dir}/scripts/browser-extensions.sh" capture "$tmp"
  if diff -ru "$inv_browser_ext" "$tmp"; then
    printf 'No differences.\n'
  else
    failed=1
  fi
  rm -rf "$tmp"
else
  printf 'Skip: %s has no captured .json files.\n' "$inv_browser_ext"
fi

printf '\nDone.\n'
exit "$failed"
