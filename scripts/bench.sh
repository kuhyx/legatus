#!/bin/bash

# ============================================================================
# Perf gate 2 (kuhy runs this, never an agent: it opens a window). The fixed
# 100k battle rendered from a rider's eye, UNCAPPED, auto-exit after 30 s;
# prints p50/p99 frame ms plus sim tick stats. Args go to the scene after
# `--`: `--seconds=N`, `--no-lod` (full soldier mesh at every distance).
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT

main() {
    godot --path "$REPO_ROOT" --audio-driver Dummy res://scenes/bench/bench.tscn -- "$@"
}

main "$@"
