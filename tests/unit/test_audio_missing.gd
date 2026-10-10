extends GutTest
## Sound samples are not in git: with none installed (CI, offline) nothing
## crashes and nothing plays.

const NO_DIR: String = "res://tests/no_such_audio_dir/"


func _empty_bank() -> AudioBank:
	return AudioBank.load_dir(NO_DIR)


func test_missing_dir_gives_an_empty_bank() -> void:
	var bank: AudioBank = _empty_bank()
	assert_true(bank.hooves.is_empty())
	assert_true(bank.snorts.is_empty())
	assert_true(bank.creaks.is_empty())
	assert_true(bank.clashes.is_empty())
	assert_null(bank.wind)
	assert_null(bank.crowd)
	assert_null(AudioBank.load_stream(NO_DIR.path_join("hoof_1.wav"), false))


func test_rider_without_samples_plays_nothing() -> void:
	var motion: HorseMotion = HorseMotion.new()
	motion.gait = GaitTable.GALLOP
	motion.stamina = 0.05
	var rider: RiderAudio = RiderAudio.new(motion, _empty_bank())
	add_child_autofree(rider)
	rider.set_physics_process(false)
	for _i: int in 1200:
		motion.step(1.0 / 60.0, 0.0)
		rider.step(1.0 / 60.0)
	assert_eq(rider.hooves.started() + rider.creaks.started() + rider.snorts.started(), 0)
	assert_eq(rider.hooves.playing_count() + rider.snorts.playing_count(), 0)
	assert_false(rider.wind.playing)


func test_din_and_couriers_without_samples_build_nothing() -> void:
	var fake: CourierFake = CourierFake.new()
	fake.add(Vector2(10.0, 0.0), 0)
	fake.engaged[0] = true
	var listener: Node3D = Node3D.new()
	add_child_autofree(listener)
	var din: BattleAudio = BattleAudio.new()
	din.setup(fake.source(), func(_f: int) -> int: return 100, _flat, listener)
	din.build(_empty_bank(), 1)
	add_child_autofree(din)
	din.update()
	assert_eq(din.emitters.size(), 0)
	var courier: Courier = Courier.new()
	courier.state = Courier.State.OUTBOUND
	var couriers: CourierAudio = CourierAudio.new()
	couriers.setup([courier] as Array[Courier], _flat, listener, _empty_bank())
	add_child_autofree(couriers)
	couriers.step(1.0)
	assert_eq(couriers.started(), 0)


func test_mute_toggles_master() -> void:
	var was: bool = AudioServer.is_bus_mute(RiderAudio.BUS_MASTER)
	assert_eq(RiderAudio.toggle_mute(), not was)
	assert_eq(AudioServer.is_bus_mute(RiderAudio.BUS_MASTER), not was)
	assert_eq(RiderAudio.toggle_mute(), was)
	GeneralInput.ensure_actions()
	assert_true(InputMap.has_action(GeneralInput.MUTE))


func _flat(_x: float, _z: float) -> float:
	return 0.0
