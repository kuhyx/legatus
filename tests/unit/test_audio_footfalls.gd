extends GutTest
## Hoof sounds on the stride clock: Footfalls edge detection and RiderAudio's
## own horse, with synthetic streams (independent of the downloaded samples).

const DT: float = 1.0 / 60.0


func _settled(gait: int) -> HorseMotion:
	var motion: HorseMotion = HorseMotion.new()
	motion.gait = gait
	motion.speed = GaitTable.speed(gait)
	return motion


func _rider(motion: HorseMotion, bank: AudioBank) -> RiderAudio:
	var rider: RiderAudio = RiderAudio.new(motion, bank, 3)
	add_child_autofree(rider)
	rider.set_physics_process(false)
	return rider


func test_each_stride_has_exactly_its_footfalls() -> void:
	for gait: int in range(GaitTable.WALK, GaitTable.GAIT_COUNT):
		var motion: HorseMotion = _settled(gait)
		var beats: PackedFloat32Array = GaitTable.footfalls(gait)
		var hits: int = 0
		var strides: int = 0
		for _i: int in 1200:
			var before: float = Footfalls.position(motion)
			var count_before: int = motion.stride_count
			motion.step(DT, 0.0)
			hits += Footfalls.crossed(before, Footfalls.position(motion), beats)
			if motion.stride_count != count_before:
				# The beat at phase 0 lands on the stride boundary itself.
				assert_eq(hits, beats.size(), "gait %d stride %d" % [gait, strides])
				hits = 0
				strides += 1
		assert_gt(strides, 10, "gait %d strode" % gait)


func test_halt_has_no_footfalls() -> void:
	var motion: HorseMotion = HorseMotion.new()
	var hits: int = 0
	for _i: int in 600:
		var before: float = Footfalls.position(motion)
		motion.step(DT, 0.0)
		hits += Footfalls.crossed(before, Footfalls.position(motion), GaitTable.footfalls(0))
	assert_eq(hits, 0)


func test_crossed_is_half_open() -> void:
	var walk: PackedFloat32Array = GaitTable.footfalls(GaitTable.WALK)
	assert_eq(Footfalls.crossed(0.0, 0.0, walk), 0, "no time, no beat")
	assert_eq(Footfalls.crossed(0.0, 0.25, walk), 1, "0.25 is in (0, 0.25]")
	assert_eq(Footfalls.crossed(0.25, 0.5, walk), 1)
	assert_eq(Footfalls.crossed(0.0, 3.0, walk), 12, "three whole strides")
	assert_eq(Footfalls.crossed(1.0, 0.5, walk), 0, "backwards is nothing")


func test_saddle_beats_follow_bounces() -> void:
	for gait: int in GaitTable.GAIT_COUNT:
		var beats: PackedFloat32Array = Footfalls.saddle_beats(gait)
		assert_eq(beats.size(), GaitTable.BOUNCES_PER_STRIDE[gait], "gait %d" % gait)


func test_rider_plays_one_hoof_per_footfall() -> void:
	for gait: int in range(GaitTable.WALK, GaitTable.GAIT_COUNT):
		var motion: HorseMotion = _settled(gait)
		var rider: RiderAudio = _rider(motion, AudioFake.bank())
		rider.step(DT)  # primes the clock at stride position 0
		for _i: int in 600:
			motion.step(DT, 0.0)
			rider.step(DT)
		var expected: int = Footfalls.crossed(
			0.0, Footfalls.position(motion), GaitTable.footfalls(gait)
		)
		assert_eq(rider.hooves.started(), expected, "gait %d" % gait)
		assert_gt(rider.creaks.started(), 0, "gait %d creaks" % gait)


func test_rider_is_silent_at_halt() -> void:
	var motion: HorseMotion = HorseMotion.new()
	var rider: RiderAudio = _rider(motion, AudioFake.bank())
	for _i: int in 600:
		motion.step(DT, 0.0)
		rider.step(DT)
	assert_eq(rider.hooves.started(), 0)
	assert_eq(rider.creaks.started(), 0)
	assert_false(rider.wind.playing, "no wind at a halt")


func test_wind_blows_at_speed() -> void:
	var motion: HorseMotion = _settled(GaitTable.GALLOP)
	var rider: RiderAudio = _rider(motion, AudioFake.bank())
	rider.step(DT)
	assert_true(rider.wind.playing)
	assert_almost_eq(rider.wind.volume_db, AudioTuning.WIND_DB_AT_GALLOP, 0.01)


func test_tired_horse_snorts_more_at_gallop() -> void:
	var fresh: HorseMotion = _settled(GaitTable.GALLOP)
	var tired: HorseMotion = _settled(GaitTable.GALLOP)
	tired.stamina = 0.1
	var fresh_rider: RiderAudio = _rider(fresh, AudioFake.bank())
	var tired_rider: RiderAudio = _rider(tired, AudioFake.bank())
	for _i: int in 1800:  # 30 s; stamina is not stepped, it stays put
		fresh_rider.step(DT)
		tired_rider.step(DT)
	assert_eq(fresh_rider.snorts.started(), 0, "a fresh galloping horse does not blow")
	assert_gt(tired_rider.snorts.started(), 8, "a blown horse blows every few strides")
