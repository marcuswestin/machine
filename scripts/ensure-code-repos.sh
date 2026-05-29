#!/usr/bin/env bash
set -euo pipefail

code_dir="$HOME/code"

repos=(
  "marcuswestin/machine machine"
  "marcuswestin/tao-lang tao-lang"
  "marcuswestin/Legal Legal"
  "marcuswestin/agent-os agent-os"
  "marcuswestin/wordflower wordflower"
  # GitHub reports this repo with an uppercase F; keep the requested local path.
  "marcuswestin/My-WordFlower My-Wordflower"
)

github_repo_from_remote() {
  local remote="$1"

  remote="${remote%.git}"
  case "$remote" in
    git@github.com:*)
      remote="${remote#git@github.com:}"
      ;;
    https://github.com/*)
      remote="${remote#https://github.com/}"
      ;;
    ssh://git@github.com/*)
      remote="${remote#ssh://git@github.com/}"
      ;;
  esac

  printf '%s' "$remote" | tr '[:upper:]' '[:lower:]'
}

ensure_repo() {
  local repo="$1"
  local local_name="$2"
  local destination="$code_dir/$local_name"
  local expected
  local origin

  if [ -e "$destination" ]; then
    if ! git -C "$destination" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      printf 'Refusing to clone %s into existing non-git path: %s\n' "$repo" "$destination" >&2
      exit 1
    fi

    origin="$(git -C "$destination" remote get-url origin 2>/dev/null || true)"
    expected="$(printf '%s' "$repo" | tr '[:upper:]' '[:lower:]')"

    if [ "$(github_repo_from_remote "$origin")" != "$expected" ]; then
      printf 'Existing checkout at %s does not use expected GitHub origin %s\n' "$destination" "$repo" >&2
      printf 'Actual origin: %s\n' "${origin:-<none>}" >&2
      exit 1
    fi

    printf '%s already cloned at %s\n' "$repo" "$destination"
    return
  fi

  mkdir -p "$code_dir"
  gh repo clone "$repo" "$destination"
}

main() {
  local entry
  local repo
  local local_name

  for entry in "${repos[@]}"; do
    read -r repo local_name <<< "$entry"
    ensure_repo "$repo" "$local_name"
  done
}

main "$@"
