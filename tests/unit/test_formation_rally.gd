extends GutTest
## A routed formation rallies once: no unrouted enemy centroid within 60 m
## for 20 s and an unrouted friend within 150 m. Pursued, it never does.

const Orders: GDScript = preload("res://tests/unit/test_formation_orders.gd")
const F_A: int = 0  # the block forced to rout
const F_C: int = 1  # friendly block to rally on
const F_B: int = 3  # A's enemy
const RALLY_TICKS: int = 1200  # 60 s: the rally comes ~40 s after the rout


## A (20 x 5) and B (20 x 5) in contact on HOLD, C 200 m behind A. Lone men
## stretch the sim box so the routers have room to run before leaving it.
func _battle(b_order: int) -> BattleSim:
	var layout: Orders.Layout = Orders.Layout.new()
	layout.block(F_A, 0, Vector2(0.0, -0.6), Vector2i(20, 5))
	layout.block(F_C, 0, Vector2(0.0, -200.0), Vector2i(20, 5))
	layout.block(2, 0, Vector2(0.0, -500.0), Vector2i(1, 1))
	layout.block(F_B, 1, Vector2(0.0, 0.6), Vector2i(20, 5))
	layout.block(4, 1, Vector2(0.0, 500.0), Vector2i(1, 1))
	var sim: BattleSim = layout.build(11)
	sim.set_formation_ids(layout.ids)
	sim.set_tuning({"withdraw_shock": 1.5})
	for f: int in [F_A, F_C, 2, 4]:
		sim.set_formation_order(f, BattleSim.ORDER_HOLD)
	sim.set_formation_order(F_B, b_order)
	return sim


## Tick until A is in contact, then order it back: the shock breaks it at once.
func _rout_a(sim: BattleSim) -> void:
	for _i: int in 400:
		sim.tick(0.05)
		if sim.is_formation_engaged(F_A):
			break
	assert_true(sim.is_formation_engaged(F_A), "A met B")
	sim.set_formation_order(F_A, BattleSim.ORDER_WITHDRAW)
	sim.tick(0.05)
	assert_true(sim.is_formation_routed(F_A), "withdrawing out of contact broke A")
	assert_false(sim.is_formation_rallied(F_A))


## Ticks after the rout until A rallies, or -1.
func _ticks_to_rally(sim: BattleSim) -> int:
	for tick: int in RALLY_TICKS:
		sim.tick(0.05)
		if sim.is_formation_rallied(F_A):
			return tick
	return -1


func test_unpursued_routers_rally_on_a_friend() -> void:
	var sim: BattleSim = _battle(BattleSim.ORDER_HOLD)
	_rout_a(sim)
	var at: int = _ticks_to_rally(sim)
	assert_gt(at, 20 * 20 - 1, "not before 20 s unpursued")
	assert_lt(at, RALLY_TICKS, "within 60 s")
	assert_false(sim.is_formation_routed(F_A))
	assert_eq(sim.get_formation_order(F_A), BattleSim.ORDER_HOLD)
	assert_almost_eq(sim.get_formation_cohesion(F_A), 0.3, 0.01, "rally_cohesion")
	assert_gt(sim.get_formation_strength(F_A), 0, "some came back")
	sim.tick(0.05)
	assert_almost_eq(sim.get_formation_cohesion(F_A), 0.3, 0.05, "one tick later")
	assert_false(sim.is_formation_routed(F_A))
	# Re-formed and out of contact: 10 s later still a formation, not a mob.
	var spot: Vector2 = sim.get_formation_center(F_A)
	for _i: int in 200:
		sim.tick(0.05)
	assert_false(sim.is_formation_routed(F_A), "still unrouted 10 s on")
	assert_true(sim.is_formation_rallied(F_A))
	assert_eq(sim.get_formation_order(F_A), BattleSim.ORDER_HOLD)
	assert_lt(sim.get_formation_center(F_A).distance_to(spot), 5.0, "stopped running")


func test_a_pursued_rout_never_rallies() -> void:
	var sim: BattleSim = _battle(BattleSim.ORDER_ADVANCE)  # pursues at 3.6 > 3.0 m/s
	_rout_a(sim)
	assert_eq(_ticks_to_rally(sim), -1, "B stays on A's heels: no rally")
	assert_false(sim.is_formation_rallied(F_A))


func test_a_rallied_formation_that_breaks_again_is_final() -> void:
	var sim: BattleSim = _battle(BattleSim.ORDER_HOLD)
	_rout_a(sim)
	assert_gt(_ticks_to_rally(sim), 0)
	# B walks up and the exhausted, half-cohesive A breaks a second time.
	sim.set_formation_order(F_B, BattleSim.ORDER_ADVANCE)
	var routed_again: bool = false
	for _i: int in 6000:
		sim.tick(0.05)
		if sim.is_formation_routed(F_A):
			routed_again = true
			break
	assert_true(routed_again, "A broke a second time")
	for _i: int in RALLY_TICKS:
		sim.tick(0.05)
		assert_true(sim.is_formation_routed(F_A) or sim.get_formation_strength(F_A) == 0)
		assert_true(sim.is_formation_rallied(F_A), "rallied stays set: the second rout is final")


func test_two_identical_runs_rally_identically() -> void:
	var runs: Array[BattleSim] = [_battle(BattleSim.ORDER_HOLD), _battle(BattleSim.ORDER_HOLD)]
	var ats: Array[int] = []
	for sim: BattleSim in runs:
		_rout_a(sim)
		ats.append(_ticks_to_rally(sim))
	assert_gt(ats[0], 0)
	assert_eq(ats[0], ats[1], "same rally tick")
	assert_eq(runs[0].get_positions(1.0), runs[1].get_positions(1.0), "bitwise identical")
	assert_eq(runs[0].get_formation_cohesion(F_A), runs[1].get_formation_cohesion(F_A))
