extends GutTest
## Couriers against the real BattleSim: an order reaches a formation only after
## distance / 40 km/h plus the handoff, and the courier order ids are the sim's.

const DT: float = BenchScenario.TICK_DT
const GENERAL_AT: Vector2 = Vector2(0.0, -2000.0)
const HANDOFF_S: float = 60.0


## Two small blocks 400 m apart, both told to hold: nothing moves or fights.
func _sim() -> BattleSim:
	var pos: PackedVector2Array = PackedVector2Array()
	var sides: PackedByteArray = PackedByteArray()
	for side: int in 2:
		for row: int in 2:
			for file: int in 10:
				# append() returns true on failure.
				if pos.append(Vector2(file - 4.5, row + side * 400.0)) or sides.append(side):
					push_error("test: cannot build the blocks")
	var sim: BattleSim = BattleSim.new()
	sim.setup_custom(pos, sides, 11)
	sim.set_formation_order(0, BattleSim.ORDER_HOLD)
	sim.set_formation_order(1, BattleSim.ORDER_HOLD)
	return sim


func _service(sim: BattleSim) -> CourierService:
	var source: FormationSource = FormationSource.new()
	source.center = sim.get_formation_center
	source.side = sim.get_formation_side
	source.routed = sim.is_formation_routed
	source.engaged = sim.is_formation_engaged
	source.count = sim.get_formation_count
	source.deliver = sim.set_formation_order
	source.general_position = func() -> Vector2: return GENERAL_AT
	var settings: CourierSettings = CourierSettings.new()
	settings.loss_per_km = 0.0
	settings.loss_near_enemy = 0.0
	settings.loss_melee_crossing = 0.0
	settings.handoff_min_s = HANDOFF_S
	settings.handoff_max_s = HANDOFF_S
	settings.arrival_radius_m = 0.0
	return CourierService.new(source, settings, 5)


func _run(sim: BattleSim, service: CourierService, ticks: int) -> void:
	for _i: int in ticks:
		sim.tick(DT)
		service.step(DT)


func test_order_ids_match_the_sim() -> void:
	assert_eq(OrderInput.ADVANCE, BattleSim.ORDER_ADVANCE)
	assert_eq(OrderInput.HOLD, BattleSim.ORDER_HOLD)
	assert_eq(OrderInput.WITHDRAW, BattleSim.ORDER_WITHDRAW)


func test_order_arrives_only_after_ride_plus_handoff() -> void:
	var sim: BattleSim = _sim()
	var service: CourierService = _service(sim)
	var distance: float = GENERAL_AT.distance_to(sim.get_formation_center(0))
	var speed: float = 40.0 / 3.6
	var expected: int = roundi((distance / speed + HANDOFF_S) / DT)
	assert_true(service.dispatch(BattleSim.ORDER_WITHDRAW, 0, GENERAL_AT))
	_run(sim, service, expected - 2)
	assert_eq(sim.get_formation_order(0), BattleSim.ORDER_HOLD, "not before ride + handoff")
	_run(sim, service, 4)
	assert_eq(sim.get_formation_order(0), BattleSim.ORDER_WITHDRAW, "delivered on time")
	assert_eq(sim.get_formation_order(1), BattleSim.ORDER_HOLD, "the other block untouched")
	assert_gt(expected * DT, 240.0, "a 2 km ride takes minutes, not seconds")
