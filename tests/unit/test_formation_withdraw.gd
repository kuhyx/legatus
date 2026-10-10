extends GutTest
## An ordered withdrawal walks each man 150 m to his own rear, then the
## formation holds there; own formations pass through each other meanwhile.

const Orders: GDScript = preload("res://tests/unit/test_formation_orders.gd")
const F_W: int = 0  # withdraws
const F_R: int = 1  # friend standing in W's way, 40 m behind it
const WALK_TICKS: int = 4000  # 200 s: the walk takes ~110 s


## W (20 x 5) at the front, R (20 x 5) directly behind it; a lone man far
## behind stretches the sim box (soldiers' extent + 50 m) past W's goal.
func _battle() -> BattleSim:
	var layout: Orders.Layout = Orders.Layout.new()
	layout.block(F_W, 0, Vector2(0.0, -100.0), Vector2i(20, 5))
	layout.block(F_R, 0, Vector2(0.0, -140.0), Vector2i(20, 5))
	layout.block(2, 0, Vector2(0.0, -400.0), Vector2i(1, 1))
	layout.block(3, 1, Vector2(0.0, 400.0), Vector2i(1, 1))
	var sim: BattleSim = layout.build(3)
	sim.set_formation_ids(layout.ids)
	for f: int in [F_R, 2, 3]:
		sim.set_formation_order(f, BattleSim.ORDER_HOLD)
	return sim


func test_withdrawal_halts_150_m_back_and_stays_put() -> void:
	var sim: BattleSim = _battle()
	var start: Vector2 = sim.get_formation_center(F_W)
	var friend: Vector2 = sim.get_formation_center(F_R)
	sim.set_formation_order(F_W, BattleSim.ORDER_WITHDRAW)
	var friend_drift: float = 0.0
	var halted: int = -1
	for tick: int in WALK_TICKS:
		sim.tick(0.05)
		friend_drift = maxf(friend_drift, sim.get_formation_center(F_R).distance_to(friend))
		if sim.get_formation_order(F_W) == BattleSim.ORDER_HOLD:
			halted = tick
			break
	assert_gt(halted, 0, "the withdrawal ended in HOLD within %d ticks" % WALK_TICKS)
	var halt: Vector2 = sim.get_formation_center(F_W)
	assert_almost_eq(start.y - halt.y, 150.0, 3.0, "walked ~withdraw_dist to its own rear (-z)")
	assert_almost_eq(halt.x, start.x, 1.0, "straight back")
	assert_false(sim.is_formation_routed(F_W), "a withdrawal, not a rout")
	assert_eq(sim.get_formation_cohesion(F_W), 1.0)
	# The flip comes within 2 m of the goal; the men still short of their
	# anchors close that last bit, then the formation stands still.
	for _i: int in 100:
		sim.tick(0.05)
	var settled: Vector2 = sim.get_formation_center(F_W)
	assert_lt(settled.distance_to(halt), 2.5, "the last metres to the anchors")
	assert_almost_eq(start.y - settled.y, 150.0, 1.5, "settled on the goal")
	for _i: int in 300:  # a further 15 s
		sim.tick(0.05)
		assert_eq(sim.get_formation_order(F_W), BattleSim.ORDER_HOLD)
	assert_lt(sim.get_formation_center(F_W).distance_to(settled), 0.3, "then stays put")
	assert_lt(friend_drift, 1.0, "the friend W walked through barely moved")
	assert_lt(sim.get_formation_center(F_R).distance_to(friend), 1.0)
	assert_eq(sim.get_formation_strength(F_W), 100, "nobody fought or fled")


func test_withdrawal_of_side_1_walks_towards_plus_z() -> void:
	var layout: Orders.Layout = Orders.Layout.new()
	layout.block(0, 0, Vector2(0.0, -400.0), Vector2i(1, 1))
	layout.block(1, 1, Vector2(0.0, 100.0), Vector2i(20, 5))
	layout.block(2, 1, Vector2(0.0, 400.0), Vector2i(1, 1))
	var sim: BattleSim = layout.build(3)
	sim.set_formation_ids(layout.ids)
	var start: Vector2 = sim.get_formation_center(1)
	sim.set_formation_order(1, BattleSim.ORDER_WITHDRAW)
	for _i: int in WALK_TICKS:
		sim.tick(0.05)
		if sim.get_formation_order(1) == BattleSim.ORDER_HOLD:
			break
	assert_eq(sim.get_formation_order(1), BattleSim.ORDER_HOLD)
	assert_almost_eq(sim.get_formation_center(1).y - start.y, 150.0, 3.0)


func test_a_withdrawal_near_the_box_edge_is_clamped_into_the_box() -> void:
	var layout: Orders.Layout = Orders.Layout.new()
	layout.block(0, 0, Vector2(0.0, -100.0), Vector2i(20, 5))  # box ends ~-154 m
	layout.block(1, 1, Vector2(0.0, 300.0), Vector2i(1, 1))
	var sim: BattleSim = layout.build(3)
	sim.set_formation_order(0, BattleSim.ORDER_WITHDRAW)
	for _i: int in WALK_TICKS:
		sim.tick(0.05)
	assert_eq(sim.get_formation_order(0), BattleSim.ORDER_HOLD, "halts at the clamped goal")
	assert_eq(sim.get_formation_strength(0), 100, "no one ran off the field")
	assert_true(sim.get_bounds().encloses(sim.get_formation_bounds(0)))
