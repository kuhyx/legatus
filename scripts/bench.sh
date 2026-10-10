#!/bin/bash

# ============================================================================
# Gate 2, the fps gate (Forward+ on the real GPU). Runs two fixed scenes for
# --seconds each (default 30): the worst-case bench (flat, fixed camera down
# the engaged line) and the real game scene (terrain, sight culling, general
# at his start, controls off). Each scene's last frame is saved to
# .shots/bench_<scene>.png so the agent can check the render itself.
#
# Modes:
#   --offscreen (agents use this): inside Xvfb on the NVIDIA Vulkan device,
#     CPU-capped, nothing on kuhy's screen. The window is 96x54 so copying
#     frames to the software X server is negligible; the 3D scene still
#     renders at 1920x1080 (--render-size). Gates on frame delta p99 too.
#   default: a real window, uncapped (kuhy runs it); gates on frame delta p99.
# Either fails if a gated p99 exceeds 16.7 ms (60 fps) or nothing was drawn.
# Usage: scripts/bench.sh [--offscreen] [--seconds=N]
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly P99_LIMIT_MS="16.7"
readonly CAPPED="$HOME/.claude/scripts/capped.sh"
SECONDS_ARG="--seconds=30"
OFFSCREEN=false

# Watchdog: a script parse error leaves Godot idling forever (--seconds is
# never reached), so every run is killed at --seconds + GRACE_S.
readonly GRACE_S=60

godot_cmd() {
    local limit=$(( ${SECONDS_ARG#--seconds=} + GRACE_S ))
    local -a watchdog=(timeout --kill-after=10 "$limit")
    if [[ "$OFFSCREEN" == true ]]; then
        CAP_CPU_PCT=20 CAP_MEM=4G "$CAPPED" "${watchdog[@]}" \
            xvfb-run -a -s '-screen 0 1920x1080x24' \
            godot --rendering-driver vulkan --gpu-index 0 --resolution 96x54 "$@" \
            --render-size=1920x1080
    else
        "${watchdog[@]}" godot "$@"
    fi
}

# p99 of the summary line `label p50=.. p99=X ..` in $1, or exit 1.
p99_of() {
    local log="$1" label="$2"
    if [[ "$log" =~ $label\ p50=[0-9.]+\ p99=([0-9.]+) ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    else
        echo "bench: no $label line" >&2
        return 1
    fi
}

check_p99() {
    local scene="$1" label="$2" value="$3"
    if awk -v p="$value" -v l="$P99_LIMIT_MS" 'BEGIN { exit !(p > l) }'; then
        echo "bench: FAIL $scene $label p99 ${value} ms > ${P99_LIMIT_MS} ms" >&2
        return 1
    fi
    echo "bench: ok $scene $label p99 ${value} ms"
}

run_scene() {
    local scene="$1" log name shot status=0 label
    name="$(basename "$scene" .tscn)"
    shot="$REPO_ROOT/.shots/bench_${name}.png"
    mkdir -p "$REPO_ROOT/.shots"
    log="$(godot_cmd --path "$REPO_ROOT" --audio-driver Dummy "$scene" -- "$SECONDS_ARG" \
        "--screenshot=$shot" 2>&1)" || status=$?
    if [[ "$status" -eq 124 || "$status" -eq 137 ]]; then
        printf '%s\n' "$log" | grep -E 'ERROR' | head -5 >&2
        echo "bench: FAIL $scene hung past --seconds (watchdog)" >&2
        return 1
    fi
    status=0
    printf '%s\n' "$log" | grep -E '^(Vulkan|bench:|battle|alive|[a-z_]+_ms |primitives|screenshot)'
    if [[ "$log" =~ primitives\ max_monitor=0\ max_server=0 ]] || [[ ! "$log" =~ primitives\ max_monitor= ]]; then
        echo "bench: FAIL $scene drew no primitives" >&2
        return 1
    fi
    check_p99 "$scene" frame_ms "$(p99_of "$log" frame_ms)" || status=1
    return "$status"
}

main() {
    for arg in "$@"; do
        case "$arg" in
            --offscreen) OFFSCREEN=true ;;
            --seconds=*) SECONDS_ARG="$arg" ;;
            *) echo "Unknown option: $arg" >&2; exit 1 ;;
        esac
    done
    local status=0
    run_scene res://scenes/bench/bench.tscn || status=1
    run_scene res://scenes/battle/battle.tscn || status=1
    return "$status"
}

main "$@"
