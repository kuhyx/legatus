class_name HorseMotion
extends RefCounted
## Pure horse kinematics: gait, speed, heading, stamina, stride clock.
##
## No input, no nodes: General feeds it intents and reads the result, so tests
## can drive it with plain step() calls.

## Gait the rider asked for (GaitTable.HALT..GALLOP).
var gait: int = GaitTable.HALT
## Current ground speed, m/s. Ramps towards the gait speed at ACCEL/DECEL.
var speed: float = 0.0
## Yaw in radians, Godot convention: 0 faces -Z, positive turns left.
var heading: float = 0.0
var stamina: float = GaitTable.STAMINA_MAX
## Set when the gallop ran stamina dry; cleared at GALLOP_RESUME_STAMINA.
var exhausted: bool = false
## Bumped every time exhaustion forced a down-shift (for UI / tests).
var forced_downshifts: int = 0
## Fraction (0..1) of the current stride; see GaitTable.STRIDE_HZ.
var stride_phase: float = 0.0
## Whole strides completed since start (never wraps; for footfall edges).
var stride_count: int = 0


## Shift one gait up. Returns false if refused (top gait, or tired horse).
func shift_up() -> bool:
	if gait >= GaitTable.GALLOP:
		return false
	if gait + 1 == GaitTable.GALLOP and exhausted:
		return false
	gait += 1
	return true


## Shift one gait down. Returns false if already halted.
func shift_down() -> bool:
	if gait <= GaitTable.HALT:
		return false
	gait -= 1
	return true


## Advance by delta seconds. turn_input is -1..1, positive = turn left.
func step(delta: float, turn_input: float) -> void:
	var target: float = GaitTable.speed(gait)
	var rate: float = GaitTable.ACCEL_MPS2 if target > speed else GaitTable.DECEL_MPS2
	speed = move_toward(speed, target, rate * delta)
	heading = wrapf(
		heading + clampf(turn_input, -1.0, 1.0) * GaitTable.turn_rate(gait) * delta, -PI, PI
	)
	_update_stamina(delta)
	stride_phase += GaitTable.STRIDE_HZ[gait] * delta * speed_share()
	if stride_phase >= 1.0:
		stride_count += int(stride_phase)
		stride_phase = fmod(stride_phase, 1.0)


## Horizontal velocity in world space for the current heading and speed.
func velocity() -> Vector3:
	return forward() * speed


## Unit forward vector on the ground plane.
func forward() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


## Vertical camera offset from the gait's stride, scaled by how close the
## horse is to that gait's speed so a halt has no bob at all.
func bob_offset() -> float:
	var bounce: float = stride_phase * GaitTable.BOUNCES_PER_STRIDE[gait] * TAU
	return sin(bounce) * GaitTable.BOB_AMPLITUDE_M[gait] * speed_share()


## Speed as a share (0..1) of the current gait's speed: a horse still ramping
## up strides and bobs less, a halt not at all.
func speed_share() -> float:
	var full: float = GaitTable.speed(gait)
	if full <= 0.0:
		return 0.0
	return clampf(speed / full, 0.0, 1.0)


func _update_stamina(delta: float) -> void:
	if gait == GaitTable.GALLOP:
		stamina = maxf(stamina - GaitTable.gallop_drain_per_s() * delta, 0.0)
		if stamina <= 0.0:
			exhausted = true
			gait = GaitTable.CANTER
			forced_downshifts += 1
		return
	stamina = minf(stamina + GaitTable.STAMINA_RATE_PER_S[gait] * delta, GaitTable.STAMINA_MAX)
	if exhausted and stamina >= GaitTable.GALLOP_RESUME_STAMINA:
		exhausted = false
