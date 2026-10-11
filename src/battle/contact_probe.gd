class_name ContactProbe
extends RefCounted
## Melee during a timed battle run: how many formations are engaged (a man of
## theirs trading blows, BattleSim.is_formation_engaged), sampled once per sim
## tick. scripts/bench.sh reads the summary line and fails a battle run whose
## measured window had no contact: a frame gate that never saw melee measures
## the march, not the battle.

var _min: int = -1
var _max: int = 0
var _samples: int = 0
var _formations: int = 0


## Count the engaged formations of `sim` now.
func sample(sim: BattleSim) -> void:
	var engaged: int = 0
	_formations = sim.get_formation_count()
	for f: int in _formations:
		if sim.is_formation_engaged(f):
			engaged += 1
	_min = engaged if _min < 0 else mini(_min, engaged)
	_max = maxi(_max, engaged)
	_samples += 1


## One line: "contact engaged_min=.. engaged_max=.. of=.. (n=..)": engaged
## formation counts over the samples (0 when there were none) of all `of`.
func summary() -> String:
	return (
		"contact engaged_min=%d engaged_max=%d of=%d (n=%d)"
		% [maxi(_min, 0), _max, _formations, _samples]
	)
