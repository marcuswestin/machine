#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  printf 'usage: %s install|prune-diff|prune-apply\n' "$0" >&2
  exit 64
fi

mode="$1"
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
desired_file="$repo_dir/home/dot_config/vscode-family/extensions.txt"

case "$mode" in
  install | prune-diff | prune-apply) ;;
  *)
    printf 'unknown mode: %s\n' "$mode" >&2
    exit 64
    ;;
esac

desired_extensions() {
  grep -Ev '^\s*(#|$)' "$desired_file" | sort -fu
}

list_extensions() {
  local cli="$1"
  local err_file=""
  local installed=""

  err_file="$(mktemp)"
  if ! installed="$("$cli" --list-extensions 2>"$err_file")"; then
    cat "$err_file" >&2
    rm -f "$err_file"
    return 1
  fi

  rm -f "$err_file"
  printf '%s\n' "$installed" | sort -fu
}

extra_extensions() {
  local cli="$1"
  local installed=""

  installed="$(list_extensions "$cli")"
  comm -23 \
    <(printf '%s\n' "$installed") \
    <(desired_extensions)
}

install_extensions() {
  local cli="$1"
  local output=""
  local status=0

  while IFS= read -r extension; do
    if output="$("$cli" --install-extension "$extension" 2>&1)"; then
      continue
    fi

    status="$?"
    printf '%s\n' "$output" >&2
    return "$status"
  done < <(desired_extensions)
}

prune_diff_extensions() {
  local name="$1"
  local cli="$2"
  local extra=""

  extra="$(extra_extensions "$cli")"
  if [ -n "$extra" ]; then
    printf 'Undeclared %s extensions:\n%s\n' "$name" "$extra"
  fi
}

prune_apply_extensions() {
  local cli="$1"
  local extra=""

  extra="$(extra_extensions "$cli")"
  if [ -z "$extra" ]; then
    return
  fi

  while IFS= read -r extension; do
    "$cli" --uninstall-extension "$extension"
  done <<< "$extra"
}

run_for_editors() {
  "$@" "VS Code" "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  "$@" "Cursor" "/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
}

case "$mode" in
  install)
    install_extensions "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" &
    code_pid="$!"
    install_extensions "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" &
    cursor_pid="$!"
    status=0
    wait "$code_pid" || status="$?"
    wait "$cursor_pid" || status="$?"
    exit "$status"
    ;;
  prune-diff)
    run_for_editors prune_diff_extensions
    ;;
  prune-apply)
    prune_apply_extensions "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    prune_apply_extensions "/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
    ;;
esac
