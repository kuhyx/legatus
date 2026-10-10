# CLAUDE.md — legatus

Godot 4.7.2 (Forward+) + a C++ GDExtension (godot-cpp `godot-4.5-stable`,
submodule). Realistic ancient battle simulator: you are the general, first
person on horseback, seeing only what a rider sees, commanding by courier.
Target: 2x50k individually simulated soldiers at >=60 fps on an RTX 3090.
Remote: `github.com/kuhyx/legatus` (public, experiment). `DOCS-design*.md`
hold the sourced mechanics, kuhy's decisions and the numbers table (ACOUP "Total Generalship"); constants come from there.

## Commands

- run: `godot --path .` (main scene `scenes/battle/battle.tscn`; user args after
  `--`: `--seconds=N`, `--screenshot=PATH`, `--eye=X,Z`, `--debug`)
- screenshot (off the live display): `capped.sh xvfb-run -a -s '-screen 0 2560x1440x24'
  godot --rendering-driver opengl3 --path . scenes/battle/battle.tscn --
  --seconds=4 --screenshot=$PWD/.shots/general_view.png` (`.shots/` is ignored)
- build: `scripts/build.sh` (C++ GDExtension -> `bin/`, capped)
- bench-headless: `scripts/bench_headless.sh` (100k sim tick p50/p99, capped)
- bench: `scripts/bench.sh` (windowed fps; kuhy runs it, never an agent)
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
  `battle_sim_run.cpp` tick, `battle_sim_fill.cpp` MultiMesh fills,
  `battle_sim_view.cpp` + `sim_view.*` the general's view (below).
- `src/sim/` — GDScript glue: battle setup, MultiMesh rendering.
- `src/general/` — the player: horse, rider camera, line-of-sight visibility.
- `src/battle/` — the playable battle: `BattleWorld` (terrain, flattened plain,
  woods, 2x50k sim, start on rising ground behind side 0), `BattleSight`
  (time-budgeted sight-tile sweeps), `battle.gd` (scene, HUD).
- `scenes/battle/` — main scene: the general rides around the live battle.
- `scenes/bench/` — fixed worst-case 100k scenario for both perf gates.
- `scenes/general/` — ride-around scene for the general (dummy formations).

## The general's view (R4: draw only what he could see)

- `set_height_field(heights, resolution, spacing, origin)` — HeightField's
  arrays, origin = `sample_position(0, 0)`; fills stand soldiers on it
  (bilinear, same clamp as `HeightField.height_at`). No field = y 0.
- `set_visibility_tiles(mask, origin, tile_size, cols, rows)` — 1 = seen;
  fills skip soldiers in hidden tiles (compacted buffers, counts only of drawn;
  outside the grid = drawn; empty mask = culling off).
  `compute_visibility_tiles(eye, first, count)` ray-marches tile centres
  (+`VisionTable.TARGET_HEIGHT_M`) in C++; `set_sight(dict)` passes the
  VisionTable constants + woods (C++ port of `Visibility`, parity-tested).
- Counts: `get_drawn_count(side)` (incl. the fallen), `get_visible_alive(side)`.
