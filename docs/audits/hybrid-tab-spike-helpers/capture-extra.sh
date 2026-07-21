#!/usr/bin/env bash
# SPIKE: capture supplementary screenshots for AX5 + landscape edge cases.
set -euo pipefail
SIM_ID="${SIM_ID:-2B3B56BE-3ADE-4C88-9F5A-1DCB69E556F4}"
APP_ID="PedroKosciuk.snap-battle"
OUT_DIR="${OUT_DIR:-docs/audits/assets/hybrid-tab-spike}"

shot() {
    local name="$1" tech="$2" trail="$3" bot="$4" tab="$5" dt="$6" hb="$7"
    local -a envs=(SIMCTL_CHILD_DAP_SPIKE=1
                   SIMCTL_CHILD_DAP_SPIKE_TECHNIQUE="$tech"
                   SIMCTL_CHILD_DAP_SPIKE_TRAILING="$trail"
                   SIMCTL_CHILD_DAP_SPIKE_BOTTOM="$bot"
                   SIMCTL_CHILD_DAP_SPIKE_TAB="$tab"
                   SIMCTL_CHILD_DAP_SPIKE_DYN_TYPE="$dt"
                   SIMCTL_CHILD_DAP_SPIKE_HIDE_MENU=1)
    [ "$hb" = "1" ] && envs+=(SIMCTL_CHILD_DAP_SPIKE_HIDE_BAR=1)
    xcrun simctl terminate "$SIM_ID" "$APP_ID" 2>/dev/null || true
    sleep 0.4
    env "${envs[@]}" xcrun simctl launch --terminate-running-process "$SIM_ID" "$APP_ID" >/dev/null
    sleep 1.5
    xcrun simctl io "$SIM_ID" screenshot "$OUT_DIR/$name.png" >/dev/null
    echo "saved $name"
}

# AX5 with larger bottom paddings
shot "26-shared-12-8-gallery-AX5" "Shared container" 12 8 gallery AX5 0
shot "27-shared-16-8-gallery-AX5" "Shared container" 16 8 gallery AX5 0
shot "28-shared-12-0-gallery-AX5" "Shared container" 12 0 gallery AX5 0

# AX5 with Jam selected
shot "29-shared-12-4-jam-AX5" "Shared container" 12 4 jam AX5 0
