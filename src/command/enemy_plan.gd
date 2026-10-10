class_name EnemyPlan
extends RefCounted
## Placeholder for the enemy general's pre-battle plan (DOCS-design-command
## §1, plan dominance): his front line advances at ADVANCE_AT_S of sim time,
## his second line holds. Orders go straight into the sim (no enemy couriers
## yet); the real plan, with its own couriers and contingencies, replaces this.

const ADVANCE_AT_S: float = 60.0

var _sim: BattleSim = null
var _front: PackedInt32Array = PackedInt32Array()
var _elapsed: float = 0.0
var _done: bool = false


func _init(sim: BattleSim, front_line: PackedInt32Array) -> void:
	_sim = sim
	_front = front_line


## One sim tick (call inside the fixed-tick loop).
func tick(dt: float) -> void:
	_elapsed += dt
	if _done or _elapsed < ADVANCE_AT_S:
		return
	_done = true
	for f: int in _front:
		_sim.set_formation_order(f, BattleSim.ORDER_ADVANCE)
	print_verbose("enemy plan: t=%.1fs front line advances (%d blocks)" % [_elapsed, _front.size()])
