# CLAUDE.md — legatus

Godot 4.7.2 (Forward+) + a C++ GDExtension (godot-cpp `godot-4.5-stable`,
submodule). Realistic ancient battle simulator: you are the general, first
person on horseback, seeing only what a rider sees, commanding by courier.
Target: 2x50k individually simulated soldiers at >=60 fps on an RTX 3090.
Local repo (no remote yet). `DOCS-design*.md` hold the sourced mechanics and
the numbers table (ACOUP "Total Generalship"); constants come from there.

## Commands

- run: `godot --path .`
- build: `scripts/build.sh` (C++ GDExtension -> `bin/`, capped)
- test: `scripts/test.sh`
- test-changed: `scripts/test_changed.sh`
- lint: `scripts/lint.sh`
- coverage: n/a: no coverage tooling for this stack
- coverage-gaps: n/a: no coverage tooling for this stack

## Rules

- **Every GDScript warning is an error** (`project.godot [debug]`): no `:=`,
  every declaration typed, every non-void return used or bound. `scripts/lint.sh`
  fails otherwise. No ignore annotations without asking.
- 250 lines per file, code and prose (shared gate). Split, do not squeeze.
- No binaries in git. `bin/`, GUT and `.godot/` are made by `install.sh`.
- Rebuild (`scripts/build.sh`) after any C++ change before running Godot.
- After adding a `class_name` script run `godot --headless --path . --import`.
- Never open a window on the live display. Headless runs and builds go
  through `~/.claude/scripts/capped.sh`; the windowed fps bench
  (`scripts/bench.sh`) is run by kuhy, never by an agent.

## Layout

- `gdextension/src/` — C++ simulation (structure-of-arrays, spatial grid, worker threads).
- `src/sim/` — GDScript glue: battle setup, MultiMesh rendering.
- `src/general/` — the player: horse, rider camera, line-of-sight visibility.
- `scenes/bench/` — fixed worst-case 100k scenario for both perf gates.
- `scenes/general/` — ride-around scene for the general.
