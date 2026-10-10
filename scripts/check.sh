#!/bin/bash

# ============================================================================
# The whole local gate in one exit code: build, lint, tests, the headless sim
# benchmark, and the four shared gates (file length, markdown naming, no
# binaries, dependency freshness).
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT

main() {
    cd "$REPO_ROOT"   # the shared gates resolve the repo from cwd
    scripts/build.sh
    scripts/lint.sh
    scripts/test.sh
    scripts/check_file_length.sh --all
    scripts/check_md_naming.sh --all
    git ls-files -z | xargs -0 scripts/check_no_binaries.sh
    scripts/check_dependency_freshness.sh --all
    echo "check: all green"
}

main "$@"
