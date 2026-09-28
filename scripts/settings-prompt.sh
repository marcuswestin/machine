#!/usr/bin/env bash
# Shared CLI acknowledgement. EOF/Ctrl-C must never confirm an import or apply.
settings_prompt() {
  local answer
  printf '\n%s\n' "$1"
  while true; do
    printf '\nPress Enter when done; Ctrl-C to stop: '
    if ! IFS= read -r answer; then
      printf '\nStopped without confirmation.\n' >&2
      return 1
    fi
    [[ -z "$answer" ]] && return 0
    printf 'Complete the numbered steps, then press Enter without typing text.\n'
  done
}
