#!/bin/bash

# ============================================================================
# Gate 2, the fps gate (Forward+ on the real GPU). Runs two fixed scenes for
# --seconds each (default 30): the worst-case bench (flat, fixed camera down
# the engaged line) and the real game scene (terrain, sight culling, general
# at his start, controls off). Each scene's last frame is saved to
# .shots/bench_<scene>.png so the agent can check the render itself.
# The battle's fronts meet ~159 s in, so its run first plays the battle's own
# fixed tick headlessly to sim second --start-at (default 170; battle.gd
# `--start-at`, ~30-45 s of wall time) and only then times frames: the window
# is the melee, not the march. It fails unless every sim tick in the window
# had a formation engaged (the `contact engaged_min=` line), so a change that
# delays or prevents contact fails loudly instead of timing an empty field.
#
# Modes:
#   --offscreen (agents use this): inside Xvfb on the NVIDIA Vulkan device,
#     CPU-capped, nothing on kuhy's screen. The window is 96x54 so copying
#     frames to the software X server is negligible; the 3D scene still
#     renders at 1920x1080 (--render-size). Gates on frame delta p99 too.
#   default: a real window, uncapped (kuhy runs it); gates on frame delta p99.
# Either fails if a gated p99 exceeds 16.7 ms (60 fps), nothing was drawn or
# the battle window had no contact.
# Usage: scripts/bench.sh [--offscreen] [--seconds=N] [--start-at=S]
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly P99_LIMIT_MS="16.7"
readonly CAPPED="$HOME/.claude/scripts/capped.sh"
SECONDS_ARG="--seconds=30"
START_AT_S=170
OFFSCREEN=false

# Watchdog: a script parse error leaves Godot idling forever (--seconds is
# never reached), so every run is killed at --seconds + GRACE_S, plus the
# sim seconds it fast-forwards first (that runs faster than real time).
readonly GRACE_S=60

# godot_cmd <fast-forward s> <godot args...>
godot_cmd() {
    local extra_s="$1"
    shift
    local limit=$(( ${SECONDS_ARG#--seconds=} + GRACE_S + extra_s ))
    local -a watchdog=(timeout --kill-after=10 "$limit")
    if [[ "$OFFSCREEN" == true ]]; then
        CAP_CPU_PCT=20 CAP_MEM=4G "$CAPPED" "${watchdog[@]}" \
            xvfb-run -a -s '-screen 0 1920x1080x24' \
            godot --rendering-driver vulkan --audio-driver Dummy --gpu-index 0 --resolution 96x54 "$@" \
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

# Fail unless the `contact` line shows a formation engaged at every sample.
check_contact() {
    local scene="$1" log="$2"
    local re='contact engaged_min=([0-9]+) engaged_max=([0-9]+) of=[0-9]+ \(n=([0-9]+)\)'
    if [[ ! "$log" =~ $re ]]; then
        echo "bench: FAIL $scene printed no contact line" >&2
        return 1
    fi
    local low="${BASH_REMATCH[1]}" high="${BASH_REMATCH[2]}" n="${BASH_REMATCH[3]}"
    if [[ "$n" -eq 0 || "$low" -lt 1 ]]; then
        echo "bench: FAIL $scene window not in contact throughout" \
            "(engaged_min=$low max=$high n=$n); --start-at past first contact?" >&2
        return 1
    fi
    echo "bench: ok $scene contact engaged_min=$low"
}

# run_scene <scene> <start-at s, 0 = none> <contact|no-contact>
run_scene() {
    local scene="$1" start_at="$2" contact="$3" log name shot status=0
    local -a extra=()
    name="$(basename "$scene" .tscn)"
    shot="$REPO_ROOT/.shots/bench_${name}.png"
    mkdir -p "$REPO_ROOT/.shots"
    if [[ "$start_at" -gt 0 ]]; then
        extra+=("--start-at=$start_at")
    fi
    log="$(godot_cmd "$start_at" --path "$REPO_ROOT" --audio-driver Dummy "$scene" -- \
        "$SECONDS_ARG" "--screenshot=$shot" "${extra[@]}" 2>&1)" || status=$?
    if [[ "$status" -eq 124 || "$status" -eq 137 ]]; then
        printf '%s\n' "$log" | grep -E 'ERROR' | head -5 >&2
        echo "bench: FAIL $scene hung past --seconds (watchdog)" >&2
        return 1
    fi
    status=0
    printf '%s\n' "$log" | grep -E '^(Vulkan|bench:|battle|alive|[a-z_]+_ms |primitives|contact|screenshot)'
    if [[ "$log" =~ primitives\ max_monitor=0\ max_server=0 ]] || [[ ! "$log" =~ primitives\ max_monitor= ]]; then
        echo "bench: FAIL $scene drew no primitives" >&2
        return 1
    fi
    check_p99 "$scene" frame_ms "$(p99_of "$log" frame_ms)" || status=1
    if [[ "$contact" == contact ]]; then
        check_contact "$scene" "$log" || status=1
    fi
    return "$status"
}

main() {
    for arg in "$@"; do
        case "$arg" in
            --offscreen) OFFSCREEN=true ;;
            --seconds=*) SECONDS_ARG="$arg" ;;
            --start-at=*) START_AT_S="${arg#--start-at=}" ;;
            *) echo "Unknown option: $arg" >&2; exit 1 ;;
        esac
    done
    local status=0
    if [[ ! "$START_AT_S" =~ ^[0-9]+$ ]]; then
        echo "--start-at must be whole sim seconds, got: $START_AT_S" >&2
        exit 1
    fi
    run_scene res://scenes/bench/bench.tscn 0 no-contact || status=1
    run_scene res://scenes/battle/battle.tscn "$START_AT_S" contact || status=1
    return "$status"
}

main "$@"
