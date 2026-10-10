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
    godot --headless --audio-driver Dummy --path "$REPO_ROOT" -s addons/gut/gut_cmdln.gd \
        -gdir=res://tests -ginclude_subdirs -gexit
}

main "$@"
