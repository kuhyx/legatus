class_name RiderMotion
extends RefCounted
## The rider's and the horse's visible motion, from HorseMotion's stride
## clock: bob, torso pitch/roll, horse head nod, lean into turns, tail, mane
## and ears. Pure state + maths (no nodes) so tests can step it.
##
## Each gait's pattern is weighted by `weights` (one per gait, sum 1), which
## glide towards the current gait over RiderMotionTable.BLEND_TIME_S; every
## term also scales by its own gait's speed share. Both keep the camera
## continuous when the gait (and so the bounces per stride) changes.

const G_MPS2: float = 9.81

## Outputs of the last step(). Angles in radians.
var bob_m: float = 0.0
var pitch: float = 0.0
var roll: float = 0.0
## Head down positive.
var nod: float = 0.0
## Into the turn; positive = leaning left (a left turn).
var lean: float = 0.0
var tail_swing: float = 0.0
var tail_lift: float = 0.0
var mane: float = 0.0
var ear_left: float = 0.0
var ear_right: float = 0.0
## Torso twist towards the head turn (radians, + = left); General sets it.
var twist: float = 0.0

var weights: PackedFloat32Array = PackedFloat32Array([1.0, 0.0, 0.0, 0.0, 0.0])
var _elapsed: float = 0.0
var _last_heading: float = 0.0
var _has_heading: bool = false


## Advance by delta seconds after `motion` has stepped.
func step(delta: float, motion: HorseMotion) -> void:
	_elapsed += delta
	_blend(delta, motion.gait)
	var phase: float = motion.stride_phase
	bob_m = 0.0
	pitch = 0.0
	roll = 0.0
	nod = 0.0
	for gait: int in range(GaitTable.WALK, GaitTable.GAIT_COUNT):
		var w: float = weights[gait] * _share(motion.speed, gait)
		if w <= 0.0:
			continue
		var bounce: float = phase * GaitTable.BOUNCES_PER_STRIDE[gait] * TAU
		bob_m += w * GaitTable.BOB_AMPLITUDE_M[gait] * sin(bounce)
		pitch += w * deg_to_rad(RiderMotionTable.SWAY_PITCH_DEG[gait]) * cos(bounce)
		roll += w * deg_to_rad(RiderMotionTable.SWAY_ROLL_DEG[gait]) * sin(phase * TAU)
		var nod_at: float = bounce - RiderMotionTable.NOD_PHASE[gait] * TAU
		nod += w * deg_to_rad(RiderMotionTable.NOD_DEG[gait]) * sin(nod_at)
	_step_lean(delta, motion)
	_step_hair(motion, phase)


## Transform of the horse + rider rig in General space: the lean (about the
## hooves) and the horse's share of the bob. RiderBody uses it as is.
func rig_transform() -> Transform3D:
	var lift: Vector3 = Vector3(0.0, bob_m * RiderMotionTable.BODY_BOB_SHARE, 0.0)
	return Transform3D(Basis(Vector3.FORWARD, -lean), lift)


## Torso rocking about the seat, in rig space (the eye and the chest).
func sway_transform() -> Transform3D:
	var hip: Vector3 = _hip()
	var sway: Basis = Basis.from_euler(Vector3(pitch, 0.0, roll))
	return Transform3D(sway, hip - sway * hip)


## Rocking plus the twist towards the look: the chest and upper arms.
func torso_transform() -> Transform3D:
	var hip: Vector3 = _hip()
	var turn: Basis = Basis(Vector3.UP, twist)
	return sway_transform() * Transform3D(turn, hip - turn * hip)


## The Neck (eye) transform in General space for the given head turn: rig,
## torso rocking, the rider's own share of the bob, then the look, with the
## eyes swinging about the neck as the head turns.
func eye_transform(neck_pitch: float, neck_yaw: float) -> Transform3D:
	var look: Basis = Basis.from_euler(Vector3(neck_pitch, neck_yaw, 0.0))
	var bounce: float = bob_m * (1.0 - RiderMotionTable.BODY_BOB_SHARE)
	var behind: float = RiderMotionTable.SPINE_BEHIND_EYES_M
	var neck: Vector3 = Vector3(0.0, GaitTable.EYE_HEIGHT_M + bounce, behind)
	var eye: Vector3 = neck + Basis(Vector3.UP, neck_yaw) * Vector3(0.0, 0.0, -behind)
	return rig_transform() * sway_transform() * Transform3D(look, eye)


## The seat: torso pivot, under the spine.
static func _hip() -> Vector3:
	var below_eye: float = GaitTable.EYE_HEIGHT_M - RiderMotionTable.TORSO_M
	return Vector3(0.0, below_eye, RiderMotionTable.SPINE_BEHIND_EYES_M)


## Share (0..1) of a gait's speed the horse is moving at.
static func _share(speed: float, gait: int) -> float:
	var full: float = GaitTable.speed(gait)
	return clampf(speed / full, 0.0, 1.0) if full > 0.0 else 0.0


func _blend(delta: float, gait: int) -> void:
	var k: float = 1.0 - exp(-delta / RiderMotionTable.BLEND_TIME_S)
	for g: int in GaitTable.GAIT_COUNT:
		var target: float = 1.0 if g == gait else 0.0
		weights[g] = lerpf(weights[g], target, k)


func _step_lean(delta: float, motion: HorseMotion) -> void:
	var rate: float = 0.0
	if _has_heading and delta > 0.0:
		rate = angle_difference(_last_heading, motion.heading) / delta
	_last_heading = motion.heading
	_has_heading = true
	var bank: float = atan(motion.speed * rate / G_MPS2) * RiderMotionTable.LEAN_SHARE
	var limit: float = deg_to_rad(RiderMotionTable.LEAN_MAX_DEG)
	var target: float = clampf(bank, -limit, limit)
	lean = lerpf(lean, target, 1.0 - exp(-delta / RiderMotionTable.LEAN_TIME_S))


func _step_hair(motion: HorseMotion, phase: float) -> void:
	var pace: float = clampf(motion.speed / GaitTable.speed(GaitTable.GALLOP), 0.0, 1.0)
	tail_swing = (
		deg_to_rad(RiderMotionTable.TAIL_SWING_DEG) * sin(phase * TAU) * minf(pace * 3.0, 1.0)
	)
	tail_lift = deg_to_rad(RiderMotionTable.TAIL_LIFT_DEG) * pace * pace
	mane = deg_to_rad(RiderMotionTable.MANE_SWAY_DEG) * sin(phase * TAU * 2.0 - 1.0) * pace
	# Ears: two slow incommensurate rhythms, each gated so they mostly rest
	# and flick now and then.
	var twitch: float = deg_to_rad(RiderMotionTable.EAR_TWITCH_DEG)
	ear_left = twitch * sin(_elapsed * 7.0) * maxf(sin(_elapsed * 0.53) - 0.6, 0.0) * 2.5
	ear_right = twitch * sin(_elapsed * 6.1) * maxf(sin(_elapsed * 0.41 + 2.0) - 0.6, 0.0) * 2.5
