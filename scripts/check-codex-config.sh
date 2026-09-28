#!/usr/bin/env bash
# Compatibility entrypoint for per-user managed Codex keys.
set -euo pipefail
repo_dir="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
MACHINE_REPO="$repo_dir" bun "$repo_dir/scripts/codex-config-sync.ts" check
