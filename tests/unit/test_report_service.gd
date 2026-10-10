extends GutTest
## ReportService against a fake battle: a level change sends a rider from the
## block's rear, he gallops to the general, one report per 60 s, routed and
## enemy blocks are silent, loss, the rider cap queue, bias, determinism.

const DT: float = BenchScenario.TICK_DT
## Block centre 1,060 m out: its rear (60 m standoff) is 1,000 m from the general.
const OUT_M: float = 1060.0


func _settings() -> CourierSettings:
	var s: CourierSettings = CourierSettings.new()
	s.loss_per_km = 0.0
	s.loss_near_enemy = 0.0
	s.loss_melee_crossing = 0.0
	s.arrival_radius_m = 0.0
	return s


func _world(blocks: int) -> CourierFake:
	var fake: CourierFake = CourierFake.new()
	for i: int in blocks:
		fake.add(Vector2(i * 10.0, OUT_M), 0)
	return fake


func _run(service: ReportService, ticks: int) -> void:
	for _i: int in ticks:
		service.step(DT)


func _riding(service: ReportService) -> Array[ReportRider]:
	var out: Array[ReportRider] = []
	for courier: Courier in service.riders:
		if courier.is_riding():
			out.append(courier as ReportRider)
	return out


func test_holding_blocks_send_nothing() -> void:
	var fake: CourierFake = _world(3)
	var service: ReportService = ReportService.new(fake.source(), _settings(), 1)
	_run(service, 200)
	assert_eq(_riding(service).size(), 0)


func test_engaged_report_leaves_the_rear_and_reaches_the_general() -> void:
	var fake: CourierFake = _world(1)
	var settings: CourierSettings = _settings()
	var service: ReportService = ReportService.new(fake.source(), settings, 1)
	fake.engaged[0] = true
	_run(service, 1)
	var riders: Array[ReportRider] = _riding(service)
	assert_eq(riders.size(), 1)
	assert_almost_eq(riders[0].position, Vector2(0.0, OUT_M - 60.0), Vector2.ONE * 0.01, "rear")
	assert_eq(riders[0].level, ReportLevel.ENGAGED)
	var ride_ticks: int = ceili((OUT_M - 60.0) / settings.speed_mps() / DT)
	_run(service, ride_ticks - 1)
	assert_eq(service.arrived.size(), 0, "not before the ride time")
	_run(service, 2)
	assert_eq(service.arrived.size(), 1)
	assert_eq(int(service.arrived[0].y), ReportLevel.ENGAGED)
	assert_almost_eq(service.arrived[0].z, DT, 1e-4, "seen when sent")
	assert_eq(service.lines(), PackedStringArray(["08:01 block 0: engaged (seen 08:00)"]))


func test_one_report_per_gap_with_the_level_at_its_end() -> void:
	var fake: CourierFake = _world(1)
	var service: ReportService = ReportService.new(fake.source(), _settings(), 1)
	fake.engaged[0] = true
	_run(service, 1)
	fake.cohesions[0] = 0.1  # breaking: never overstated
	_run(service, roundi(30.0 / DT))
	assert_eq(service.arrived.size(), 0)
	_run(service, roundi(31.0 / DT))
	var last: ReportRider = null
	for rider: ReportRider in _riding(service):
		last = rider
	assert_not_null(last, "the change inside the gap went out at its end")
	assert_eq(last.level, ReportLevel.BREAKING)
	assert_almost_eq(last.seen_s, ReportService.MIN_GAP_S + DT, 0.1)


func test_a_change_undone_inside_the_gap_is_not_sent() -> void:
	var fake: CourierFake = _world(1)
	var service: ReportService = ReportService.new(fake.source(), _settings(), 1)
	fake.engaged[0] = true
	_run(service, 1)
	fake.cohesions[0] = 0.1
	_run(service, roundi(20.0 / DT))
	fake.cohesions[0] = 1.0
	# Past the gap's end and the first report's arrival (~90 s), before it
	# leaves the list (90 s after arrival).
	_run(service, roundi(140.0 / DT))
	assert_eq(service.arrived.size(), 1, "only the first report")
	assert_eq(_riding(service).size(), 0)


func test_routed_and_enemy_blocks_are_silent() -> void:
	var fake: CourierFake = _world(2)
	fake.add(Vector2(0.0, 1500.0), 1)
	var service: ReportService = ReportService.new(fake.source(), _settings(), 1)
	fake.routed[0] = true
	fake.cohesions[0] = 0.0
	fake.engaged[2] = true
	_run(service, 100)
	assert_eq(_riding(service).size(), 0)


func test_a_lost_rider_never_arrives() -> void:
	var fake: CourierFake = _world(1)
	var settings: CourierSettings = _settings()
	settings.loss_per_km = 1.0
	var service: ReportService = ReportService.new(fake.source(), settings, 1)
	fake.engaged[0] = true
	_run(service, roundi(200.0 / DT))
	assert_eq(service.arrived.size(), 0)
	assert_eq(service.riders[0].state, Courier.State.LOST)


func test_past_the_rider_cap_reports_wait_and_are_not_dropped() -> void:
	var fake: CourierFake = _world(ReportService.RIDERS + 1)
	var service: ReportService = ReportService.new(fake.source(), _settings(), 1)
	for f: int in ReportService.RIDERS + 1:
		fake.engaged[f] = true
	_run(service, 1)
	assert_eq(_riding(service).size(), ReportService.RIDERS)
	while service.arrived.is_empty():
		service.step(DT)
	service.step(DT)
	var out: Array[int] = []
	for rider: ReportRider in _riding(service):
		out.append(rider.formation)
	assert_has(out, ReportService.RIDERS, "the waiting report went out")
	assert_eq(out.size() + service.arrived.size(), ReportService.RIDERS + 1, "none dropped")


func test_shaken_officers_sometimes_overstate() -> void:
	var fake: CourierFake = _world(ReportService.RIDERS)
	var service: ReportService = ReportService.new(fake.source(), _settings(), 4)
	for f: int in ReportService.RIDERS:
		fake.engaged[f] = true
		fake.cohesions[f] = 0.2  # hard pressed, overstated with chance 0.6
	_run(service, 1)
	var said: Dictionary[int, int] = {}
	for rider: ReportRider in _riding(service):
		said[rider.level] = said.get(rider.level, 0) + 1
	assert_eq(said.keys().size(), 2, "both hard pressed and breaking: %s" % said)
	assert_true(said.has(ReportLevel.HARD_PRESSED) and said.has(ReportLevel.BREAKING))


func test_same_seed_same_reports() -> void:
	var runs: Array[Array] = []
	for _r: int in 2:
		var fake: CourierFake = _world(6)
		var settings: CourierSettings = _settings()
		settings.loss_per_km = 0.3
		var service: ReportService = ReportService.new(fake.source(), settings, 9)
		for f: int in 6:
			fake.engaged[f] = true
			fake.cohesions[f] = 0.3
		_run(service, roundi(300.0 / DT))
		runs.append(service.arrived.duplicate())
	assert_eq(runs[0], runs[1])
