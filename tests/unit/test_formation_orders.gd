extends GutTest
## Formation tables and orders: contiguous ids, HOLD stands, WITHDRAW walks
## back to the own rear, and a routed formation ignores new orders.


## Soldiers for BattleSim.setup_custom, built block by block (side 0 first).
class Layout:
	var pos: PackedVector2Array = PackedVector2Array()
	var sides: PackedByteArray = PackedByteArray()
	var ids: PackedInt32Array = PackedInt32Array()

	## size.x files by size.y ranks, 1 m / 1.1 m apart, front rank on `front`;
	## side 0 faces +z, so its ranks go -z.
	func block(id: int, side: int, front: Vector2, size: Vector2i) -> void:
		for r: int in size.y:
			for f: int in size.x:
				var depth: float = r * 1.1 * (-1.0 if side == 0 else 1.0)
				assert(not pos.append(front + Vector2(f - 0.5 * (size.x - 1), depth)))
				assert(not sides.append(side))
				assert(not ids.append(id))

	func build(seed: int) -> BattleSim:
		var sim: BattleSim = BattleSim.new()
		sim.setup_custom(pos, sides, seed)
		return sim


func _run(sim: BattleSim, ticks: int) -> void:
	for _i: int in ticks:
		sim.tick(0.05)


## Two 20 x 5 blocks 300 m apart: far beyond the 48 m enemy search.
func _far_apart() -> BattleSim:
	var layout: Layout = Layout.new()
	layout.block(0, 0, Vector2(0.0, -150.0), Vector2i(20, 5))
	layout.block(1, 1, Vector2(0.0, 150.0), Vector2i(20, 5))
	return layout.build(4)


func test_setup_lines_formations_are_contiguous_side_0_first() -> void:
	var sim: BattleSim = BattleSim.new()
	sim.setup_lines(3000, 120.0, 4.0, 9)
	assert_eq(sim.get_formation_count(), 4, "120 files = two 60-file blocks per side")
	var sides: Array[int] = []
	var strength: int = 0
	for f: int in sim.get_formation_count():
		sides.append(sim.get_formation_side(f))
		strength += sim.get_formation_strength(f)
		assert_eq(sim.get_formation_order(f), BattleSim.ORDER_ADVANCE)
		assert_eq(sim.get_formation_cohesion(f), 1.0)
		assert_eq(sim.get_formation_break_losses(f), -1.0)
		assert_false(sim.is_formation_routed(f))
	assert_eq(sides, [0, 0, 1, 1])
	assert_eq(strength, 6000)


func test_setup_custom_is_one_formation_per_side() -> void:
	var sim: BattleSim = _far_apart()
	assert_eq(sim.get_formation_count(), 2)
	assert_eq(sim.get_formation_strength(0), 100)
	assert_almost_eq(sim.get_formation_center(0), Vector2(0.0, -152.2), Vector2(0.01, 0.01))


func test_set_formation_ids_regroups() -> void:
	var sim: BattleSim = _far_apart()
	var ids: PackedInt32Array = PackedInt32Array()
	for i: int in sim.get_count():
		assert_false(ids.append(0 if i < 50 else (1 if i < 100 else 2)))
	sim.set_formation_ids(ids)
	assert_eq(sim.get_formation_count(), 3)
	assert_eq(sim.get_formation_strength(0), 50)
	assert_eq(sim.get_formation_side(2), 1)


func test_hold_stands_when_no_enemy_is_near() -> void:
	var sim: BattleSim = _far_apart()
	sim.set_formation_order(0, BattleSim.ORDER_HOLD)
	assert_eq(sim.get_formation_order(0), BattleSim.ORDER_HOLD)
	var held: Vector2 = sim.get_formation_center(0)
	var advancing: Vector2 = sim.get_formation_center(1)
	_run(sim, 200)
	assert_lt(sim.get_formation_center(0).distance_to(held), 0.5, "held its ground")
	assert_lt(sim.get_formation_center(1).y, advancing.y - 5.0, "the other side walked on")


func test_hold_returns_to_the_anchor() -> void:
	var sim: BattleSim = _far_apart()
	_run(sim, 100)  # walks ~7 m forward first
	var anchor: Vector2 = sim.get_formation_center(0)
	sim.set_formation_order(0, BattleSim.ORDER_HOLD)
	_run(sim, 200)
	assert_lt(sim.get_formation_center(0).distance_to(anchor), 0.5)


func test_withdraw_walks_to_the_own_rear() -> void:
	var sim: BattleSim = _far_apart()
	var start: Array[Vector2] = [sim.get_formation_center(0), sim.get_formation_center(1)]
	sim.set_formation_order(0, BattleSim.ORDER_WITHDRAW)
	sim.set_formation_order(1, BattleSim.ORDER_WITHDRAW)
	_run(sim, 200)
	assert_lt(sim.get_formation_center(0).y, start[0].y - 5.0, "side 0's rear is -z")
	assert_gt(sim.get_formation_center(1).y, start[1].y + 5.0, "side 1's rear is +z")
	assert_false(sim.is_formation_routed(0), "not engaged: a withdrawal, not a rout")
	assert_eq(sim.get_formation_cohesion(0), 1.0)


func test_unknown_order_is_rejected() -> void:
	var sim: BattleSim = _far_apart()
	sim.set_formation_order(0, 7)
	assert_eq(sim.get_formation_order(0), BattleSim.ORDER_ADVANCE)
	assert_engine_error("unknown order")
