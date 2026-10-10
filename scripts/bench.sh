#!/bin/bash

# ============================================================================
# Gate 2, the windowed fps gate (Forward+, uncapped). Opens a window, so kuhy
# runs it, never an agent. Runs two fixed scenes for --seconds each (default
# 30): the worst-case bench (flat, fixed camera down the engaged line) and the
# real game scene (terrain, sight culling, general at his start). Fails if
# either frame p99 exceeds 16.7 ms (60 fps), or if a scene drew no primitives
# (a frame time measured on an empty scene proves nothing). Each scene's last
# frame is saved to .shots/bench_<scene>.png so the agent can check the real
# Forward+ render itself instead of asking what was on screen.
# Usage: scripts/bench.sh [--seconds=N]
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly P99_LIMIT_MS="16.7"
SECONDS_ARG="--seconds=30"

run_scene() {
    local scene="$1" log p99 name shot
    name="$(basename "$scene" .tscn)"
    shot="$REPO_ROOT/.shots/bench_${name}.png"
    mkdir -p "$REPO_ROOT/.shots"
    log="$(godot --path "$REPO_ROOT" --audio-driver Dummy "$scene" -- "$SECONDS_ARG" \
        "--screenshot=$shot" 2>&1)"
    printf '%s\n' "$log" | grep -E '^(bench|battle|alive|frame_ms|tick_ms|fill_upload_ms|primitives|screenshot)'
    if [[ "$log" =~ frame_ms\ p50=[0-9.]+\ p99=([0-9.]+) ]]; then
        p99="${BASH_REMATCH[1]}"
    else
        echo "bench: no frame_ms line from $scene" >&2
        return 1
    fi
    if [[ "$log" =~ primitives\ max_monitor=0\ max_server=0 ]] || [[ ! "$log" =~ primitives\ max_monitor= ]]; then
        echo "bench: FAIL $scene drew no primitives" >&2
        return 1
    fi
    if awk -v p="$p99" -v l="$P99_LIMIT_MS" 'BEGIN { exit !(p > l) }'; then
        echo "bench: FAIL $scene frame p99 ${p99} ms > ${P99_LIMIT_MS} ms" >&2
        return 1
    fi
    echo "bench: ok $scene frame p99 ${p99} ms"
}

main() {
    [[ "${1:-}" == --seconds=* ]] && SECONDS_ARG="$1"
    local status=0
    run_scene res://scenes/bench/bench.tscn || status=1
    run_scene res://scenes/battle/battle.tscn || status=1
    return "$status"
}

main "$@"
