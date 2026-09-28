#!/usr/bin/env bash
# Capture user-installed browser extensions in a stable, reviewable JSON form.
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  printf 'usage: %s capture <output-dir>\n' "$(basename "$0")" >&2
}

json_string() {
  jq -Rn --arg value "$1" '$value'
}

write_json_array() {
  local output_file="$1"
  local jsonl_file="$2"

  if [[ -s "$jsonl_file" ]]; then
    jq -sS 'sort_by(.browser, .profile // "", .id // "", .bundle_id // "", .name // "")' "$jsonl_file" >"$output_file"
  else
    printf '[]\n' >"$output_file"
  fi
}

capture_chrome() {
  local output_file="$1"
  local chrome_root="${HOME}/Library/Application Support/Google/Chrome"
  local tmp
  local found

  tmp="$(mktemp)"
  found="$(mktemp)"
  if [[ -d "$chrome_root" ]]; then
    if ! find "$chrome_root" -maxdepth 2 -name 'Secure Preferences' -type f -print0 >"$found"; then
      rm -f "$tmp" "$found"
      printf 'UNVERIFIED Chrome extensions: cannot read Chrome profiles under %s. Run from a Terminal with access to that folder.\n' "$chrome_root" >&2
      return 1
    fi
    while IFS= read -r -d '' secure_prefs; do
      profile_dir="$(dirname "$secure_prefs")"
      profile="$(basename "$profile_dir")"
      jq -cS --arg profile "$profile" '
        (.extensions.settings // {})
        | to_entries[]
        | select(.value.manifest? != null)
        | select((.value.was_installed_by_default // false) == false)
        | select((.value.was_installed_by_oem // false) == false)
        | select(((.value.path // "") | startswith("/")) | not)
        | {
            browser: "chrome",
            profile: $profile,
            id: .key,
            name: (.value.manifest.name // ""),
            description: (.value.manifest.description // ""),
            from_webstore: (.value.from_webstore // null),
            enabled: (((.value.disable_reasons // []) | length) == 0),
            update_url: (.value.manifest.update_url // null)
          }
      ' "$secure_prefs" >>"$tmp"
    done < "$found"
  fi

  write_json_array "$output_file" "$tmp"
  rm -f "$tmp" "$found"
}

capture_firefox() {
  local output_file="$1"
  local firefox_root="${HOME}/Library/Application Support/Firefox/Profiles"
  local tmp
  local found

  tmp="$(mktemp)"
  found="$(mktemp)"
  if [[ -d "$firefox_root" ]]; then
    if ! find "$firefox_root" -maxdepth 2 -name extensions.json -type f -print0 >"$found"; then
      rm -f "$tmp" "$found"
      printf 'UNVERIFIED Firefox extensions: cannot read profiles under %s.\n' "$firefox_root" >&2
      return 1
    fi
    while IFS= read -r -d '' extensions_json; do
      profile="$(basename "$(dirname "$extensions_json")")"
      jq -cS --arg profile "$profile" '
        (.addons // [])
        | .[]
        | select(.type == "extension")
        | select((.isSystem // false) == false)
        | select((.location // "") != "app-system-defaults")
        | {
            browser: "firefox",
            profile: $profile,
            id: (.id // ""),
            name: (.defaultLocale.name // .name // ""),
            description: (.defaultLocale.description // ""),
            active: (.active // null),
            user_disabled: (.userDisabled // null),
            app_disabled: (.appDisabled // null),
            source_uri: (.sourceURI // null)
          }
      ' "$extensions_json" >>"$tmp"
    done < "$found"
  fi

  write_json_array "$output_file" "$tmp"
  rm -f "$tmp" "$found"
}

capture_safari() {
  local output_file="$1"
  local tmp
  local point
  local plugin_rows

  tmp="$(mktemp)"
  plugin_rows="$(mktemp)"
  for point in \
    com.apple.Safari.web-extension \
    com.apple.Safari.content-blocker \
    com.apple.Safari.extension; do
    if ! pluginkit -m -A -D -v -p "$point" >"$plugin_rows"; then
      rm -f "$tmp" "$plugin_rows"
      printf 'UNVERIFIED Safari extensions: pluginkit could not list %s.\n' "$point" >&2
      return 1
    fi
    while IFS= read -r line; do
      [[ "$line" =~ plug-in\)$ ]] && continue
      [[ "$line" =~ ^[[:space:]]*([+\-=!?])?[[:space:]]*([^[:space:](]+)\(([^)]*)\)[[:space:]]+([A-F0-9-]+)[[:space:]]+([0-9-]+[[:space:]][0-9:]+[[:space:]][+-][0-9]+)[[:space:]]+(.+)$ ]] || continue

      election="${BASH_REMATCH[1]:-default}"
      identifier="${BASH_REMATCH[2]}"
      version="${BASH_REMATCH[3]}"
      uuid="${BASH_REMATCH[4]}"
      registered_at="${BASH_REMATCH[5]}"
      path="${BASH_REMATCH[6]}"

      # Built-in Safari helpers are part of Safari itself, not user-installed extensions.
      [[ "$identifier" == com.apple.* ]] && continue

      jq -cnS \
        --arg point "$point" \
        --arg election "$election" \
        --arg identifier "$identifier" \
        --arg version "$version" \
        --arg uuid "$uuid" \
        --arg registered_at "$registered_at" \
        --arg path "$path" \
        '{
          browser: "safari",
          extension_point: $point,
          bundle_id: $identifier,
          version: $version,
          election: $election,
          plugin_uuid: $uuid,
          registered_at: $registered_at,
          path: $path
        }' >>"$tmp"
    done < "$plugin_rows"
  done

  write_json_array "$output_file" "$tmp"
  rm -f "$tmp" "$plugin_rows"
}

capture_all() {
  local output_dir="$1"
  mkdir -p "$output_dir"

  capture_chrome "${output_dir}/chrome.json"
  capture_firefox "${output_dir}/firefox.json"
  capture_safari "${output_dir}/safari.json"
}

case "${1:-}" in
  capture)
    [[ $# -eq 2 ]] || {
      usage
      exit 64
    }
    capture_all "$2"
    ;;
  *)
    usage
    exit 64
    ;;
esac
