extends GutTest
## Formations break on losses at or before 10 %, most of the killing comes in
## the pursuit, a rout next door shakes a formation that lost nobody, and
## routers who leave the field are fled: not alive, not drawn.
##
## One battle, run once: side 0 has a shallow block A (50 x 4) in contact
## with a deep block B (50 x 12), so A's losses climb three times faster and
## A breaks first; C (25 x 4) holds 60 m east of A, out of reach. A lone man
## per side holds 150 m behind his line only to stretch the sim's box, so the
## routers have a real run to the edge.

const Orders: GDScript = preload("res://tests/unit/test_formation_orders.gd")
const F_A: int = 0
const F_C: int = 1
const F_B: int = 3
const MAX_TICKS: int = 12000  # 10 game minutes to the first break
const AFTER_TICKS: int = 2400  # 2 more minutes of pursuit

var _sim: BattleSim
var _break_tick: int = -1
var _dead_at_break: int = 0
var _c_min_cohesion: float = 1.0
var _c_losses: float = 0.0
var _order_after_rout: int = -1


## The battle above, its 802 soldiers split into `chunks` worker chunks.
static func battle(chunks: int) -> BattleSim:
	var layout: Orders.Layout = Orders.Layout.new()
	layout.block(F_A, 0, Vector2(0.0, -0.6), Vector2i(50, 4))
	layout.block(F_C, 0, Vector2(60.0, -0.6), Vector2i(25, 4))
	layout.block(2, 0, Vector2(0.0, -150.0), Vector2i(1, 1))
	layout.block(F_B, 1, Vector2(0.0, 0.6), Vector2i(50, 12))
	layout.block(4, 1, Vector2(0.0, 150.0), Vector2i(1, 1))
	var sim: BattleSim = BattleSim.new()
	sim.set_chunk_count(chunks)
	sim.setup_custom(layout.pos, layout.sides, 11)
	sim.set_formation_ids(layout.ids)
	for f: int in [F_C, 2, 4]:
		sim.set_formation_order(f, BattleSim.ORDER_HOLD)
	return sim


func before_all() -> void:
	_sim = battle(128)
	for tick: int in MAX_TICKS:
		_sim.tick(0.05)
		if _sim.is_formation_routed(F_A):
			_break_tick = tick
			break
	_dead_at_break = _dead(0)
	_sim.set_formation_order(F_A, BattleSim.ORDER_HOLD)
	_order_after_rout = _sim.get_formation_order(F_A)
	for _i: int in AFTER_TICKS:
		_sim.tick(0.05)
		if _sim.get_formation_cohesion(F_C) < _c_min_cohesion:
			_c_min_cohesion = _sim.get_formation_cohesion(F_C)
			_c_losses = _sim.get_formation_losses(F_C)
		if _sim.get_formation_strength(F_A) == 0:
			break


func _dead(side: int) -> int:
	return _sim.get_side_count(side) - _sim.get_alive(side) - _sim.get_fled(side)


func test_the_shallow_block_breaks_at_or_before_ten_percent() -> void:
	assert_gt(_break_tick, 0, "A broke within %d ticks" % MAX_TICKS)
	var at: float = _sim.get_formation_break_losses(F_A)
	assert_gt(at, 0.0, "it broke on losses, not on nothing")
	assert_lte(at, 0.10, "Part IIIc: at or before 10 %")
	assert_eq(_sim.get_formation_cohesion(F_A), 0.0)
	assert_eq(_sim.get_formation_break_losses(F_B), -1.0, "the deep block held")


func test_most_of_the_killing_is_in_the_pursuit() -> void:
	var after: int = _dead(0) - _dead_at_break
	gut.p("side 0 killed: %d before A broke, %d after" % [_dead_at_break, after])
	assert_gt(after, _dead_at_break)


func test_a_routing_neighbour_shakes_a_formation_that_lost_nobody() -> void:
	gut.p("C cohesion fell to %.2f at %.1f %% losses" % [_c_min_cohesion, 100.0 * _c_losses])
	assert_lt(_c_min_cohesion, 0.9, "a one-off shock of 0.5 x (1 - d / 150 m)")
	assert_lt(_c_losses, 0.02)


func test_a_routed_formation_ignores_orders() -> void:
	assert_true(_sim.is_formation_routed(F_A))
	assert_eq(_order_after_rout, BattleSim.ORDER_ADVANCE)


func test_routers_leaving_the_field_are_fled_and_not_drawn() -> void:
	var fled: int = _sim.get_fled(0)
	assert_gt(fled, 10, "A's routers reached the edge of the box")
	var living: int = 0
	for f: int in _sim.get_formation_count():
		if _sim.get_formation_side(f) == 0:
			living += _sim.get_formation_strength(f)
	assert_eq(_sim.get_alive(0), living, "get_alive excludes the fled")
	assert_eq(_sim.fill_transforms(0, 1.0).size(), _sim.get_side_count(0) * 16)
	assert_eq(
		_sim.get_drawn_count(0), _sim.get_side_count(0) - fled, "the dead are drawn, the fled not"
	)


func test_routs_pursuit_and_flight_do_not_depend_on_the_chunking() -> void:
	assert_gt(_break_tick, 0)
	var runs: Array[BattleSim] = [battle(128), battle(7)]
	for sim: BattleSim in runs:
		for _i: int in _break_tick + 800:  # the break, the pursuit, the first fled
			sim.tick(0.05)
	var a: BattleSim = runs[0]
	var b: BattleSim = runs[1]
	assert_true(a.is_formation_routed(F_A))
	assert_gt(a.get_fled(0), 0, "the run reached men leaving the field")
	assert_eq(a.get_formation_break_losses(F_A), b.get_formation_break_losses(F_A))
	for side: int in 2:
		assert_eq(a.get_alive(side), b.get_alive(side))
		assert_eq(a.get_fled(side), b.get_fled(side))
	assert_eq(a.get_positions(1.0), b.get_positions(1.0), "bitwise identical positions")
