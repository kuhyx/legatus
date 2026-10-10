class_name BenchScenario
extends RefCounted
## The fixed worst case both perf gates run: two deep blocks of 50k, 1.5 km
## frontage, front ranks 6 m apart so the whole line charges into contact
## within ~2 s and then fights (push, melee, fatigue, death) for the rest.

const PER_SIDE: int = 50000
const FRONTAGE: float = 1500.0
const GAP: float = 6.0
const SEED: int = 42
const TICK_DT: float = 0.05


static func create() -> BattleSim:
	var sim: BattleSim = BattleSim.new()
	sim.setup_lines(PER_SIDE, FRONTAGE, GAP, SEED)
	return sim


## World-space box every soldier stays inside (custom MultiMesh AABB).
static func bounds() -> AABB:
	var half: float = FRONTAGE * 0.5 + 100.0
	return AABB(Vector3(-half, -1.0, -200.0), Vector3(half * 2.0, 4.0, 400.0))


## Value of a `--name=value` user arg (after `--`), or `fallback`.
static func arg(name: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a == "--" + name:
			return "true"
		if a.begins_with("--" + name + "="):
			return a.trim_prefix("--" + name + "=")
	return fallback
