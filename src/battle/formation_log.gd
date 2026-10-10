class_name FormationLog
extends RefCounted
## `--verbose` only: once a second of sim time, one line per formation whose
## state changed (engaged, routed, rallied, order), so a run's log shows the
## battle unfold. A debugging aid; the general himself gets no such feed.

const PERIOD_S: float = 1.0
const ORDER_NAMES: PackedStringArray = ["advance", "hold", "withdraw"]

var _sim: BattleSim = null
var _last: PackedStringArray = PackedStringArray()
var _elapsed: float = 0.0
var _timer: float = 0.0


func _init(sim: BattleSim) -> void:
	_sim = sim
	if _last.resize(sim.get_formation_count()) != OK:
		push_error("FormationLog: cannot size the formation table")


## One sim tick (call inside the fixed-tick loop).
func tick(dt: float) -> void:
	_elapsed += dt
	_timer += dt
	if _timer < PERIOD_S or not OS.is_stdout_verbose():
		return
	_timer = 0.0
	for f: int in mini(_last.size(), _sim.get_formation_count()):
		var now: String = describe(f)
		if now != _last[f]:
			print(
				(
					"formations: t=%.1fs f%d side %d %s"
					% [_elapsed, f, _sim.get_formation_side(f), now]
				)
			)
			_last[f] = now


func describe(f: int) -> String:
	var state: String = ORDER_NAMES[_sim.get_formation_order(f)]
	if _sim.is_formation_routed(f):
		state = "ROUTED"
	elif _sim.is_formation_rallied(f):
		state += " (rallied)"
	if _sim.is_formation_engaged(f):
		state += " engaged"
	return state
