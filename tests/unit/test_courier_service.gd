extends GutTest
## CourierService against a fake battle: ride time + handoff, chasing a moving
## formation, loss, pool exhaustion, routed targets, determinism.

const DT: float = BenchScenario.TICK_DT
const DISTANCE_M: float = 2000.0
const HANDOFF_S: float = 90.0


## Loss off, fixed handoff, exact arrival: latency = distance / speed + handoff.
func _settings(pool: int) -> CourierSettings:
	var s: CourierSettings = CourierSettings.new()
	s.loss_per_km = 0.0
	s.loss_near_enemy = 0.0
	s.loss_melee_crossing = 0.0
	s.handoff_min_s = HANDOFF_S
	s.handoff_max_s = HANDOFF_S
	s.arrival_radius_m = 0.0
	s.pool_size = pool
	return s


func _world() -> CourierFake:
	var fake: CourierFake = CourierFake.new()
	fake.add(Vector2(DISTANCE_M, 0.0), 0)
	return fake


func _run(service: CourierService, ticks: int) -> void:
	for _i: int in ticks:
		service.step(DT)


func _expected_ticks(settings: CourierSettings) -> int:
	return roundi((DISTANCE_M / settings.speed_mps() + HANDOFF_S) / DT)


func test_order_arrives_after_ride_time_plus_handoff() -> void:
	var fake: CourierFake = _world()
	var settings: CourierSettings = _settings(8)
	var service: CourierService = CourierService.new(fake.source(), settings, 1)
	assert_almost_eq(settings.speed_mps(), 11.111, 0.001, "40 km/h gallop")
	assert_true(service.dispatch(OrderInput.HOLD, 0, Vector2.ZERO))
	var expected: int = _expected_ticks(settings)
	_run(service, expected - 2)
	assert_eq(fake.deliveries.size(), 0, "not delivered 2 ticks early")
	_run(service, 4)
	assert_eq(fake.deliveries, [Vector2i(0, OrderInput.HOLD)] as Array[Vector2i])
	assert_eq(service.couriers[0].state, Courier.State.RETURNING)


func test_courier_chases_a_moving_formation() -> void:
	var fake: CourierFake = _world()
	var settings: CourierSettings = _settings(8)
	var service: CourierService = CourierService.new(fake.source(), settings, 1)
	assert_true(service.dispatch(OrderInput.ADVANCE, 0, Vector2.ZERO))
	var courier: Courier = service.couriers[0]
	var centres: Array[Vector2] = fake.centres
	var ticks: int = 0
	while courier.state == Courier.State.OUTBOUND and ticks < 20000:
		centres[0] += Vector2(0.0, 3.0 * DT)  # 3 m/s march to +Z
		service.step(DT)
		ticks += 1
	assert_eq(courier.state, Courier.State.HANDOFF, "caught the formation")
	assert_gt(centres[0].y, 500.0, "the formation really moved")
	assert_almost_eq(courier.position.distance_to(centres[0]), 0.0, 0.5, "at the new centre")
	assert_gt(ticks, roundi(DISTANCE_M / settings.speed_mps() / DT), "longer than a static ride")
	_run(service, roundi(HANDOFF_S / DT) + 2)
	assert_eq(fake.deliveries.size(), 1, "order delivered after the chase")


func test_certain_loss_never_delivers() -> void:
	var fake: CourierFake = _world()
	var settings: CourierSettings = _settings(8)
	settings.loss_per_km = 1.0
	var service: CourierService = CourierService.new(fake.source(), settings, 1)
	assert_true(service.dispatch(OrderInput.WITHDRAW, 0, Vector2.ZERO))
	_run(service, _expected_ticks(settings) * 2)
	var courier: Courier = service.couriers[0]
	assert_eq(fake.deliveries.size(), 0, "order never arrives")
	assert_eq(courier.state, Courier.State.LOST)
	assert_false(courier.is_riding(), "a lost courier is not drawn")
	assert_between(courier.position.x, 0.0, DISTANCE_M, "lost somewhere on the route")
	assert_eq(service.lost_count, 1)
	assert_eq(service.free_count(), 7, "he never rejoins the pool")


