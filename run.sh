#!/bin/bash

# ============================================================================
# Play legatus: install whatever is missing (install.sh), rebuild the C++
# simulation if its sources changed, then open the battle in a game window.
# Every argument is passed to the game, e.g. `./run.sh --debug`.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT
readonly LIB_GLOB="$REPO_ROOT/bin/liblegatus.linux.*.so"
readonly SRC_DIR="$REPO_ROOT/gdextension/src"

usage() {
    cat <<EOF
Usage: ${0##*/} [GAME OPTIONS]
Installs missing dependencies, rebuilds the simulation if needed, runs the game.
Game options (passed through):
  --debug            show soldier counts on the HUD
  --eye=X,Z          start the general at world X,Z instead of the vantage
  --order=N          at start, send order N (0 advance, 1 hold, 2 withdraw)
                     to the formation in view
  --seconds=N        quit after N seconds
  --screenshot=PATH  save the last frame as PNG (with --seconds)
  -h, --help         show this help
Keys in game: W/S gait, A/D turn, mouse look, 1/2/3 send an order, Esc mouse.
EOF
}

# The built library, or nothing if it does not exist yet.
built_library() {
    local lib
    for lib in $LIB_GLOB; do
        [[ -f "$lib" ]] && printf '%s\n' "$lib" && return
    done
}

needs_install() {
    command -v godot >/dev/null 2>&1 || return 0
    [[ -n "$(built_library)" ]] || return 0
    [[ -x "$REPO_ROOT/.venv/bin/python" ]] || return 0
    [[ -f "$REPO_ROOT/addons/gut/plugin.cfg" ]] || return 0
    return 1
}

# True when any C++ source or header is newer than the built library.
sources_changed() {
    local lib
    lib="$(built_library)"
    [[ -n "$(find "$SRC_DIR" "$REPO_ROOT/gdextension/SConstruct" -newer "$lib" \
        \( -name '*.cpp' -o -name '*.h' -o -name SConstruct \) -print -quit)" ]]
}

# Godot resolves `class_name` scripts from a cache that only an import
# refreshes: re-import when any script is newer than it (e.g. after a pull).
scripts_changed() {
    local cache="$REPO_ROOT/.godot/global_script_class_cache.cfg"
    [[ -f "$cache" ]] || return 0
    [[ -n "$(find "$REPO_ROOT/src" "$REPO_ROOT/scenes" -newer "$cache" -name '*.gd' \
        -print -quit)" ]]
}

main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi
    if needs_install; then
        echo "run: installing dependencies (install.sh)..."
        "$REPO_ROOT/install.sh"
    elif sources_changed; then
        echo "run: C++ sources changed, rebuilding the simulation..."
        "$REPO_ROOT/scripts/build.sh"
    fi
    if scripts_changed; then
        echo "run: scripts changed, refreshing Godot's import cache..."
        godot --headless --path "$REPO_ROOT" --import >/dev/null 2>&1 || true
    fi
    exec godot --path "$REPO_ROOT" -- "$@"
}

main "$@"
