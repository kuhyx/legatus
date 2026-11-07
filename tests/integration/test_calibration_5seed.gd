extends GutTest
## Morale regression: calibrate_morale.gd seeds 1-5, 15 game minutes each, in
## parallel; every seed must land in CalibrationBands. ~15 min of wall clock,
## so it runs only with LEGATUS_CALIB=1 (scripts/calibrate.sh --five).
## Knobs: LEGATUS_CALIB_SEEDS=A-B, LEGATUS_CALIB_MINUTES=N,
## LEGATUS_CALIB_TUNE=k:v,... (BattleSim.set_tuning keys).

const RUN_TIMEOUT_MS: int = 1_700_000  # under calibrate.sh's 1800 s, so a hung seed is named
const POLL_MS: int = 500
const LOG_DIR: String = "res://.shots/calibrate5"


func should_skip_script() -> Variant:
	return false if OS.get_environment("LEGATUS_CALIB") == "1" else "set LEGATUS_CALIB=1"


func test_every_seed_lands_in_the_band() -> void:
	var seeds: PackedInt32Array = _seeds(OS.get_environment("LEGATUS_CALIB_SEEDS"))
	assert_false(seeds.is_empty(), "LEGATUS_CALIB_SEEDS must be A-B")
	var dir: String = ProjectSettings.globalize_path(LOG_DIR)
	assert_eq(DirAccess.make_dir_recursive_absolute(dir), OK)
	var pids: Dictionary = {}
	for seed: int in seeds:
		pids[seed] = _start(seed, "%s/seed_%d.log" % [dir, seed])
	_wait(pids)
	var failed: Array[String] = []
	for seed: int in seeds:
		var log_text: String = FileAccess.get_file_as_string("%s/seed_%d.log" % [dir, seed])
		var line: String = CalibrationBands.result_line(log_text)
		gut.p("seed %d: %s" % [seed, line])
		failed.append_array(Array(CalibrationBands.failures(seed, line)))
	assert_eq(failed, [] as Array[String], "\n".join(PackedStringArray(failed)))


## "A-B" (default 1-5) -> [A..B]; malformed -> empty.
func _seeds(spec: String) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var ab: PackedStringArray = ("1-5" if spec.is_empty() else spec).split("-")
	if ab.size() != 2 or not ab[0].is_valid_int() or not ab[1].is_valid_int():
		return out
	for seed: int in range(ab[0].to_int(), ab[1].to_int() + 1):
		assert(not out.append(seed))
	return out


## One headless, muted calibrate_morale.gd run with stdout+stderr to `log_path`.
func _start(seed: int, log_path: String) -> int:
	var minutes: String = OS.get_environment("LEGATUS_CALIB_MINUTES")
	var args: PackedStringArray = PackedStringArray(
		[
			"-c",
			'log="$1"; shift; exec "$@" >"$log" 2>&1',
			"calibrate5",
			log_path,
			OS.get_executable_path(),
			"--headless",
			"--audio-driver",
			"Dummy",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"-s",
			"res://src/sim/calibrate_morale.gd",
			"--",
			"--minutes=%s" % ("15" if minutes.is_empty() else minutes),
			"--seed=%d" % seed,
			"--tune=%s" % OS.get_environment("LEGATUS_CALIB_TUNE"),
		]
	)
	var pid: int = OS.create_process("bash", args)
	assert_gt(pid, 0, "seed %d: cannot start godot" % seed)
	return pid


## Blocks until every run exits; kills what is left at RUN_TIMEOUT_MS.
func _wait(pids: Dictionary) -> void:
	var deadline: int = Time.get_ticks_msec() + RUN_TIMEOUT_MS
	var running: bool = true
	while running and Time.get_ticks_msec() < deadline:
		running = false
		for pid: int in pids.values():
			running = running or (pid > 0 and OS.is_process_running(pid))
		OS.delay_msec(POLL_MS)
	for pid: int in pids.values():
		if pid > 0 and OS.is_process_running(pid):
			assert_eq(OS.kill(pid), OK)
