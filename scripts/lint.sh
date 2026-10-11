#!/bin/bash

# ============================================================================
# Lint: gdlint (every check, .gdlintrc), gdformat --check, then a headless
# parse of every script with GDScript warnings promoted to errors
# (project.godot), so an untyped declaration fails here, not at runtime.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly VENV="$REPO_ROOT/.venv"
readonly DIRS=("$REPO_ROOT/src" "$REPO_ROOT/tests")
readonly PARSE_JOBS=8

# One script's headless parse; prints only what Godot complained about.
parse_one() {
    godot --headless --path "$REPO_ROOT" --check-only -s "res://${1#"$REPO_ROOT"/}" 2>&1 \
        | grep -v '^Godot Engine' || true
}

# Every script parsed, PARSE_JOBS at a time (one Godot start per file costs
# ~0.6 s; serial, the 89 files took over a minute). Any output fails.
parse_gate() {
    local output
    output="$(find "${DIRS[@]}" -name '*.gd' -print0 | sort -z \
        | xargs -0 -P "$PARSE_JOBS" -n 1 "${BASH_SOURCE[0]}" --parse-one)"
    if [[ -n "$output" ]]; then
        printf '%s\n' "$output" >&2
        return 1
    fi
}

main() {
    if [[ ${1:-} == --parse-one ]]; then # one xargs worker of parse_gate
        parse_one "$2"
        return
    fi
    "$VENV/bin/gdlint" "${DIRS[@]}"
    "$VENV/bin/gdformat" --check "${DIRS[@]}"
    # Refresh the global class cache first: a script added since the last
    # import is otherwise "Could not find type X" for every file that uses it.
    godot --headless --path "$REPO_ROOT" --import >/dev/null 2>&1 || true
    if ! parse_gate; then
        echo "lint: headless parse reported warnings-as-errors" >&2
        exit 1
    fi
    echo "lint: ok"
}

main "$@"
