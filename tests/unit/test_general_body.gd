extends GutTest
## RiderBody: the general's visible horse and kit hang off General (not the
## Neck), are meshes only (no collision, no shadows), and the eye contract
## for sight lines holds (eye at EYE_HEIGHT_M at rest).

const DT: float = 1.0 / 60.0
const GENERAL_SCENE: String = "res://scenes/general/general.tscn"


func _general() -> General:
	var scene: PackedScene = load(GENERAL_SCENE)
	return add_child_autofree(scene.instantiate())


func test_body_is_under_general_not_neck() -> void:
	var general: General = _general()
	var body: RiderBody = general.body()
	assert_not_null(body)
	assert_eq(body.get_parent(), general, "the horse does not turn with the head")
	var neck: Node = general.get_node("Neck")
	assert_eq(neck.find_children("*", "MeshInstance3D", true, false).size(), 0)
	assert_gt(body.meshes().size(), 10, "horse, head, ears, tail, hands, reins...")


func test_body_has_no_collision_and_no_shadows() -> void:
	var body: RiderBody = _general().body()
	assert_eq(body.find_children("*", "CollisionObject3D", true, false).size(), 0)
	assert_eq(body.find_children("*", "CollisionShape3D", true, false).size(), 0)
	for mesh: MeshInstance3D in body.meshes():
		assert_eq(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, mesh.name)
		assert_gt(mesh.mesh.get_surface_count(), 0, "%s has geometry" % mesh.name)


func test_eye_height_holds_at_halt_after_steps() -> void:
	var general: General = _general()
	general.controls_enabled = false
	for _i: int in 30:
		general._physics_process(DT)
	var eye: float = general.eye_position().y - general.global_position.y
	assert_almost_eq(eye, GaitTable.EYE_HEIGHT_M, 1e-4)
	assert_almost_eq(general.camera().near, General.CAMERA_NEAR_M, 1e-6)


func test_head_turn_swings_eye_about_neck_only() -> void:
	var motion: RiderMotion = RiderMotion.new()
	var ahead: Vector3 = motion.eye_transform(0.0, 0.0).origin
	assert_almost_eq(ahead.distance_to(Vector3(0.0, GaitTable.EYE_HEIGHT_M, 0.0)), 0.0, 1e-5)
	var back: Vector3 = motion.eye_transform(0.0, GaitTable.NECK_YAW_LIMIT_RAD).origin
	assert_almost_eq(back.y, GaitTable.EYE_HEIGHT_M, 1e-5, "turning the head keeps eye height")
	assert_lt(back.x, -0.05, "looking left moves the eyes left")
	assert_lt(ahead.distance_to(back), 2.0 * RiderMotionTable.SPINE_BEHIND_EYES_M + 1e-4)


func test_hands_and_reins_follow_the_nod() -> void:
	var body: RiderBody = RiderBody.new()
	var motion: RiderMotion = RiderMotion.new()
	body.pose(motion)
	var hand: Vector3 = body._hands[0].position
	var rein_end: Vector3 = body._reins[1].transform * Vector3.FORWARD
	motion.nod = deg_to_rad(6.0)
	body.pose(motion)
	assert_lt(body._hands[0].position.z, hand.z - 0.02, "head down pulls the hands forward")
	var bit: Vector3 = body._reins[1].transform * Vector3.FORWARD
	assert_lt(bit.distance_to(body._on_head(HorseShape.BIT)), 1e-4, "the rein ends at the bit")
	assert_gt(rein_end.distance_to(bit), 0.02, "the bit moved with the head")
	body.free()
