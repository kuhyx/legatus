extends SceneTree
## Gate 1: 2 x 50k soldiers, lines 6 m apart so they charge into contact within
## ~2 s, 400 ticks at 20 Hz (20 s of game time). Ticks are paced in real time
## like the game; pass `-- --unpaced` to run them back to back, and
## `--search-cells=N` to widen the nearest-enemy search (2 m cells, default 24).
## Prints alive counts, tick percentiles and worker threads; exits 1 when nobody died
## (no casualties = no contact = the run proved nothing).

const TICK_DT: float = BenchScenario.TICK_DT
const DEFAULT_TICKS: int = 400


func _initialize() -> void:
	var ticks: int = BenchScenario.arg("ticks", str(DEFAULT_TICKS)).to_int()
	var paced: bool = BenchScenario.arg("unpaced", "false") != "true"
	quit(_run(ticks, paced))


func _run(ticks: int, paced: bool) -> int:
	var sim: BattleSim = BenchScenario.create()
	sim.set_search_cells(BenchScenario.arg("search-cells", "24").to_int())
	var start: Array[int] = [sim.get_alive(0), sim.get_alive(1)]
	print(
		(
			"bench_headless: soldiers=%d ticks=%d paced=%s chunks=%d cpus=%d search=%dm"
			% [
				sim.get_count(),
				ticks,
				paced,
				sim.get_chunk_count(),
				OS.get_processor_count(),
				sim.get_search_cells() * 2,
			]
		)
	)
	print("alive start: side0=%d side1=%d" % [start[0], start[1]])
	var tick_ms: SimStats = SimStats.new()
	var threads: SimStats = SimStats.new()
	var next_usec: int = Time.get_ticks_usec()
	for i: int in ticks:
		sim.tick(TICK_DT)
		tick_ms.add(sim.get_last_tick_usec() / 1000.0)
		threads.add(sim.get_last_tick_threads())
		if i % 100 == 99:
			print("  tick %d alive %d / %d" % [i + 1, sim.get_alive(0), sim.get_alive(1)])
		next_usec += int(TICK_DT * 1000000.0)
		if paced:
			OS.delay_usec(maxi(0, next_usec - Time.get_ticks_usec()))
	var dead: int = start[0] + start[1] - sim.get_alive(0) - sim.get_alive(1)
	print("alive end: side0=%d side1=%d casualties=%d" % [sim.get_alive(0), sim.get_alive(1), dead])
	print(tick_ms.summary("tick_ms"))
	print(threads.summary("threads_per_tick"))
	if dead == 0:
		push_error("bench_headless: no casualties - the lines never made contact")
		return 1
	return 0
