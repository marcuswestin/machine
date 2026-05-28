#!/usr/bin/env bash
set -euo pipefail

# Captured from the current macOS display arrangement with displayplacer.
# Serial screen ids are tied to the physical displays and are less sensitive to
# macOS persistent id changes when external displays wake in a different order.
exec displayplacer \
  "id:s656250 res:2560x1440 hz:60 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0" \
  "id:s4251086178 res:1728x1117 hz:120 color_depth:8 enabled:true scaling:on origin:(377,1440) degree:0" \
  "id:s810243667 res:2560x1440 hz:60 color_depth:8 enabled:true scaling:on origin:(2560,67) degree:0"
