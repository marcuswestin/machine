#!/usr/bin/env bash
# Capture local machine state under a scoped inventory folder for review (gitignored by default).
# Defaults domain list must stay aligned with scripts/snapshot-diff.sh.
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

defaults_domains=(
  NSGlobalDomain
  com.apple.dock
  com.apple.finder
  com.apple.AppleMultitouchTrackpad
  com.apple.driver.AppleBluetoothMultitouch.trackpad
  app.monitorcontrol.MonitorControl
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

rm -rf "${inv}/browser-extensions" "${inv}/defaults" "${inv}/editor-extensions"
rm -f "${inv}/Brewfile" "${inv}/mas.json" "${inv}/display-layout.sh"
mkdir -p "${inv}/editor-extensions"

printf 'Import: brew bundle dump → %s/Brewfile\n' "$inv_name"
brew bundle dump --force --file "${inv}/Brewfile"

printf 'Import: mas list → %s/mas.json\n' "$inv_name"
mas list | jq -Rs '[split("\n")[] | select(length > 0 and test("\\S"))]' >"${inv}/mas.json"

printf 'Import: defaults export → %s/defaults/\n' "$inv_name"
mkdir -p "${inv}/defaults"
for domain in "${defaults_domains[@]}"; do
  defaults export "$domain" "${inv}/defaults/${domain}.plist" 2>/dev/null || true
done
for domain in "${current_host_defaults_domains[@]}"; do
  defaults -currentHost export "$domain" "${inv}/defaults/${domain}.currentHost.plist" 2>/dev/null || true
done

printf 'Import: readable defaults sidecars → %s/defaults/*.plist.{xml,json,toml}\n' "$inv_name"
"${repo_dir}/scripts/plist-sidecars.sh" "${inv}/defaults" || true

printf 'Import: editor extension lists → %s/editor-extensions/\n' "$inv_name"
code --list-extensions >"${inv}/editor-extensions/code.txt"
cursor --list-extensions >"${inv}/editor-extensions/cursor.txt"

printf 'Import: browser extension lists → %s/browser-extensions/\n' "$inv_name"
"${repo_dir}/scripts/browser-extensions.sh" capture "${inv}/browser-extensions"

printf 'Import: display layout → %s/display-layout.sh (ignored if not replayable)\n' "$inv_name"
(cd "$repo_dir" && just _display-layout-capture "${inv_name}/display-layout.sh") || true

printf 'Import: Raycast bundle if config/raycast/settings.json changed\n'
"${repo_dir}/scripts/raycast-settings-sync.sh" "${repo_dir}" || true

printf '\nImport complete; snapshots in %s\n' "$inv"
