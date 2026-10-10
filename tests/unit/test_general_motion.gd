extends GutTest
## HorseMotion: steady-state gait speeds, stamina, turning; General camera.

const DT: float = 1.0 / 60.0
const GENERAL_SCENE: String = "res://scenes/general/general.tscn"


func _run(motion: HorseMotion, seconds: float, turn: float) -> void:
	for _i: int in int(seconds / DT):
		motion.step(DT, turn)


func _motion_at(gait: int) -> HorseMotion:
	var motion: HorseMotion = HorseMotion.new()
	motion.gait = gait
	return motion


func test_steady_state_speed_matches_gait_table() -> void:
	# 20 s: long enough to reach any gait, well inside gallop endurance.
	for gait: int in range(GaitTable.WALK, GaitTable.GAIT_COUNT):
		var motion: HorseMotion = _motion_at(gait)
		_run(motion, 20.0, 0.0)
		var expected: float = GaitTable.speed(gait)
		assert_eq(motion.gait, gait, "gait held: %s" % GaitTable.GAIT_NAMES[gait])
		assert_almost_eq(motion.speed, expected, expected * 0.02, GaitTable.GAIT_NAMES[gait])
		assert_almost_eq(motion.velocity().length(), expected, expected * 0.02)


func test_speed_ramps_not_jumps() -> void:
	var motion: HorseMotion = _motion_at(GaitTable.GALLOP)
	motion.step(DT, 0.0)
	assert_almost_eq(motion.speed, GaitTable.ACCEL_MPS2 * DT, 1e-5)


func test_shifts_are_one_gait_at_a_time() -> void:
	var motion: HorseMotion = HorseMotion.new()
	assert_true(motion.shift_up())
	assert_eq(motion.gait, GaitTable.WALK)
	assert_true(motion.shift_down())
	assert_false(motion.shift_down(), "cannot go below halt")


func test_gallop_exhaustion_forces_downshift() -> void:
	var motion: HorseMotion = _motion_at(GaitTable.GALLOP)
	_run(motion, GaitTable.GALLOP_ENDURANCE_S + 1.0, 0.0)
	assert_eq(motion.gait, GaitTable.CANTER, "blown horse drops to canter")
	assert_true(motion.exhausted)
	assert_eq(motion.forced_downshifts, 1)
	assert_false(motion.shift_up(), "refuses to gallop while blown")


func test_rest_restores_gallop() -> void:
	var motion: HorseMotion = _motion_at(GaitTable.GALLOP)
	_run(motion, GaitTable.GALLOP_ENDURANCE_S + 1.0, 0.0)
	motion.gait = GaitTable.WALK
	_run(motion, GaitTable.GALLOP_RESUME_STAMINA / GaitTable.STAMINA_RATE_PER_S[1] + 1.0, 0.0)
	assert_false(motion.exhausted)
	motion.gait = GaitTable.CANTER
	assert_true(motion.shift_up(), "rested horse gallops again")


func test_turning_is_slower_at_gallop() -> void:
	var walk: HorseMotion = _motion_at(GaitTable.WALK)
	var gallop: HorseMotion = _motion_at(GaitTable.GALLOP)
	_run(walk, 1.0, 1.0)
	_run(gallop, 1.0, 1.0)
	assert_gt(walk.heading, gallop.heading)
	assert_gt(gallop.heading, 0.0, "positive input turns left")


func test_camera_at_eye_height() -> void:
	var scene: PackedScene = load(GENERAL_SCENE)
	var general: General = add_child_autofree(scene.instantiate())
	var eye: float = general.eye_position().y - general.global_position.y
	assert_almost_eq(eye, GaitTable.EYE_HEIGHT_M, 1e-4)
	assert_eq(general.camera().far, VisionTable.MAX_DISTANCE_M * 2.0)


func test_neck_range_is_limited() -> void:
	var scene: PackedScene = load(GENERAL_SCENE)
	var general: General = add_child_autofree(scene.instantiate())
	general.look(10.0, 10.0)
	assert_eq(general.neck_yaw, GaitTable.NECK_YAW_LIMIT_RAD)
	assert_eq(general.neck_pitch, GaitTable.NECK_PITCH_UP_RAD)
	general.look(-20.0, -20.0)
	assert_eq(general.neck_yaw, -GaitTable.NECK_YAW_LIMIT_RAD)
	assert_eq(general.neck_pitch, GaitTable.NECK_PITCH_DOWN_RAD)
