#!/bin/bash

# ============================================================================
# Install this repo's git hooks.
#
# .git/hooks/ is not tracked, so a fresh clone has no hooks. Run this once
# after cloning. The checks themselves live in .pre-commit-config.yaml; the
# four shared gates (line cap, markdown naming, dependency freshness, no
# binaries) are shims over ~/src/utils, so that clone has to exist too.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
readonly REPO_ROOT
readonly UTILS_ROOT="${UTILS_ROOT:-$HOME/src/utils}"

ensure_pre_commit() {
    if command -v pre-commit >/dev/null 2>&1; then
        return
    fi
    echo "Installing pre-commit..."
    if command -v pipx >/dev/null 2>&1; then
        pipx install pre-commit
    else
        python3 -m pip install --user pre-commit
    fi
}

ensure_shared_gates() {
    if [[ -d "$UTILS_ROOT/scripts" ]]; then
        return
    fi
    echo "Cloning the shared gates to $UTILS_ROOT..."
    git clone --depth 1 https://github.com/kuhyx/utils "$UTILS_ROOT"
}

main() {
    ensure_pre_commit
    ensure_shared_gates
    cd "$REPO_ROOT"
    pre-commit install
    echo "Installed pre-commit hooks: $REPO_ROOT/.git/hooks/pre-commit"
}

main "$@"
