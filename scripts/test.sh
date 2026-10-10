#!/bin/bash

# ============================================================================
# Run every GUT test (tests/unit + tests/integration) headless.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT

main() {
    if [[ ! -f "$REPO_ROOT/addons/gut/gut_cmdln.gd" ]]; then
        echo "GUT missing: run ./install.sh" >&2
        exit 1
    fi
    # GUT skips a test script that fails to parse and still exits 0, so the
    # log is checked too: a skipped or erroring script fails the run.
    local log status=0
    log="$(godot --headless --audio-driver Dummy --path "$REPO_ROOT" -s addons/gut/gut_cmdln.gd \
        -gdir=res://tests -ginclude_subdirs -gexit 2>&1)" || status=$?
    printf '%s\n' "$log"
    if grep -qE 'SCRIPT ERROR|Ignoring script|Parse Error' <<<"$log"; then
        echo "test: a test script errored or was skipped" >&2
        exit 1
    fi
    exit "$status"
}

main "$@"
