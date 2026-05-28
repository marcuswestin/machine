#!/usr/bin/env bash
# Broad discovery of machine surfaces that may be worth managing later.
# Review-only: does not write active config or promote inventory.
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
discovery_dir="${repo_dir}/inventory-global/discovery"
summary_report="${discovery_dir}/summary.txt"

tracked_defaults_domains=(
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
  com.apple.Spotlight
  com.apple.WindowManager
  com.apple.controlcenter
)

section() {
  printf '\n━━ %s ━━\n' "$1"
}

tracked_defaults() {
  printf '%s\n' "${tracked_defaults_domains[@]}" | LC_ALL=C sort -u
}

write_section() {
  local slug="$1"
  local title="$2"
  local report="${discovery_dir}/${slug}.txt"
  shift 2

  {
    section "$title"
    "$@"
  } | tee "$report" | tee -a "$summary_report"
}

cask_receipt_app_names() {
  local caskroom="$1"
  [[ -d "$caskroom" ]] || return 0

  while IFS= read -r receipt; do
    jq -r '
      (
        .artifacts[]?
        | if type == "array" then
            .[]? | objects | .target? // empty
          elif type == "object" and has("pkg") then
            .pkg[]? | objects | .choices[]?.choiceIdentifier? // empty
          else
            empty
          end
      ),
      (.uninstall_artifacts[]? | objects | .uninstall[]? | objects | .delete[]? // empty)
    ' "$receipt" 2>/dev/null \
      | awk -F/ '
          /\.app$/ {
            name = $NF
            sub(/\.app$/, "", name)
            print name
          }
        '
  done < <(find "$caskroom" -path '*/.metadata/INSTALL_RECEIPT.json' -type f 2>/dev/null || true)
}

applications_candidates() {
  local extra_apps=()
  local cask_bundle_ids=()
  local cask_app_names=()
  local brew_prefix
  local caskroom

  brew_prefix="$(brew --prefix)"
  caskroom="${brew_prefix}/Caskroom"
  if [[ -d "$caskroom" ]]; then
    while IFS= read -r -d '' app; do
      bid="$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null || true)"
      [[ -n "$bid" ]] && cask_bundle_ids+=("$bid")
    done < <(find "$caskroom" -name '*.app' -print0 2>/dev/null || true)
    while IFS= read -r name; do
      [[ -n "$name" ]] && cask_app_names+=("$name")
    done < <(cask_receipt_app_names "$caskroom" | LC_ALL=C sort -u)
  fi

  for root in /Applications "${HOME}/Applications"; do
    [[ -d "$root" ]] || continue
    while IFS= read -r -d '' app; do
      bid="$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null || true)"
      [[ "$bid" == com.apple.* ]] && continue
      real="$(realpath "$app" 2>/dev/null || true)"
      [[ -n "$real" ]] || continue
      if [[ "$real" == /nix/store/* ]]; then
        continue
      fi
      if [[ "$real" == "$caskroom"/* ]]; then
        continue
      fi
      if [[ -n "$bid" ]]; then
        for known in "${cask_bundle_ids[@]}"; do
          if [[ "$known" == "$bid" ]]; then
            continue 2
          fi
        done
      fi
      app_name="$(basename "$app" .app)"
      for known in "${cask_app_names[@]}"; do
        if [[ "$known" == "$app_name" ]]; then
          continue 2
        fi
      done
      label="$app_name ($bid)"
      [[ "$root" == "${HOME}/Applications" ]] && label="${label} [~/Applications]"
      extra_apps+=("$label")
    done < <(find "$root" -maxdepth 1 -name '*.app' -print0 2>/dev/null || true)
  done
  if [[ "${#extra_apps[@]}" -eq 0 ]]; then
    printf 'None matched heuristics.\n'
  else
    printf '%s\n' "${extra_apps[@]}" | LC_ALL=C sort -u
  fi
}

defaults_domains_candidates() {
  comm -23 \
    <(
      defaults domains 2>/dev/null \
        | tr ',' '\n' \
        | sed 's/^ *//; s/ *$//' \
        | grep -v '^$' \
        | LC_ALL=C sort -u
    ) \
    <(tracked_defaults) || true
}

preference_plist_candidates() {
  for prefs_dir in "${HOME}/Library/Preferences" /Library/Preferences; do
    [[ -d "$prefs_dir" ]] || continue
    printf '%s\n' "$prefs_dir"
    comm -23 \
      <(
        find "$prefs_dir" -maxdepth 1 -name '*.plist' -type f -print 2>/dev/null \
          | sed 's#.*/##; s/\.plist$//' \
          | LC_ALL=C sort -u
      ) \
      <(tracked_defaults) \
      | sed 's/^/  /' || true
  done
}

launch_candidates() {
  for launch_dir in \
    "${HOME}/Library/LaunchAgents" \
    /Library/LaunchAgents \
    /Library/LaunchDaemons; do
    [[ -d "$launch_dir" ]] || continue
    printf '%s\n' "$launch_dir"
    find "$launch_dir" -maxdepth 1 -name '*.plist' -type f -print 2>/dev/null \
      | sed 's#.*/#  #' \
      | LC_ALL=C sort -u
  done
}

font_candidates() {
  for font_dir in "${HOME}/Library/Fonts" /Library/Fonts; do
    [[ -d "$font_dir" ]] || continue
    printf '%s\n' "$font_dir"
    find "$font_dir" -maxdepth 1 -type f \( -iname '*.otf' -o -iname '*.ttf' -o -iname '*.ttc' \) -print 2>/dev/null \
      | sed 's#.*/#  #' \
      | LC_ALL=C sort -u
  done
}

system_extensions() {
  systemextensionsctl list 2>/dev/null || true
}

shell_snippets() {
  local found_snippet=0
  for f in "${HOME}/.zprofile" "${HOME}/.zshenv"; do
    if [[ -f "$f" ]]; then
      printf '%s exists\n' "$f"
      found_snippet=1
    fi
  done
  if [[ "$found_snippet" -eq 0 ]]; then
    printf 'None.\n'
  fi
}

mkdir -p "$discovery_dir"
: >"$summary_report"

write_section applications '/Applications candidates (not Homebrew/nix; excludes com.apple.*)' applications_candidates
write_section defaults-domains 'Defaults domains not in tracked capture list' defaults_domains_candidates
write_section preference-plists 'Preference plist candidates outside tracked defaults' preference_plist_candidates
write_section launch-agents-daemons 'LaunchAgents and LaunchDaemons candidates' launch_candidates
write_section fonts 'Fonts outside system font directories' font_candidates
write_section system-extensions 'System extensions' system_extensions
write_section shell-snippets 'Unmanaged shell snippets' shell_snippets

printf '\nDone. Reports written to %s\n' "${discovery_dir#"$repo_dir/"}" | tee -a "$summary_report"
