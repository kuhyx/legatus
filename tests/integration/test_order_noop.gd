extends GutTest
## BattleCommand.deliver against the real BattleSim: the order a block already
## follows changes nothing, takes no officer's roll and does not re-set the
## order (a re-sent withdraw would walk the men a further withdraw_dist back).

const DT: float = BenchScenario.TICK_DT


## Two small blocks 400 m apart, both told to hold: nothing moves or fights.
## The box starts at z -50 (setup_custom spans the origin), so side 0 at z 400
## has room for two withdraw_dist walks before the box edge would clamp them.
func _sim() -> BattleSim:
	var pos: PackedVector2Array = PackedVector2Array()
	var sides: PackedByteArray = PackedByteArray()
	for side: int in 2:
		for row: int in 2:
			for file: int in 10:
				# append() returns true on failure.
				if (
					pos.append(Vector2(file - 4.5, row + 400.0 + side * 400.0))
					or sides.append(side)
				):
					push_error("test: cannot build the blocks")
	var sim: BattleSim = BattleSim.new()
	sim.setup_custom(pos, sides, 11)
	sim.set_formation_order(0, BattleSim.ORDER_HOLD)
	sim.set_formation_order(1, BattleSim.ORDER_HOLD)
	return sim


## A BattleCommand wired to `sim` alone; officers never ignore an order.
func _command(sim: BattleSim) -> BattleCommand:
	var command: BattleCommand = autofree(BattleCommand.new())
	command._sim = sim
	var settings: CourierSettings = CourierSettings.new()
	settings.ignore_min = 0.0
	settings.ignore_max = 0.0
	command.officers = Officers.new(sim.get_formation_count(), settings, 5)
	return command


func _run(sim: BattleSim, ticks: int) -> void:
	for _i: int in ticks:
		sim.tick(DT)


func test_hold_to_a_holding_block_takes_no_roll() -> void:
	var sim: BattleSim = _sim()
	var command: BattleCommand = _command(sim)
	command.deliver(0, OrderInput.HOLD)
	assert_eq(command.officers._rolled[0], 0, "no roll for a no-op")
	assert_eq(sim.get_formation_order(0), BattleSim.ORDER_HOLD)


func test_a_real_order_still_rolls_and_applies() -> void:
	var sim: BattleSim = _sim()
	var command: BattleCommand = _command(sim)
	command.deliver(0, OrderInput.HOLD)
	command.deliver(0, OrderInput.WITHDRAW)
	assert_eq(command.officers._rolled[0], 1, "the no-op used no roll index")
	assert_eq(sim.get_formation_order(0), BattleSim.ORDER_WITHDRAW)


func test_resent_withdraw_does_not_walk_further() -> void:
	var once: BattleSim = _sim()
	var twice: BattleSim = _sim()
	var command_once: BattleCommand = _command(once)
	var command_twice: BattleCommand = _command(twice)
	command_once.deliver(0, OrderInput.WITHDRAW)
	command_twice.deliver(0, OrderInput.WITHDRAW)
	_run(once, 200)
	_run(twice, 200)
	command_twice.deliver(0, OrderInput.WITHDRAW)
	assert_eq(command_twice.officers._rolled[0], 1, "the re-send took no roll")
	# Long enough for withdraw_dist at walking pace and the halt to hold.
	_run(once, 6000)
	_run(twice, 6000)
	assert_eq(once.get_formation_order(0), BattleSim.ORDER_HOLD, "halted")
	assert_eq(twice.get_formation_order(0), BattleSim.ORDER_HOLD, "halted")
	var gap: float = once.get_formation_center(0).distance_to(twice.get_formation_center(0))
	assert_lt(gap, 0.5, "same halt line with or without the re-send")
