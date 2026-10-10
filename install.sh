#!/bin/bash

# ============================================================================
# Install everything legatus needs: Godot 4.7.2, scons + a C++ compiler, the
# godot-cpp submodule, the Python dev tools (gdlint/gdformat, pre-commit) in
# .venv, GUT, the compiled simulation GDExtension, the CC0 sound samples
# (scripts/fetch_audio.sh), git hooks.
# Idempotent; rerun after a pull.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT
readonly GUT_TAG="v9.7.1"   # newest stable; not tracked by the freshness gate
readonly VENV="$REPO_ROOT/.venv"

ensure_packages() {
    local missing=()
    command -v godot >/dev/null 2>&1 || missing+=(godot)
    command -v scons >/dev/null 2>&1 || missing+=(scons)
    command -v g++ >/dev/null 2>&1 || missing+=(gcc)
    # Sound samples: download, unpack, slice (scripts/fetch_audio.sh).
    command -v curl >/dev/null 2>&1 || missing+=(curl)
    command -v unzip >/dev/null 2>&1 || missing+=(unzip)
    command -v ffmpeg >/dev/null 2>&1 || missing+=(ffmpeg)
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Installing ${missing[*]}..."
        sudo pacman -S --needed --noconfirm "${missing[@]}"
    fi
}

ensure_python_tools() {
    # Repo-local venv: Arch's Python is PEP 668 managed.
    if [[ ! -x "$VENV/bin/python" ]]; then
        python3 -m venv "$VENV"
    fi
    "$VENV/bin/python" -m pip install --quiet -r "$REPO_ROOT/requirements-dev.txt"
}

ensure_gut() {
    local gut_dir="$REPO_ROOT/addons/gut"
    if [[ -f "$gut_dir/plugin.cfg" ]] && grep -q "${GUT_TAG#v}" "$gut_dir/plugin.cfg"; then
        return
    fi
    echo "Installing GUT ${GUT_TAG}..."
    rm -rf "$gut_dir"
    local tmp
    tmp="$(mktemp -d)"
    git clone -q --depth 1 --branch "$GUT_TAG" https://github.com/bitwes/Gut "$tmp"
    mkdir -p "$REPO_ROOT/addons"
    mv "$tmp/addons/gut" "$gut_dir"
    rm -rf "$tmp"
}

main() {
    ensure_packages
    git -C "$REPO_ROOT" submodule update --init --recursive
    ensure_python_tools
    ensure_gut
    "$REPO_ROOT/scripts/build.sh"
    "$REPO_ROOT/scripts/fetch_audio.sh" || echo "install: sounds not fetched, the game runs silent" >&2
    godot --headless --path "$REPO_ROOT" --import >/dev/null 2>&1 || true
    if [[ -d "$REPO_ROOT/.git" && -z "${CI:-}" ]]; then
        "$REPO_ROOT/scripts/install_hooks.sh"
    fi
    echo "legatus: ready."
}

main "$@"
