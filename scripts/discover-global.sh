#!/usr/bin/env bash
# Broad discovery of machine surfaces that may be worth managing later.
# Review-only: does not write active config or promote inventory.
set -euo pipefail

tracked_defaults_domains=(
  NSGlobalDomain
  com.apple.dock
  com.apple.finder
  com.apple.AppleMultitouchTrackpad
  com.apple.driver.AppleBluetoothMultitouch.trackpad
  app.monitorcontrol.MonitorControl
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
  printf '%s\n' "${tracked_defaults_domains[@]}" | sort -fu
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

section '/Applications candidates (not Homebrew/nix; excludes com.apple.*)'
extra_apps=()
cask_bundle_ids=()
cask_app_names=()
brew_prefix="$(brew --prefix)"
caskroom="${brew_prefix}/Caskroom"
if [[ -d "$caskroom" ]]; then
  while IFS= read -r -d '' app; do
    bid="$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null || true)"
    [[ -n "$bid" ]] && cask_bundle_ids+=("$bid")
  done < <(find "$caskroom" -name '*.app' -print0 2>/dev/null || true)
  while IFS= read -r name; do
    [[ -n "$name" ]] && cask_app_names+=("$name")
  done < <(cask_receipt_app_names "$caskroom" | sort -fu)
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
  printf '%s\n' "${extra_apps[@]}" | sort -fu
fi

section 'Defaults domains not in tracked capture list'
defaults domains 2>/dev/null \
  | tr ',' '\n' \
  | sed 's/^ *//; s/ *$//' \
  | grep -v '^$' \
  | sort -fu \
  | comm -23 - <(tracked_defaults) || true

section 'Preference plist candidates outside tracked defaults'
for prefs_dir in "${HOME}/Library/Preferences" /Library/Preferences; do
  [[ -d "$prefs_dir" ]] || continue
  printf '%s\n' "$prefs_dir"
  find "$prefs_dir" -maxdepth 1 -name '*.plist' -type f -print 2>/dev/null \
    | sed 's#.*/##; s/\.plist$//' \
    | sort -fu \
    | comm -23 - <(tracked_defaults) \
    | sed 's/^/  /' || true
done

section 'LaunchAgents and LaunchDaemons candidates'
for launch_dir in \
  "${HOME}/Library/LaunchAgents" \
  /Library/LaunchAgents \
  /Library/LaunchDaemons; do
  [[ -d "$launch_dir" ]] || continue
  printf '%s\n' "$launch_dir"
  find "$launch_dir" -maxdepth 1 -name '*.plist' -type f -print 2>/dev/null \
    | sed 's#.*/#  #' \
    | sort -fu
done

section 'Fonts outside system font directories'
for font_dir in "${HOME}/Library/Fonts" /Library/Fonts; do
  [[ -d "$font_dir" ]] || continue
  printf '%s\n' "$font_dir"
  find "$font_dir" -maxdepth 1 -type f \( -iname '*.otf' -o -iname '*.ttf' -o -iname '*.ttc' \) -print 2>/dev/null \
    | sed 's#.*/#  #' \
    | sort -fu
done

section 'System extensions'
systemextensionsctl list 2>/dev/null || true

section 'Unmanaged shell snippets'
found_snippet=0
for f in "${HOME}/.zprofile" "${HOME}/.zshenv"; do
  if [[ -f "$f" ]]; then
    printf '%s exists\n' "$f"
    found_snippet=1
  fi
done
if [[ "$found_snippet" -eq 0 ]]; then
  printf 'None.\n'
fi

printf '\nDone.\n'
