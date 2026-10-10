extends GutTest
## RiderMotion: the head nod and the rider's bob/sway run on the shared
## stride clock, follow the per-gait tables and stay continuous when the
## gait (and with it the bounces per stride) changes mid-stride.

const DT: float = 1.0 / 60.0
## Largest frame-to-frame change in the per-step camera delta (a second
## difference) a smooth motion produces at 60 Hz; an unblended gait switch
## jumps the bob by ~5 cm in one step.
const MAX_JERK_M: float = 0.012
const MAX_JERK_RAD: float = 0.004


func _settled(gait: int) -> HorseMotion:
	var motion: HorseMotion = HorseMotion.new()
	motion.gait = gait
	motion.speed = GaitTable.speed(gait)
	return motion


## Step both for `seconds`; returns the peak |value| of bob, pitch, roll, nod.
func _run(horse: HorseMotion, rider: RiderMotion, seconds: float) -> Vector4:
	var peak: Vector4 = Vector4.ZERO
	for _i: int in int(seconds / DT):
		horse.step(DT, 0.0)
		rider.step(DT, horse)
		peak = peak.max(
			Vector4(absf(rider.bob_m), absf(rider.pitch), absf(rider.roll), absf(rider.nod))
		)
	return peak


## Step both for `seconds` so the gait blend settles.
func _warm(horse: HorseMotion, rider: RiderMotion, seconds: float) -> void:
	for _i: int in int(seconds / DT):
		horse.step(DT, 0.0)
		rider.step(DT, horse)


func test_halt_is_still() -> void:
	var horse: HorseMotion = HorseMotion.new()
	var rider: RiderMotion = RiderMotion.new()
	var peak: Vector4 = _run(horse, rider, 2.0)
	assert_eq(peak, Vector4.ZERO, "no bob, sway or nod at a halt")
	assert_eq(rider.lean, 0.0)


func test_amplitudes_follow_the_tables() -> void:
	for gait: int in range(GaitTable.WALK, GaitTable.GAIT_COUNT):
		var horse: HorseMotion = _settled(gait)
		var rider: RiderMotion = RiderMotion.new()
		_warm(horse, rider, 5.0)
		var peak: Vector4 = _run(horse, rider, 3.0)
		var gait_name: String = GaitTable.GAIT_NAMES[gait]
		var bob: float = GaitTable.BOB_AMPLITUDE_M[gait]
		assert_almost_eq(peak.x, bob, bob * 0.05, "bob " + gait_name)
		var sway_pitch: float = deg_to_rad(RiderMotionTable.SWAY_PITCH_DEG[gait])
		assert_almost_eq(peak.y, sway_pitch, sway_pitch * 0.05, "pitch " + gait_name)
		var sway_roll: float = deg_to_rad(RiderMotionTable.SWAY_ROLL_DEG[gait])
		assert_almost_eq(peak.z, sway_roll, sway_roll * 0.05, "roll " + gait_name)
		var nod: float = deg_to_rad(RiderMotionTable.NOD_DEG[gait])
		assert_almost_eq(peak.w, nod, nod * 0.05, "nod " + gait_name)


func test_nod_repeats_every_stride() -> void:
	var horse: HorseMotion = _settled(GaitTable.CANTER)
	var rider: RiderMotion = RiderMotion.new()
	_warm(horse, rider, 5.0)
	var strides: int = horse.stride_count
	var phase: float = horse.stride_phase
	var nod: float = rider.nod
	var steps: int = 0
	while horse.stride_count < strides + 1 or horse.stride_phase < phase:
		horse.step(DT, 0.0)
		rider.step(DT, horse)
		steps += 1
	var slope: float = deg_to_rad(RiderMotionTable.NOD_DEG[GaitTable.CANTER]) * TAU * 2.0 * DT
	assert_almost_eq(rider.nod, nod, slope, "same phase, same nod")
	assert_almost_eq(steps, int(1.0 / GaitTable.STRIDE_HZ[GaitTable.CANTER] / DT), 2)


func test_walk_and_trot_differ_in_nod() -> void:
	assert_gt(
		RiderMotionTable.NOD_DEG[GaitTable.WALK], RiderMotionTable.NOD_DEG[GaitTable.TROT] * 3.0
	)
	assert_gt(
		RiderMotionTable.NOD_DEG[GaitTable.CANTER], RiderMotionTable.NOD_DEG[GaitTable.TROT] * 3.0
	)


func test_gait_changes_do_not_jump_the_camera() -> void:
	# [from, to, stride phase at the switch]: trot -> canter at its bob peak
	# is where bounces per stride halve.
	var cases: Array[Vector3] = [
		Vector3(GaitTable.TROT, GaitTable.CANTER, 0.125),
		Vector3(GaitTable.CANTER, GaitTable.TROT, 0.3),
		Vector3(GaitTable.WALK, GaitTable.TROT, 0.6),
		Vector3(GaitTable.CANTER, GaitTable.GALLOP, 0.8),
		Vector3(GaitTable.WALK, GaitTable.HALT, 0.125),
	]
	for c: Vector3 in cases:
		var horse: HorseMotion = _settled(int(c.x))
		var rider: RiderMotion = RiderMotion.new()
		_warm(horse, rider, 4.0)
		while absf(horse.stride_phase - c.z) > 0.02:
			horse.step(DT, 0.0)
			rider.step(DT, horse)
		var label: String = (
			"%s -> %s" % [GaitTable.GAIT_NAMES[int(c.x)], GaitTable.GAIT_NAMES[int(c.y)]]
		)
		_assert_smooth(horse, rider, int(c.y), label)


## Switch to `gait` and check the eye's second difference stays small
## around the switch.
func _assert_smooth(horse: HorseMotion, rider: RiderMotion, gait: int, label: String) -> void:
	var eyes: Array[Transform3D] = []
	for i: int in 8:
		if i == 3:
			horse.gait = gait
		horse.step(DT, 0.0)
		rider.step(DT, horse)
		eyes.append(rider.eye_transform(0.0, 0.0))
	for i: int in range(2, eyes.size()):
		var jerk: Vector3 = eyes[i].origin - 2.0 * eyes[i - 1].origin + eyes[i - 2].origin
		assert_lt(jerk.length(), MAX_JERK_M, "%s: eye position step %d" % [label, i])
		var turn_a: float = eyes[i].basis.get_euler().x - eyes[i - 1].basis.get_euler().x
		var turn_b: float = eyes[i - 1].basis.get_euler().x - eyes[i - 2].basis.get_euler().x
		assert_lt(absf(turn_a - turn_b), MAX_JERK_RAD, "%s: eye pitch step %d" % [label, i])


func test_leans_into_a_turn() -> void:
	var horse: HorseMotion = _settled(GaitTable.GALLOP)
	var rider: RiderMotion = RiderMotion.new()
	for _i: int in 120:
		horse.step(DT, 1.0)
		rider.step(DT, horse)
	assert_gt(rider.lean, deg_to_rad(2.0), "a left turn leans left")
	assert_lt(rider.lean, deg_to_rad(RiderMotionTable.LEAN_MAX_DEG) + 1e-5)
