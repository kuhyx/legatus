extends SceneTree
## Morale calibration: the bench battle (2 x 50k, BenchScenario) run unpaced
## until one side has broken and the pursuit is over, against the historical
## targets (DOCS-design-army §4): units break at or before 10 % losses,
## winners lose ~4-5 % killed, losers ~14-16 %.
## Run: capped.sh godot --headless --audio-driver Dummy --path .
##   -s res://src/sim/calibrate_morale.gd -- [--minutes=30] [--per-side=50000]
##   [--frontage=1500] [--gap=6] [--seed=42] [--every=1200 ticks]
##   [--tune=kill_chance:0.001,contagion:0.05] (BattleSim.set_tuning keys)
## Prints a line per game minute, then per side: formations broken, losses at
## break (min / median / max), killed and fled, and kills before / after breaks.

const TICK_DT: float = BenchScenario.TICK_DT
const TICKS_PER_MINUTE: int = 1200
## Game minutes of pursuit after the last break before stopping.
const PURSUIT_MINUTES: int = 3

var _sim: BattleSim
## Ticks between progress lines (`--every=N`, default one game minute).
var _every: int = TICKS_PER_MINUTE
## Per formation: start strength, tick of the break (-1 = never), dead + fled then.
var _start: PackedInt32Array = PackedInt32Array()
var _break_tick: PackedInt32Array = PackedInt32Array()
var _lost_at_break: PackedInt32Array = PackedInt32Array()
## Per side: killed when its first formation broke (-1 = none broke).
var _dead_at_first_break: PackedInt32Array = PackedInt32Array([-1, -1])


func _initialize() -> void:
	var minutes: int = BenchScenario.arg("minutes", "30").to_int()
	_every = maxi(1, BenchScenario.arg("every", str(TICKS_PER_MINUTE)).to_int())
	_sim = BattleSim.new()
	_sim.set_tuning(_tuning(BenchScenario.arg("tune", "")))
	_sim.setup_lines(
		BenchScenario.arg("per-side", str(BenchScenario.PER_SIDE)).to_int(),
		BenchScenario.arg("frontage", str(BenchScenario.FRONTAGE)).to_float(),
		BenchScenario.arg("gap", str(BenchScenario.GAP)).to_float(),
		BenchScenario.arg("seed", str(BenchScenario.SEED)).to_int()
	)
	var n: int = _sim.get_formation_count()
	for f: int in n:
		assert(not _start.append(_sim.get_formation_strength(f)))
	assert(_break_tick.resize(n) == OK)
	assert(_lost_at_break.resize(n) == OK)
	_break_tick.fill(-1)
	print("calibrate_morale: soldiers=%d formations=%d max=%d min" % [_sim.get_count(), n, minutes])
	_run(minutes * TICKS_PER_MINUTE)
	_report()
	quit(0)


## `key:value,key:value` -> Dictionary of floats for BattleSim.set_tuning.
func _tuning(spec: String) -> Dictionary:
	var out: Dictionary = {}
	for pair: String in spec.split(",", false):
		var kv: PackedStringArray = pair.split(":")
		if kv.size() == 2:
			out[kv[0]] = kv[1].to_float()
	print("tuning: %s" % _sim.get_tuning().merged(out, true))
	return out


func _run(max_ticks: int) -> void:
	var last_break: int = -1
	var last_contact: int = 0
	for tick: int in max_ticks:
		_sim.tick(TICK_DT)
		for f: int in _sim.get_formation_count():
			if _sim.is_formation_engaged(f):
				last_contact = tick
				break
		for f: int in _sim.get_formation_count():
			if _break_tick[f] < 0 and _sim.is_formation_routed(f):
				_break_tick[f] = tick
				_lost_at_break[f] = _lost(f)
				last_break = tick
				var side: int = _sim.get_formation_side(f)
				if _dead_at_first_break[side] < 0:
					_dead_at_first_break[side] = _dead(side)
		if tick % _every == _every - 1:
			_print_minute(tick + 1)
		var quiet: int = PURSUIT_MINUTES * TICKS_PER_MINUTE
		if last_break >= 0 and tick - last_break >= quiet and tick - last_contact >= quiet:
			print(
				(
					"stopped at %.0fs: no break and no contact for %d min"
					% [tick * TICK_DT, PURSUIT_MINUTES]
				)
			)
			return


## Men of formation f killed or fled so far.
func _lost(f: int) -> int:
	return roundi(_sim.get_formation_losses(f) * _start[f])


func _dead(side: int) -> int:
	return _sim.get_side_count(side) - _sim.get_alive(side) - _sim.get_fled(side)


func _print_minute(tick: int) -> void:
	var parts: PackedStringArray = PackedStringArray()
	for side: int in 2:
		var routed: int = 0
		var engaged: int = 0
		var coh: float = 0.0
		var count: int = 0
		for f: int in _sim.get_formation_count():
			if _sim.get_formation_side(f) != side:
				continue
			count += 1
			routed += 1 if _sim.is_formation_routed(f) else 0
			engaged += 1 if _sim.is_formation_engaged(f) else 0
			coh += _sim.get_formation_cohesion(f)
		var total: float = _sim.get_side_count(side)
		var part: String = (
			"s%d dead %.2f%% fled %.2f%% routed %d/%d engaged %d coh %.2f"
			% [
				side,
				100.0 * _dead(side) / total,
				100.0 * _sim.get_fled(side) / total,
				routed,
				count,
				engaged,
				coh / maxf(1.0, count),
			]
		)
		assert(not parts.append(part))
	print("t %6.1fs | %s" % [tick * TICK_DT, " | ".join(parts)])


func _report() -> void:
	for side: int in 2:
		var breaks: Array[float] = []
		var lost_by_break: int = 0
		var lost_final: int = 0
		for f: int in _sim.get_formation_count():
			if _sim.get_formation_side(f) != side or _break_tick[f] < 0:
				continue
			breaks.append(_sim.get_formation_break_losses(f))
			lost_by_break += _lost_at_break[f]
			lost_final += _lost(f)
		breaks.sort()
		var total: float = _sim.get_side_count(side)
		print(
			(
				"side %d: broken %d | break losses min %s median %s max %s | killed %.2f%% fled %.2f%%"
				% [
					side,
					breaks.size(),
					_pct(breaks, 0.0),
					_pct(breaks, 0.5),
					_pct(breaks, 1.0),
					100.0 * _dead(side) / total,
					100.0 * _sim.get_fled(side) / total,
				]
			)
		)
		var first: int = _dead_at_first_break[side]
		print(
			(
				(
					"  killed before the side's first break %s, after %s"
					+ " | routed formations lost %d by their breaks, %d by the end"
				)
				% [
					str(first) if first >= 0 else "-",
					str(_dead(side) - first) if first >= 0 else "-",
					lost_by_break,
					lost_final,
				]
			)
		)


func _pct(sorted: Array[float], p: float) -> String:
	if sorted.is_empty():
		return "-"
	return (
		"%.1f%%" % (100.0 * sorted[clampi(roundi(p * (sorted.size() - 1)), 0, sorted.size() - 1)])
	)
