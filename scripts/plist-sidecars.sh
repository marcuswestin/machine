#!/usr/bin/env bash
# Write readable sidecars for binary or XML plists: XML, TOML (via yq-go), JSON (via jq).
# Default target is inventory-global/defaults when present; pass files or directories otherwise.
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

pretty_xml() {
  /usr/bin/python3 -c 'import sys, xml.dom.minidom
raw = sys.stdin.buffer.read()
if not raw.strip():
    raise SystemExit(0)
sys.stdout.write(xml.dom.minidom.parseString(raw).toprettyxml(indent="  "))'
}

write_error() {
  local out=$1
  shift
  printf '%s\n' "$*" >"${out}.error.txt"
}

emit_one() {
  local f=$1
  local xml_out="${f}.xml"
  local toml_out="${f}.toml"
  local json_out="${f}.json"

  rm -f \
    "$xml_out" "${xml_out}.error.txt" \
    "$toml_out" "${toml_out}.error.txt" \
    "$json_out" "${json_out}.error.txt"

  if ! plutil -convert xml1 -o - "$f" 2>"${xml_out}.error.txt" | pretty_xml >"$xml_out"; then
    rm -f "$xml_out"
  elif [[ ! -s "${xml_out}.error.txt" ]]; then
    rm -f "${xml_out}.error.txt"
  fi

  if ! command -v yq >/dev/null 2>&1; then
    write_error "$toml_out" 'Skipped: no yq on PATH (nix-darwin declares pkgs.yq-go as `yq`).'
  elif ! yq -V 2>&1 | grep -qi mikefarah; then
    write_error "$toml_out" 'Skipped: this yq is not mikefarah/yq-go (wrong -p=json support).'
  elif ! plutil -convert json -o - "$f" 2>"${toml_out}.error.txt" | yq -p=json -o=toml '.' >"$toml_out" 2>>"${toml_out}.error.txt"; then
    rm -f "$toml_out"
    if [[ ! -s "${toml_out}.error.txt" ]]; then
      write_error "$toml_out" 'Skipped: JSON to TOML conversion failed.'
    fi
  elif [[ ! -s "${toml_out}.error.txt" ]]; then
    rm -f "${toml_out}.error.txt"
  fi

  if ! plutil -convert json -o - "$f" 2>"${json_out}.error.txt" | jq . >"$json_out" 2>>"${json_out}.error.txt"; then
    rm -f "$json_out"
    if [[ ! -s "${json_out}.error.txt" ]]; then
      write_error "$json_out" 'JSON conversion failed.'
    fi
  elif [[ ! -s "${json_out}.error.txt" ]]; then
    rm -f "${json_out}.error.txt"
  fi
}

collect_plists() {
  local target=$1
  if [[ -d "$target" ]]; then
    find "$target" -maxdepth 1 -name '*.plist' -type f -print 2>/dev/null | LC_ALL=C sort -u
  elif [[ -f "$target" ]]; then
    printf '%s\n' "$target"
  else
    printf 'plist-sidecars: skip missing path: %s\n' "$target" >&2
  fi
}

main() {
  if [[ "$#" -eq 0 ]]; then
    local default_dir="${repo_dir}/inventory-global/defaults"
    if [[ -d "$default_dir" ]] && compgen -G "${default_dir}/*.plist" >/dev/null; then
      set -- "$default_dir"
    else
      printf 'usage: %s [file.plist|dir ...]\n' "$(basename "$0")" >&2
      printf '  Default dir %s has no *.plist; pass paths explicitly.\n' "$default_dir" >&2
      exit 64
    fi
  fi

  local any=0
  local path f
  for path in "$@"; do
    [[ "$path" != /* ]] && path="${repo_dir}/${path}"
    while IFS= read -r f; do
      [[ -n "$f" ]] || continue
      emit_one "$f"
      any=$((any + 1))
    done < <(collect_plists "$path")
  done

  if [[ "$any" -eq 0 ]]; then
    printf 'No plist files found for given paths.\n' >&2
    exit 1
  fi
  printf 'plist-sidecars: wrote sidecar dumps for %s plist file(s).\n' "$any"
}

main "$@"
