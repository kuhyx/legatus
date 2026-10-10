extends GutTest
## Spatial grid queries against brute force on a small scattered crowd.

const COUNT: int = 400
const AREA: float = 40.0


func _crowd() -> BattleSim:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var pos: PackedVector2Array = PackedVector2Array()
	var sides: PackedByteArray = PackedByteArray()
	if pos.resize(COUNT) != OK or sides.resize(COUNT) != OK:
		fail_test("could not allocate the crowd")
	for i: int in COUNT:
		pos[i] = Vector2(rng.randf_range(-AREA, AREA), rng.randf_range(-AREA, AREA) * 0.5)
		sides[i] = 0 if i < COUNT / 2 else 1
	var sim: BattleSim = BattleSim.new()
	sim.setup_custom(pos, sides, 1)
	sim.rebuild_grid()
	return sim


func _brute(pos: PackedVector2Array, index: int, radius: float) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for j: int in pos.size():
		if j != index and pos[j].distance_squared_to(pos[index]) <= radius * radius:
			var appended: bool = out.push_back(j)
			assert(not appended)
	return out


func test_neighbours_match_brute_force() -> void:
	var sim: BattleSim = _crowd()
	var pos: PackedVector2Array = sim.get_positions(1.0)
	for radius: float in [0.9, 2.0, 3.5, 7.0]:
		for i: int in range(0, COUNT, 7):
			var got: PackedInt32Array = sim.query_neighbors(i, radius)
			got.sort()
			assert_eq(got, _brute(pos, i, radius), "soldier %d radius %.1f" % [i, radius])


func test_nearest_enemy_matches_brute_force_within_search_radius() -> void:
	var sim: BattleSim = _crowd()
	var pos: PackedVector2Array = sim.get_positions(1.0)
	var checked: int = 0
	var reach: float = sim.get_search_cells() * 2.0  # rings of 2 m cells
	for i: int in COUNT:
		var best_d2: float = INF
		for j: int in COUNT:
			if (j < COUNT / 2) != (i < COUNT / 2):
				best_d2 = minf(best_d2, pos[j].distance_squared_to(pos[i]))
		var found: int = sim.find_enemy(i)
		if best_d2 <= reach * reach:
			checked += 1
			assert_ne(found, -1, "soldier %d has an enemy in range" % i)
			assert_almost_eq(pos[found].distance_squared_to(pos[i]), best_d2, 1e-4)
	assert_gt(checked, COUNT / 2, "most soldiers had an enemy in range")
	sim.set_search_cells(2)
	for i: int in COUNT:
		var found: int = sim.find_enemy(i)
		if found != -1:
			assert_lt(pos[found].distance_to(pos[i]), 4.0 * sqrt(2.0) + 2.0 * sqrt(2.0))
