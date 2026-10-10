#!/bin/bash

# ============================================================================
# Compile the C++ simulation GDExtension into bin/. Locally the build runs in
# the capped scope (20 % CPU, 4 GiB); CI (no systemd user session) runs it
# directly. The first build also compiles godot-cpp and takes minutes.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly CAPPED="$HOME/.claude/scripts/capped.sh"

main() {
    local -a cmd=(scons -C "$REPO_ROOT/gdextension" platform=linux target=template_release -j5)
    if [[ -z "${CI:-}" && -x "$CAPPED" ]]; then
        CAP_CPU_PCT=20 CAP_MEM=4G "$CAPPED" "${cmd[@]}"
    else
        "${cmd[@]}"
    fi
}

main "$@"
