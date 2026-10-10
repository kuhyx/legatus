extends GutTest
## The stride clock (HorseMotion.stride_phase / stride_count) that the bob,
## the head nod and the hoof sounds share; DemoRide's schedule.

const DT: float = 1.0 / 60.0


func _settled(gait: int) -> HorseMotion:
	var motion: HorseMotion = HorseMotion.new()
	motion.gait = gait
	motion.speed = GaitTable.speed(gait)
	return motion


func test_strides_per_second_match_table() -> void:
	for gait: int in range(GaitTable.WALK, GaitTable.GAIT_COUNT):
		var motion: HorseMotion = _settled(gait)
		for _i: int in 600:
			motion.step(DT, 0.0)
		var strides: float = motion.stride_count + motion.stride_phase
		assert_almost_eq(strides, GaitTable.STRIDE_HZ[gait] * 10.0, 0.05, "gait %d" % gait)


func test_bounce_rate_is_unchanged() -> void:
	# The bob ran at 1.8 / 2.6 / 1.9 / 2.3 Hz before the stride clock existed.
	var bounce_hz: Array[float] = [0.0, 1.8, 2.6, 1.9, 2.3]
	for gait: int in range(GaitTable.WALK, GaitTable.GAIT_COUNT):
		var hz: float = GaitTable.STRIDE_HZ[gait] * GaitTable.BOUNCES_PER_STRIDE[gait]
		assert_almost_eq(hz, bounce_hz[gait], 1e-4)


func test_halt_has_no_stride_and_no_bob() -> void:
	var motion: HorseMotion = HorseMotion.new()
	for _i: int in 120:
		motion.step(DT, 0.0)
	assert_eq(motion.stride_count, 0)
	assert_eq(motion.stride_phase, 0.0)
	assert_eq(motion.bob_offset(), 0.0)


func test_footfalls_are_sorted_phases() -> void:
	assert_eq(GaitTable.FOOTFALLS.size(), GaitTable.GAIT_COUNT)
	assert_eq(GaitTable.footfalls(GaitTable.HALT).size(), 0)
	var beats: Array[int] = [0, 4, 2, 3, 4]
	for gait: int in GaitTable.GAIT_COUNT:
		var falls: PackedFloat32Array = GaitTable.footfalls(gait)
		assert_eq(falls.size(), beats[gait])
		for i: int in falls.size():
			assert_between(falls[i], 0.0, 0.999)
			if i > 0:
				assert_gt(falls[i], falls[i - 1])


func test_demo_ride_schedule() -> void:
	assert_eq(int(DemoRide.row_at(0.0)[1]), GaitTable.HALT)
	assert_eq(int(DemoRide.row_at(15.0)[1]), GaitTable.GALLOP)
	assert_eq(DemoRide.row_at(24.0)[3], 110.0, "looks back over the rump")
	assert_eq(int(DemoRide.row_at(DemoRide.DURATION_S)[1]), GaitTable.HALT)
