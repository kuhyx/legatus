class_name General
extends CharacterBody3D
## The player: a general on horseback, seen from the rider's eyes.
##
## Kinematics live in HorseMotion; this node only turns input into intents,
## moves the body and places the camera. W/S shift gait, A/D turn, the mouse
## turns the rider's head within a realistic neck range, holding the right
## mouse button reins the horse towards where the rider is looking.

signal gait_changed(gait: int)

const MOUSE_SENSITIVITY: float = 0.0025
## Turn input per radian of head-vs-horse angle while reining by gaze.
const REIN_GAIN: float = 1.5
const GRAVITY_MPS2: float = 9.81

var motion: HorseMotion = HorseMotion.new()
## Optional: in woods the horse cannot go faster than a trot.
var woods: Woods = null
var neck_yaw: float = 0.0
var neck_pitch: float = 0.0
## False for timed bench runs: no mouse capture, no keys, no mouse-look, so the
## measured view is fixed (kuhy's first battle bench screenshot was all sky).
var controls_enabled: bool = true:
	set = set_controls_enabled
## Turn input (-1..1, + = left) used while controls are off, so a scripted
## ride (DemoRide) can steer without faking key events.
var scripted_turn: float = 0.0

@onready var _neck: Node3D = $Neck
@onready var _camera: Camera3D = $Neck/Camera


func _ready() -> void:
	GeneralInput.ensure_actions()
	_neck.position = Vector3(0.0, GaitTable.EYE_HEIGHT_M, 0.0)
	_camera.position = Vector3.ZERO
	_camera.far = VisionTable.MAX_DISTANCE_M * 2.0
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## World position of the rider's eyes, for Visibility queries.
func eye_position() -> Vector3:
	return _camera.global_position


func camera() -> Camera3D:
	return _camera


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event.is_action_pressed(GeneralInput.GAIT_UP) and motion.shift_up():
		gait_changed.emit(motion.gait)
	elif event.is_action_pressed(GeneralInput.GAIT_DOWN) and motion.shift_down():
		gait_changed.emit(motion.gait)
	elif event.is_action_pressed(GeneralInput.RELEASE_MOUSE):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel: Vector2 = (event as InputEventMouseMotion).relative
		look(-rel.x * MOUSE_SENSITIVITY, -rel.y * MOUSE_SENSITIVITY)


## Turn the head by the given yaw/pitch deltas, clamped to the neck range.
func look(yaw_delta: float, pitch_delta: float) -> void:
	neck_yaw = clampf(
		neck_yaw + yaw_delta, -GaitTable.NECK_YAW_LIMIT_RAD, GaitTable.NECK_YAW_LIMIT_RAD
	)
	neck_pitch = clampf(
		neck_pitch + pitch_delta, GaitTable.NECK_PITCH_DOWN_RAD, GaitTable.NECK_PITCH_UP_RAD
	)


func _physics_process(delta: float) -> void:
	var turn: float = scripted_turn
	var reining: bool = false
	if controls_enabled:
		turn = Input.get_axis(GeneralInput.TURN_RIGHT, GeneralInput.TURN_LEFT)
		reining = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if reining:
		turn = clampf(turn + neck_yaw * REIN_GAIN, -1.0, 1.0)
	if woods != null and motion.gait > GaitTable.TROT and woods.contains(position.x, position.z):
		motion.gait = GaitTable.TROT
		gait_changed.emit(motion.gait)
	var gait_before: int = motion.gait
	var heading_before: float = motion.heading
	motion.step(delta, turn)
	if motion.gait != gait_before:
		gait_changed.emit(motion.gait)
	if reining:
		# Keep the gaze fixed in the world while the horse swings under it.
		look(-angle_difference(heading_before, motion.heading), 0.0)
	_move(delta)
	rotation.y = motion.heading
	_camera.position.y = motion.bob_offset()
	_neck.rotation = Vector3(neck_pitch, neck_yaw, 0.0)


func _move(delta: float) -> void:
	var ground_velocity: Vector3 = motion.velocity()
	velocity.x = ground_velocity.x
	velocity.z = ground_velocity.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY_MPS2 * delta
	# A "wall" here is a slope too steep to climb: the horse balks.
	if move_and_slide() and is_on_wall():
		motion.speed = minf(motion.speed, GaitTable.speed(GaitTable.WALK))
