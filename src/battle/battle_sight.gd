class_name BattleSight
extends RefCounted
## Keeps BattleSim's sight tiles current from the general's eye. The C++ ray
## march (BattleSim.compute_visibility_tiles) runs a slice of tiles per frame
## within BUDGET_USEC, so a full sweep never stalls a frame; each tile is at
## most one sweep stale.

## Per-frame time budget for tile updates.
const BUDGET_USEC: int = 2000
## Tiles per C++ call; the budget is checked between batches.
const BATCH: int = 64

## Visible tiles in the last completed sweep.
var visible_tiles: int = 0
## Completed sweeps so far.
var sweeps: int = 0
## Wall time of the last completed sweep: compute only, and from its first
## to its last frame.
var last_sweep_compute_usec: int = 0
var last_sweep_wall_usec: int = 0

var _sim: BattleSim = null
var _cursor: int = 0
var _seen: int = 0
var _compute_usec: int = 0
var _sweep_start_usec: int = 0


func _init(sim: BattleSim) -> void:
	_sim = sim


## Recompute every tile now (scene start, teleports). Returns visible tiles.
func full_sweep(eye: Vector3) -> int:
	var start: int = Time.get_ticks_usec()
	visible_tiles = _sim.compute_visibility_tiles(eye, 0, _sim.get_tile_count())
	last_sweep_compute_usec = Time.get_ticks_usec() - start
	last_sweep_wall_usec = last_sweep_compute_usec
	sweeps += 1
	_cursor = 0
	_seen = 0
	_compute_usec = 0
	return visible_tiles


## Advance the incremental sweep within the budget; `sweeps` counts the
## completed ones.
func step(eye: Vector3) -> void:
	var total: int = _sim.get_tile_count()
	if total == 0:
		return
	var start: int = Time.get_ticks_usec()
	if _cursor == 0:
		_sweep_start_usec = start
	while Time.get_ticks_usec() - start < BUDGET_USEC:
		var count: int = mini(BATCH, total - _cursor)
		_seen += _sim.compute_visibility_tiles(eye, _cursor, count)
		_cursor += count
		if _cursor >= total:
			_compute_usec += Time.get_ticks_usec() - start
			_finish_sweep()
			return
	_compute_usec += Time.get_ticks_usec() - start


func _finish_sweep() -> void:
	visible_tiles = _seen
	last_sweep_compute_usec = _compute_usec
	last_sweep_wall_usec = Time.get_ticks_usec() - _sweep_start_usec
	sweeps += 1
	_cursor = 0
	_seen = 0
	_compute_usec = 0
