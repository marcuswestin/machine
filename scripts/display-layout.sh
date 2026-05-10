#!/usr/bin/env bash
set -euo pipefail

cat >&2 <<'EOF'
No replayable display layout is checked in yet.

Arrange the displays in System Settings, then run:
  just display-layout-capture

After reviewing the generated script, replay it with:
  just display-layout-apply
EOF

exit 1
