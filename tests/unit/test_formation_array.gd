extends GutTest
## BattleSim.setup_array: each side in lines one behind the other, ~60-file
## blocks, ids contiguous (side 0 first, front line first), the sim box roomy
## enough for a 150 m withdrawal of every block. Also BattleWorld's wiring of
## it with the battle's real numbers.

const GAP: float = 150.0
const LINE_GAP: float = 80.0
const RANK_GAP: float = 1.1
const JITTER: float = 0.15  # setup jitters each man by +-0.1 m
const LINES_2: PackedFloat32Array = [0.6, 0.4]
const LINES_3: PackedFloat32Array = [0.5, 0.3, 0.2]

var _real: BattleSim


func before_all() -> void:
	_real = BattleSim.new()
	(
		_real
		. setup_array(
			50000,
			BenchScenario.FRONTAGE,
			BattleWorld.OPENING_GAP_M,
			BattleWorld.LINE_GAP_M,
			BattleWorld.ROMAN_LINES,
			BattleWorld.ENEMY_LINES,
			BenchScenario.SEED,
		)
	)


func _small(per_side: int = 3000) -> BattleSim:
	var sim: BattleSim = BattleSim.new()
	sim.setup_array(per_side, 120.0, GAP, LINE_GAP, LINES_2, LINES_2, 5)
	return sim


func test_small_case_has_two_blocks_per_line_and_the_line_strengths() -> void:
	var sim: BattleSim = _small()
	assert_eq(sim.get_formation_count(), 8, "2 lines x 2 blocks x 2 sides")
	var want: Array[int] = [900, 900, 600, 600, 900, 900, 600, 600]
	var sides: Array[int] = []
	var got: Array[int] = []
	for f: int in sim.get_formation_count():
		sides.append(sim.get_formation_side(f))
		got.append(sim.get_formation_strength(f))
	assert_eq(sides, [0, 0, 0, 0, 1, 1, 1, 1], "contiguous, side 0 first")
	assert_eq(got, want, "front line (60 %) first, then the second (40 %)")
	assert_eq(sim.get_side_count(0), 3000)
	assert_eq(sim.get_side_count(1), 3000)


func test_three_lines_split_by_share_and_the_last_takes_the_rest() -> void:
	var sim: BattleSim = BattleSim.new()
	sim.setup_array(3001, 120.0, GAP, LINE_GAP, LINES_3, LINES_2, 5)
	var strength: Array[int] = [0, 0]
	for f: int in sim.get_formation_count():
		strength[sim.get_formation_side(f)] += sim.get_formation_strength(f)
	assert_eq(strength, [3001, 3001], "nobody lost to rounding")
	assert_eq(sim.get_formation_count(), 6 + 4, "3 lines + 2 lines, 2 blocks each")


func test_front_ranks_stand_half_the_gap_from_the_centre() -> void:
	var sim: BattleSim = _small()
	var side_0: Rect2 = sim.get_formation_bounds(0)
	var side_1: Rect2 = sim.get_formation_bounds(4)
	assert_almost_eq(side_0.end.y, -0.5 * GAP, JITTER, "side 0 front rank at -gap/2")
	assert_almost_eq(side_1.position.y, 0.5 * GAP, JITTER, "side 1 front rank at +gap/2")
	assert_almost_eq(side_1.position.y - side_0.end.y, GAP, 2.0 * JITTER)


func test_line_gap_runs_from_the_rear_rank_to_the_next_front_rank() -> void:
	var sim: BattleSim = _small()
	var front: Rect2 = sim.get_formation_bounds(0)
	var second: Rect2 = sim.get_formation_bounds(2)
	assert_almost_eq(front.size.y, 14.0 * RANK_GAP, 2.0 * JITTER, "900 men / 60 files = 15 ranks")
	assert_almost_eq(front.position.y - second.end.y, LINE_GAP, 2.0 * JITTER, "side 0, -z")
	var enemy_front: Rect2 = sim.get_formation_bounds(4)
	var enemy_second: Rect2 = sim.get_formation_bounds(6)
	assert_almost_eq(enemy_second.position.y - enemy_front.end.y, LINE_GAP, 2.0 * JITTER, "side 1")


func test_blocks_of_a_line_sit_side_by_side_without_overlap() -> void:
	var sim: BattleSim = _small()
	var left: Rect2 = sim.get_formation_bounds(0)
	var right: Rect2 = sim.get_formation_bounds(1)
	assert_almost_eq(left.size.x, 59.0, 2.0 * JITTER, "60 files, 1 m apart")
	assert_false(left.intersects(right), "blocks 0 and 1 do not overlap")
	assert_almost_eq(left.get_center().y, right.get_center().y, 0.5, "same line, same depth")


func test_the_box_encloses_every_formation_and_a_full_withdrawal() -> void:
	for sim: BattleSim in [_small(), _real]:
		var box: Rect2 = sim.get_bounds()
		for f: int in sim.get_formation_count():
			var rect: Rect2 = sim.get_formation_bounds(f)
			assert_true(box.encloses(rect), "formation %d inside the box" % f)
			var back: float = -150.0 if sim.get_formation_side(f) == 0 else 150.0
			assert_true(box.encloses(Rect2(rect.position + Vector2(0.0, back), rect.size)))


func test_real_battle_has_75_roman_and_50_enemy_blocks() -> void:
	assert_eq(_real.get_side_count(0), 50000)
	assert_eq(_real.get_side_count(1), 50000)
	var count: Array[int] = [0, 0]
	for f: int in _real.get_formation_count():
		count[_real.get_formation_side(f)] += 1
		if f > 0:
			assert_gte(_real.get_formation_side(f), _real.get_formation_side(f - 1), "side 0 first")
	assert_eq(count, [75, 50], "(0.4, 0.4, 0.2) and (0.6, 0.4) of 25 blocks a line")


func test_real_battle_a_withdrawal_to_the_rear_crosses_no_sibling() -> void:
	for f: int in _real.get_formation_count():
		var side: int = _real.get_formation_side(f)
		var rect: Rect2 = _real.get_formation_bounds(f)
		var back: float = -150.0 if side == 0 else 150.0
		var moved: Rect2 = Rect2(rect.position + Vector2(0.0, back), rect.size)
		assert_true(_real.get_bounds().encloses(moved), "formation %d stays in the box" % f)
		for g: int in _real.get_formation_count():
			if g != f and _real.get_formation_side(g) == side:
				assert_false(moved.intersects(_real.get_formation_bounds(g)), "%d x %d" % [f, g])


func test_battle_world_front_line_is_the_first_25_blocks_of_each_side() -> void:
	var world: BattleWorld = BattleWorld.build(BenchScenario.SEED, 50000)
	var roman: PackedInt32Array = world.front_line(0)
	var enemy: PackedInt32Array = world.front_line(1)
	assert_eq(roman.size(), 25)
	assert_eq(enemy.size(), 25)
	for k: int in 25:
		assert_eq(roman[k], k, "Roman front line = ids 0..24")
		assert_eq(enemy[k], 75 + k, "enemy front line = ids 75..99")
	for f: int in world.sim.get_formation_count():
		assert_eq(world.sim.get_formation_order(f), BattleSim.ORDER_HOLD)
