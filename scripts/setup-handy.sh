#!/usr/bin/env bash
set -euo pipefail

repo_dir="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
mode="${2:-apply}"
if [ "$mode" != apply ] && [ "$mode" != check ]; then
  printf 'usage: %s [repo-dir] [apply|check]\n' "$0" >&2
  exit 2
fi

# The guided full apply closes Handy when its declared settings changed.
# Model provisioning itself does not require quitting the app.

model_id="$(jq -er '.settings.selected_model | select(length > 0)' \
  "$repo_dir/home/.dotfiles/handy/settings_store.json")"
pin="$(jq -ce --arg id "$model_id" '.[$id] // error("No download pin for Handy model: " + $id)' \
  "$repo_dir/config/handy/models.json")"
revision="$(jq -er '.revision' <<< "$pin")"
sha256="$(jq -er '.sha256' <<< "$pin")"
model_repo="${model_id%/*}"
filename="${model_id##*/}"
model_dir="$HOME/Library/Application Support/com.pais.handy/models"
destination="$model_dir/$filename"

matches_pin() {
  [ -f "$1" ] && [ "$(shasum -a 256 "$1" | cut -d ' ' -f 1)" = "$sha256" ]
}

if matches_pin "$destination"; then
  printf 'Handy model verified: %s\n' "$model_id"
  exit 0
fi

# Handy also resolves the shared Hugging Face cache through refs/<revision>,
# then refs/main. Reuse a verified copy there instead of downloading it twice.
cache="${HF_HOME:-$HOME/.cache/huggingface}/hub/models--${model_repo//\//--}"
for ref in "$revision" main; do
  if [ -f "$cache/refs/$ref" ]; then
    snapshot="$(cat "$cache/refs/$ref")"
    if matches_pin "$cache/snapshots/$snapshot/$filename"; then
      printf 'Handy model verified in Hugging Face cache: %s\n' "$model_id"
      exit 0
    fi
  fi
done

if [ "$mode" = check ]; then
  printf 'Handy model missing or checksum differs: %s (run just apply-to-machine dotfiles).\n' "$model_id" >&2
  exit 1
fi

mkdir -p "$model_dir"
download="$(mktemp "$model_dir/.download.XXXXXX")"
trap 'rm -f "$download"' EXIT
printf 'Downloading Handy model: %s\n' "$model_id"
curl --fail --location --show-error --silent --retry 3 --proto '=https' --tlsv1.2 \
  "https://huggingface.co/$model_repo/resolve/$revision/$filename" --output "$download"
if ! matches_pin "$download"; then
  printf 'Handy model download failed SHA-256 verification.\n' >&2
  exit 1
fi
# Publish only a complete, verified model. Downloads stay outside the repo.
mv -f "$download" "$destination"
printf 'Handy model installed: %s\n' "$model_id"
