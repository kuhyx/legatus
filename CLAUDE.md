# CLAUDE.md — legatus

Godot 4.7.2 (Forward+) + a C++ GDExtension (godot-cpp `godot-4.5-stable`,
submodule). Realistic ancient battle simulator: you are the general, first
person on horseback, seeing only what a rider sees, commanding by courier.
Target: 2x50k individually simulated soldiers at >=60 fps on an RTX 3090.
Remote: `github.com/kuhyx/legatus` (public, experiment). `DOCS-design*.md`
hold the sourced mechanics, kuhy's decisions and the numbers table (ACOUP "Total Generalship"); constants come from there.

## Commands

- run: `./run.sh` (installs what is missing, rebuilds changed C++, then
  `godot --path . -- ARGS`; opens a window: kuhy's only, agents use xvfb-run).
  Plain `godot --path .` (main scene `scenes/battle/battle.tscn`; user args after
  `--`: `--seconds=N`, `--screenshot=PATH`, `--eye=X,Z`, `--debug`,
  `--speed=N` debug: sim N x real time (<= 16),
  `--order=N` send 0 advance / 1 hold / 2 withdraw at start to the block in
  view, `--order-to=F` to block F instead, `--order-at=S` at sim second S;
  comma lists send several, e.g. `--order=2,1 --order-to=11,15
  --order-at=0,200`; `--start-at=S` runs the sim headlessly to sim second S
  before the first frame; add `--verbose` for the `couriers:` / `orders:` /
  `reports:` / `formations:` log)
- screenshot (off the live display, Forward+, muted: agent runs ALWAYS pass
  `--audio-driver Dummy`, kuhy hears them otherwise): `capped.sh xvfb-run -a -s
  '-screen 0 1920x1080x24' godot --rendering-driver vulkan --audio-driver Dummy
  --gpu-index 0 --resolution 96x54 --path . scenes/battle/battle.tscn --
  --seconds=4 --render-size=1920x1080 --screenshot=$PWD/.shots/general_view.png`
  (a bigger window costs ~50 ms a frame in Xvfb copies: no timings from it)
  (`.shots/` is ignored)
- calibrate morale: `scripts/calibrate.sh --quick [--tune=k:v,...]` (seed 6,
  full 2x50k, ~50 s; gates loser 14-16 / winner 4-5 % killed, break <= 10 %
  vs DOCS-design-army §4). Without `--quick`: seeds 1-20, ~15 min, kuhy only.
  One seed raw: `capped.sh godot --headless --audio-driver Dummy --path .
  -s res://src/sim/calibrate_morale.gd -- --seed=6 [--tune=k:v,...]`
- build: `scripts/build.sh` (C++ GDExtension -> `bin/`, capped)
- sounds: `scripts/fetch_audio.sh` (CC0 samples -> ignored `assets/audio/`,
  sha256-pinned in the tracked `assets/audio/sources.tsv`; install.sh runs it)
- record with sound (Movie Maker, AVI + PCM): `CAP_CPU_PCT=20 CAP_MEM=4G
  capped.sh xvfb-run -a -s '-screen 0 640x360x24' godot --rendering-driver vulkan
  --path . --write-movie $PWD/.shots/ride_audio.avi --fixed-fps 30
  scenes/battle/battle.tscn -- --seconds=30 --demo-ride --render-size=1280x720`
- bench-headless: `scripts/bench_headless.sh` (100k sim tick p50/p99, capped)
- bench: `scripts/bench.sh --offscreen` (fps gate on the real GPU inside Xvfb,
  capped, nothing on kuhy's screen; agents run THIS). Plain `scripts/bench.sh`
  opens a real window and is kuhy's only. Frames land in `.shots/bench_*.png`.
  The battle run fast-forwards to `--start-at=170` (fronts meet ~159 s) and
  fails unless a formation is engaged on every tick of the timed window.
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
  through `~/.claude/scripts/capped.sh`. Forward+ renders on the RTX 3090
  inside Xvfb (`--rendering-driver vulkan`); keep that window tiny and use
  `--render-size=1920x1080`, or copying frames to Xvfb dominates timings.

## Layout

- `gdextension/src/` — C++ simulation (structure-of-arrays, spatial grid, worker threads).
  `battle_sim_run.cpp` tick, `battle_sim_fill.cpp` MultiMesh fills,
  `battle_sim_view.cpp` + `sim_view.*` the general's view (below),
  `sim_formation.*` + `battle_sim_formation.cpp` formations (below),
  `sim_orders.cpp` orders, withdraw halt, rally, `sim_steer.cpp` per-order
  steering, `battle_sim_setup.cpp` the battle's lines (`setup_array`).
- `src/sim/` — GDScript glue: battle setup, MultiMesh rendering.
- `src/general/` — the player: horse, rider camera, line-of-sight visibility.
- `src/battle/` — the playable battle: `BattleWorld` (terrain, flattened plain,
  woods, 2x50k sim in lines 150 m apart, all on hold, start on rising ground
  behind side 0), `BattleSight` (time-budgeted sight-tile sweeps),
  `FormationLog` (`--verbose` state changes), `ContactProbe` (engaged
  formations in a timed run, the bench's contact gate), `battle.gd` (scene, HUD).
- `src/command/` — orders by courier (DOCS-design-command §3): `CourierService`
  (pool, sim-tick step, seeded RNG) over a `FormationSource` of Callables,
  `CourierSettings` (numbers-table guesses), `OrderPicker`, `OrderInput` (1/2/3),
  `BattleCommand` (the node in battle.gd: keys -> courier, riders in sight),
  `Officers` (per-officer ignore chance, own seeded roll stream), `OrderLog`
  (HUD orders: sent / acknowledged / found them broken), `ReportService` +
  `ReportRider` + `ReportLevel` (officers' reports by rider, morale bias),
  `RiderView`, `BattleClock` (08:00 + sim time), `EnemyPlan` (placeholder:
  the enemy front line advances at 60 s). `src/battle/battle_hud.gd` draws it.
- `src/audio/` — sound (`BattleSound` wires it in battle.gd): `AudioBank`
  (samples; a missing file plays nothing), `RiderAudio` (own hooves on the
  stride clock via `Footfalls`, saddle creak, snorts, wind ~speed^2, M mutes),
  `BattleAudio` (16 `DinEmitter`s on the nearest engaged/routed formations,
  `DinSelect`: distance only, no sight test), `CourierAudio` (hooves <= 300 m).
  Levels are `AudioTuning` [design guess].
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

## Formations (morale + order groups)

- Ids are contiguous, side 0 first (`setup_lines`: ~60-file blocks, bench and
  calibration only; `setup_array`: the battle, lines front first;
  `setup_custom`: one per side; `set_formation_ids(ids)` regroups).
- WITHDRAW walks `withdraw_dist` back, then HOLDs; routed / withdrawing men
  pass through friends; routers rally once (`is_formation_rallied`). Rows in
  `DOCS-design.md`. A man searches for enemies only if an enemy block's box
  is within search reach (`near_ids`): armies apart cost ~2 ms a tick.
- `get_formation_count/side/center/order/cohesion/losses/break_losses/strength`,
  `is_formation_routed/engaged`, `set_formation_order(f, ORDER_ADVANCE|HOLD|WITHDRAW)`
  (ignored once routed). Serial formation pass after damage (determinism).
- Routers leaving the clamp box become `ST_FLED`: not drawn, not alive,
  `get_fled(side)`. `set_tuning(dict)` / `get_tuning()` expose the constants.
