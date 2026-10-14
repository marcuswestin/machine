#!/usr/bin/env bash
set -euo pipefail

# Exit 0 when every screen in the captured layout is connected and offers the
# captured mode; otherwise name the first mismatch and exit 1. displayplacer
# fails the whole layout in that case, e.g. when the external display is
# unplugged or the layout was captured on a laptop with a different panel.
layout="${1:-$(cd "$(dirname "$0")" && pwd)/display-layout.sh}"

# The capture recipe writes one quoted "id:<serial> res:… hz:… …" argument per screen.
displayplacer list | LAYOUT="$(grep -o '"id:[^"]*"' "$layout" | tr -d '"')" awk '
  /^Serial screen id:/ { serial = $4; connected[serial] = 1 }
  /^[[:space:]]+mode [0-9]+:/ {
    # Mode lines omit the scaling field for unscaled modes.
    modes[serial, $3 " " $4 " " $5 " " ($6 == "scaling:on" ? "scaling:on" : "scaling:off")] = 1
  }
  END {
    n = split(ENVIRON["LAYOUT"], args, "\n")
    for (i = 1; i <= n; i++) {
      split(args[i], fields, " ")
      delete val
      for (j in fields) val[substr(fields[j], 1, index(fields[j], ":") - 1)] = fields[j]
      id = substr(val["id"], 4)
      key = val["res"] " " val["hz"] " " val["color_depth"] " " val["scaling"]
      if (!(id in connected)) { printf "Display %s is not connected.\n", id; exit 1 }
      if (!((id, key) in modes)) { printf "Display %s does not offer %s.\n", id, key; exit 1 }
    }
  }
'
