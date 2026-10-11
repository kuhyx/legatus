#!/bin/bash
# Morale calibration gate (DOCS-design-army §4): the bench battle
# (src/sim/calibrate_morale.gd) over many seeds, against the historical
# targets. Medians over the seeds must land in: loser killed 14-16 %, winner
# killed 4-5 %, the loser's median break losses <= 10 %.
#   --quick   one seed (6, close to the 20-seed medians), ~50 s: every tweak.
#   default   seeds 1-20, ~15 min: the acceptance run once a tuning is done.
# Jobs split capped.sh's 50 % ceiling between them. Not in pre-commit.
# Usage: scripts/calibrate.sh [--quick] [--seeds=1-20] [--jobs=4]
#        [--minutes=15] [--tune=k:v,...] [--out=DIR]
# Exit: 0 in the bands, 1 outside, 2 a run gave no result line.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly CAPPED="$HOME/.claude/scripts/capped.sh"
readonly RUN_TIMEOUT_S=1800

SEEDS="1-20"
JOBS=4
MINUTES=15
TUNE=""
OUT="$REPO_ROOT/.shots/calibrate"

parse_args() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            --quick) SEEDS="6-6"; JOBS=1 ;;
            --seeds=*) SEEDS="${arg#--seeds=}" ;;
            --jobs=*) JOBS="${arg#--jobs=}" ;;
            --minutes=*) MINUTES="${arg#--minutes=}" ;;
            --tune=*) TUNE="${arg#--tune=}" ;;
            --out=*) OUT="${arg#--out=}" ;;
            *) echo "calibrate: unknown argument $arg" >&2; exit 2 ;;
        esac
    done
    if [[ ! "$SEEDS" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        echo "calibrate: --seeds must be A-B" >&2
        exit 2
    fi
}

# One seed, log to $OUT/seed_N.log (a hang is killed by the timeout).
run_seed() {
    local seed="$1"
    CAP_CPU_PCT=$((50 / JOBS)) timeout --kill-after=10 "$RUN_TIMEOUT_S" "$CAPPED" godot --headless --audio-driver Dummy \
        --path "$REPO_ROOT" -s res://src/sim/calibrate_morale.gd -- \
        --minutes="$MINUTES" --seed="$seed" --tune="$TUNE" >"$OUT/seed_$seed.log" 2>&1 || true
}

# run_all <first> <last>: every seed, $JOBS at a time.
run_all() {
    local seed
    for seed in $(seq "$1" "$2"); do
        while (($(jobs -rp | wc -l) >= JOBS)); do
            wait -n || true
        done
        run_seed "$seed" &
    done
    wait
}

# Field `key=value` of a result line.
field() {
    local line="$1" key="$2"
    [[ "$line" =~ $key=([0-9.]+) ]] && printf '%s' "${BASH_REMATCH[1]}"
}

# Median of the numbers on stdin (mean of the middle two for an even count).
median() {
    local -a values
    mapfile -t values < <(sort -g)
    local n="${#values[@]}"
    awk -v a="${values[$(((n - 1) / 2))]}" -v b="${values[$((n / 2))]}" \
        'BEGIN { printf "%.2f", (a + b) / 2 }'
}

# check <label> <value> <low> <high>: prints ok/FAIL, returns 1 outside.
check() {
    local label="$1" value="$2" low="$3" high="$4"
    if awk -v v="$value" -v l="$low" -v h="$high" 'BEGIN { exit !(v < l || v > h) }'; then
        echo "calibrate: FAIL $label median $value % outside $low-$high %"
        return 1
    fi
    echo "calibrate: ok $label median $value % in $low-$high %"
}

main() {
    parse_args "$@"
    mkdir -p "$OUT"
    rm -f "$OUT"/seed_*.log
    local first="${BASH_REMATCH[1]}" last="${BASH_REMATCH[2]}"
    echo "calibrate: seeds $first-$last, $JOBS at a time, tune '${TUNE}' -> $OUT"
    run_all "$first" "$last"
    local seed line losers="" winners="" breaks="" missing=0
    for seed in $(seq "$first" "$last"); do
        line="$(grep -m1 '^result ' "$OUT/seed_$seed.log" || true)"
        if [[ -z "$line" ]]; then
            echo "calibrate: seed $seed gave no result (see $OUT/seed_$seed.log)"
            missing=1
            continue
        fi
        echo "seed $seed: ${line#result }"
        losers+="$(field "$line" loser_killed)"$'\n'
        winners+="$(field "$line" winner_killed)"$'\n'
        breaks+="$(field "$line" loser_break_median)"$'\n'
    done
    ((missing == 0)) || exit 2
    local status=0
    check "loser killed" "$(median <<<"${losers%$'\n'}")" 14 16 || status=1
    check "winner killed" "$(median <<<"${winners%$'\n'}")" 4 5 || status=1
    check "loser break losses" "$(median <<<"${breaks%$'\n'}")" 0 10 || status=1
    exit "$status"
}

main "$@"
