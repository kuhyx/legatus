#!/bin/bash

# ============================================================================
# Perf gate 1: 2 x 50k soldiers charge into contact and fight for 400 ticks
# (20 s of game time, paced at 20 Hz) headless. Prints alive counts and tick
# p50/p99/max; exits non-zero when nobody died (= the lines never touched).
# Locally runs in the capped scope (20 % CPU, 4 GiB), so the tick numbers are
# a LOWER bound on what the sim does on the whole machine. Extra args go to
# the bench after `--` (e.g. `--unpaced`, `--ticks=100`).
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly CAPPED="$HOME/.claude/scripts/capped.sh"

main() {
    local -a cmd=(godot --headless --audio-driver Dummy --path "$REPO_ROOT"
        -s res://src/sim/bench_headless.gd -- "$@")
    if [[ -z "${CI:-}" && -x "$CAPPED" ]]; then
        CAP_CPU_PCT=20 CAP_MEM=4G "$CAPPED" "${cmd[@]}"
    else
        "${cmd[@]}"
    fi
}

main "$@"
