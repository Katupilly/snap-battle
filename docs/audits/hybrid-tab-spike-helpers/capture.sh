#!/usr/bin/env bash
# SPIKE: capture many screenshots in sequence. Disposable.
set -euo pipefail
SIM_ID="${SIM_ID:-2B3B56BE-3ADE-4C88-9F5A-1DCB69E556F4}"
APP_ID="PedroKosciuk.snap-battle"
OUT_DIR="${OUT_DIR:-docs/audits/assets/hybrid-tab-spike}"

run_case() {
    local name="$1"
    shift
    xcrun simctl terminate "$SIM_ID" "$APP_ID" 2>/dev/null || true
    sleep 0.5
    env "$@" xcrun simctl launch --terminate-running-process "$SIM_ID" "$APP_ID" >/dev/null
    sleep 1.5
    xcrun simctl io "$SIM_ID" screenshot "$OUT_DIR/$name.png" >/dev/null
    echo "saved $OUT_DIR/$name.png"
}

# Args: name technique trailing bottom tab dynType hideBar
shot() {
    local name="$1" tech="$2" trail="$3" bot="$4" tab="$5" dt="$6" hb="$7"
    local -a envs=(SIMCTL_CHILD_DAP_SPIKE=1
                   SIMCTL_CHILD_DAP_SPIKE_TECHNIQUE="$tech"
                   SIMCTL_CHILD_DAP_SPIKE_TRAILING="$trail"
                   SIMCTL_CHILD_DAP_SPIKE_BOTTOM="$bot"
                   SIMCTL_CHILD_DAP_SPIKE_TAB="$tab"
                   SIMCTL_CHILD_DAP_SPIKE_DYN_TYPE="$dt"
                   SIMCTL_CHILD_DAP_SPIKE_HIDE_MENU=1)
    if [ "$hb" = "1" ]; then
        envs+=(SIMCTL_CHILD_DAP_SPIKE_HIDE_BAR=1)
    fi
    run_case "$name" "${envs[@]}"
}

mkdir -p "$OUT_DIR"

# =================================================================
# 01-02 — Base cases (shared container, 12/4, both tabs)
# =================================================================
shot "01-shared-12-4-gallery" "Shared container" 12 4 gallery L 0
shot "02-shared-12-4-jam"     "Shared container" 12 4 jam L 0

# =================================================================
# 03-11 — Padding matrix (shared container, Gallery, default DT)
# =================================================================
shot "03-shared-8-0-gallery"  "Shared container" 8 0  gallery L 0
shot "04-shared-8-4-gallery"  "Shared container" 8 4  gallery L 0
shot "05-shared-8-8-gallery"  "Shared container" 8 8  gallery L 0
shot "06-shared-12-0-gallery" "Shared container" 12 0 gallery L 0
shot "07-shared-12-4-gallery" "Shared container" 12 4 gallery L 0
shot "08-shared-12-8-gallery" "Shared container" 12 8 gallery L 0
shot "09-shared-16-0-gallery" "Shared container" 16 0 gallery L 0
shot "10-shared-16-4-gallery" "Shared container" 16 4 gallery L 0
shot "11-shared-16-8-gallery" "Shared container" 16 8 gallery L 0

# =================================================================
# 12 — Tab bar hidden (simulated detail)
# =================================================================
shot "12-shared-12-4-gallery-bar-hidden" "Shared container" 12 4 gallery L 1

# =================================================================
# 13-15 — Dynamic Type variations
# =================================================================
shot "13-shared-12-4-gallery-XS"  "Shared container" 12 4 gallery XS 0
shot "14-shared-12-4-gallery-AX3" "Shared container" 12 4 gallery AX3 0
shot "15-shared-12-4-gallery-AX5" "Shared container" 12 4 gallery AX5 0

# =================================================================
# 16 — Dark mode
# =================================================================
xcrun simctl ui "$SIM_ID" appearance dark >/dev/null 2>&1
sleep 0.5
shot "16-shared-12-4-gallery-dark" "Shared container" 12 4 gallery L 0
xcrun simctl ui "$SIM_ID" appearance light >/dev/null 2>&1
sleep 0.5

# =================================================================
# 17-18 — Safe area inset technique
# =================================================================
shot "17-safeareainset-12-4-gallery" "Safe area inset" 12 4 gallery L 0
shot "18-safeareainset-12-4-jam"     "Safe area inset" 12 4 jam L 0

# =================================================================
# 19-20 — Overlay technique
# =================================================================
shot "19-overlay-12-4-gallery" "Overlay" 12 4 gallery L 0
shot "20-overlay-12-4-jam"     "Overlay" 12 4 jam L 0

# =================================================================
# 21 — Overlay, larger DT
# =================================================================
shot "21-overlay-12-4-gallery-AX3" "Overlay" 12 4 gallery AX3 0

# =================================================================
# 22 — Overlay, bar hidden
# =================================================================
shot "22-overlay-12-4-gallery-bar-hidden" "Overlay" 12 4 gallery L 1

# =================================================================
# 23 — Approach B (external source) — Jam selected
# =================================================================
shot "23-approach-b-jam" "Shared container" 12 4 jam L 0

# =================================================================
# 24 — Simulated capture sheet
# =================================================================
shot "24-shared-capture-sheet" "Shared container" 12 4 gallery L 0
xcrun simctl terminate "$SIM_ID" "$APP_ID" 2>/dev/null || true
sleep 0.5
env SIMCTL_CHILD_DAP_SPIKE=1 \
    SIMCTL_CHILD_DAP_SPIKE_TECHNIQUE="Shared container" \
    SIMCTL_CHILD_DAP_SPIKE_TRAILING=12 \
    SIMCTL_CHILD_DAP_SPIKE_BOTTOM=4 \
    SIMCTL_CHILD_DAP_SPIKE_TAB=gallery \
    SIMCTL_CHILD_DAP_SPIKE_DYN_TYPE=L \
    SIMCTL_CHILD_DAP_SPIKE_HIDE_MENU=1 \
    SIMCTL_CHILD_DAP_SPIKE_SHOW_CAPTURE=1 \
  xcrun simctl launch --terminate-running-process "$SIM_ID" "$APP_ID" >/dev/null
sleep 2.5
xcrun simctl io "$SIM_ID" screenshot "$OUT_DIR/25-shared-capture-sheet-active.png" >/dev/null
echo "saved 25-shared-capture-sheet-active.png"

echo "ALL DONE"
