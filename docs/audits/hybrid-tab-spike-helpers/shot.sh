#!/usr/bin/env bash
# SPIKE: helper for taking screenshots. Disposable, not part of any spec.
set -euo pipefail
SIM_ID="${SIM_ID:-2B3B56BE-3ADE-4C88-9F5A-1DCB69E556F4}"
APP_ID="PedroKosciuk.snap-battle"
OUT="${1:?usage: shot.sh <out-path>}"
xcrun simctl io "$SIM_ID" screenshot "$OUT" >/dev/null
echo "saved $OUT"
