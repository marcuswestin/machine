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

# Yes/no question where Enter means yes. Returns 0 for yes, 2 for no, and 1 on
# EOF/Ctrl-C, so a closed input never counts as consent.
confirm_prompt() {
  local answer
  printf '\n%s\n' "$1"
  while true; do
    printf '\n%s [Y/n] ' "$2"
    if ! IFS= read -r answer; then
      printf '\nStopped without confirmation.\n' >&2
      return 1
    fi
    case "$answer" in
      ''|y|Y|yes|YES|Yes) return 0 ;;
      n|N|no|NO|No) return 2 ;;
    esac
    printf 'Answer y or n (Enter means yes).\n'
  done
}