func test_pool_exhaustion_then_return() -> void:
	var fake: CourierFake = _world()
	var service: CourierService = CourierService.new(fake.source(), _settings(2), 1)
	assert_true(service.dispatch(OrderInput.HOLD, 0, Vector2.ZERO))
	assert_true(service.dispatch(OrderInput.HOLD, 0, Vector2.ZERO))
	assert_false(service.dispatch(OrderInput.HOLD, 0, Vector2.ZERO), "pool empty")
	assert_eq(service.free_count(), 0)
	var ticks: int = 0
	while service.free_count() == 0 and ticks < 30000:
		service.step(DT)
		ticks += 1
	assert_eq(service.free_count(), 2, "both riders back with the general")
	var round_trip_s: float = 2.0 * DISTANCE_M / service.settings.speed_mps() + HANDOFF_S
	assert_almost_eq(ticks * DT, round_trip_s, 0.2, "out, handoff, back")
	assert_true(service.dispatch(OrderInput.HOLD, 0, Vector2.ZERO), "dispatch works again")


func test_dispatch_to_missing_formation_fails() -> void:
	var service: CourierService = CourierService.new(_world().source(), _settings(2), 1)
	assert_false(service.dispatch(OrderInput.HOLD, 5, Vector2.ZERO))
	assert_false(service.dispatch(OrderInput.HOLD, -1, Vector2.ZERO))
	assert_eq(service.free_count(), 2, "no courier consumed")


func test_routed_target_gets_no_order() -> void:
	var fake: CourierFake = _world()
	var settings: CourierSettings = _settings(8)
	var service: CourierService = CourierService.new(fake.source(), settings, 1)
	assert_true(service.dispatch(OrderInput.ADVANCE, 0, Vector2.ZERO))
	var routed: Array[bool] = fake.routed
	routed[0] = true
	_run(service, _expected_ticks(settings) + 2)
	assert_eq(fake.deliveries.size(), 0, "a routed unit obeys nobody")
	assert_eq(service.dropped_count, 1)
	assert_eq(service.couriers[0].state, Courier.State.RETURNING, "the rider still rides back")


func test_the_courier_back_acknowledges_the_order() -> void:
	var fake: CourierFake = _world()
	var settings: CourierSettings = _settings(8)
	var service: CourierService = CourierService.new(fake.source(), settings, 1)
	watch_signals(service)
	assert_true(service.dispatch(OrderInput.HOLD, 0, Vector2.ZERO))
	var ticket: int = service.last_ticket
	_run(service, _expected_ticks(settings) + 10)
	assert_signal_not_emitted(service, "order_acknowledged", "not on handover")
	_run(service, roundi(DISTANCE_M / settings.speed_mps() / DT))
	assert_signal_emitted_with_parameters(
		service, "order_acknowledged", [ticket, 0, OrderInput.HOLD]
	)
	assert_signal_not_emitted(service, "order_found_broken")


func test_the_courier_back_reports_a_broken_formation() -> void:
	var fake: CourierFake = _world()
	var settings: CourierSettings = _settings(8)
	var service: CourierService = CourierService.new(fake.source(), settings, 1)
	watch_signals(service)
	assert_true(service.dispatch(OrderInput.ADVANCE, 0, Vector2.ZERO))
	var routed: Array[bool] = fake.routed
	routed[0] = true
	_run(service, _expected_ticks(settings) + roundi(DISTANCE_M / settings.speed_mps() / DT) + 10)
	assert_signal_emitted_with_parameters(
		service, "order_found_broken", [service.last_ticket, 0, OrderInput.ADVANCE]
	)
	assert_signal_not_emitted(service, "order_acknowledged")


func test_same_seed_same_run() -> void:
	var a: CourierService = _random_run(99)
	var b: CourierService = _random_run(99)
	assert_eq(a.history, b.history, "replayable from the seed")
	assert_eq(a.lost_count, b.lost_count)
	assert_between(a.lost_count, 1, 7, "~51% loss over 2 km: the RNG was really used")


func _random_run(rng_seed: int) -> CourierService:
	var fake: CourierFake = _world()
	var settings: CourierSettings = CourierSettings.new()
	settings.loss_per_km = 0.3
	var service: CourierService = CourierService.new(fake.source(), settings, rng_seed)
	for _i: int in settings.pool_size:
		assert_true(service.dispatch(OrderInput.HOLD, 0, Vector2.ZERO))
	_run(service, roundi(600.0 / DT))
	return service
