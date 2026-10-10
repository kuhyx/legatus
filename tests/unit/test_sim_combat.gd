extends GutTest
## Contact causes damage, distance does not, and results are deterministic.


func _pair(gap: float) -> BattleSim:
	var sim: BattleSim = BattleSim.new()
	sim.setup_custom(
		PackedVector2Array([Vector2(0, 0), Vector2(0, gap)]), PackedByteArray([0, 1]), 3
	)
	return sim


func _run(sim: BattleSim, ticks: int) -> void:
	for _i: int in ticks:
		sim.tick(0.05)


func test_soldiers_in_contact_take_damage() -> void:
	var sim: BattleSim = _pair(1.2)
	_run(sim, 200)
	var lost: int = 2 * sim.get_max_hp() - sim.get_hp(0) - sim.get_hp(1)
	assert_gt(lost, 0, "10 s of melee draws blood")


func test_soldiers_far_apart_take_no_damage() -> void:
	var sim: BattleSim = _pair(100.0)
	_run(sim, 50)
	assert_eq(sim.get_hp(0), sim.get_max_hp())
	assert_eq(sim.get_hp(1), sim.get_max_hp())


func test_lines_in_contact_suffer_casualties() -> void:
	var sim: BattleSim = BattleSim.new()
	sim.setup_lines(2000, 100.0, 4.0, 5)
	_run(sim, 300)
	assert_lt(sim.get_alive(0) + sim.get_alive(1), 4000, "15 s of melee kills someone")


func _battle(chunks: int) -> BattleSim:
	var sim: BattleSim = BattleSim.new()
	sim.set_chunk_count(chunks)
	sim.setup_lines(3000, 120.0, 4.0, 9)
	_run(sim, 120)
	return sim


func test_same_seed_same_outcome_whatever_the_chunking() -> void:
	var a: BattleSim = _battle(128)
	var b: BattleSim = _battle(128)
	var c: BattleSim = _battle(7)
	assert_eq(a.get_alive(0), b.get_alive(0))
	assert_eq(a.get_alive(1), b.get_alive(1))
	assert_eq(a.get_alive(0), c.get_alive(0))
	assert_eq(a.get_alive(1), c.get_alive(1))
	assert_eq(a.get_positions(1.0), b.get_positions(1.0), "bitwise identical positions")
	assert_eq(a.get_positions(1.0), c.get_positions(1.0), "chunking does not change positions")
	assert_lt(a.get_alive(0) + a.get_alive(1), 6000, "the battle actually fought")
