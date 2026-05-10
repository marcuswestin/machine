#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  printf 'usage: %s diff|sync repos-file code-dir\n' "$0" >&2
  exit 64
fi

mode="$1"
repos_file="$2"
code_dir="$3"

case "$mode" in
  diff | sync) ;;
  *)
    printf 'unknown mode: %s\n' "$mode" >&2
    exit 64
    ;;
esac

normalize_url() {
  local value="$1"
  printf '%s\n' "${value%.git}"
}

repo_status() {
  local dest="$1"
  local expected_url="$2"
  local actual=""

  if [ ! -e "$dest" ]; then
    printf 'missing\n'
    return
  fi

  if [ ! -d "$dest/.git" ]; then
    printf 'Path exists but is not a git repo: %s\n' "$dest" >&2
    printf 'invalid\n'
    return
  fi

  actual="$(git -C "$dest" remote get-url origin 2>/dev/null || true)"
  if [ -z "$actual" ]; then
    printf 'Repo has no origin remote: %s\n' "$dest" >&2
    printf 'invalid\n'
    return
  fi

  if [ "$(normalize_url "$actual")" != "$(normalize_url "$expected_url")" ]; then
    printf 'Origin mismatch for %s:\n  expected: %s\n  actual:   %s\n' "$dest" "$expected_url" "$actual" >&2
    printf 'invalid\n'
    return
  fi

  printf 'ok\n'
}

if [ "$mode" = sync ]; then
  mkdir -p "$code_dir"
fi

status=0

while IFS=$'\t' read -r rel_path url _rest; do
  [ -n "$rel_path" ] || continue
  [[ "$rel_path" == \#* ]] && continue

  dest="$code_dir/$rel_path"
  state="$(repo_status "$dest" "$url")"

  case "$state" in
    ok)
      ;;
    missing)
      if [ "$mode" = sync ]; then
        mkdir -p "$(dirname "$dest")"
        git clone "$url" "$dest"
      else
        printf 'Missing repo: %s -> %s\n' "$dest" "$url"
        status=1
      fi
      ;;
    invalid)
      status=1
      ;;
  esac
done < "$repos_file"

exit "$status"
