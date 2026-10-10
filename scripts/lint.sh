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

parse_gate() {
    local failed=0 output
    while IFS= read -r -d '' file; do
        output="$(godot --headless --path "$REPO_ROOT" --check-only -s "res://${file#"$REPO_ROOT"/}" 2>&1 \
            | grep -v '^Godot Engine' || true)"
        if [[ -n "$output" ]]; then
            printf '%s\n' "$output" >&2
            failed=1
        fi
    done < <(find "${DIRS[@]}" -name '*.gd' -print0 | sort -z)
    return "$failed"
}

main() {
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
