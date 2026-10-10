class_name DemoRide
extends Node
## A scripted 30 s ride for recordings and screenshots (`--demo-ride`): no one
## presses keys inside Xvfb, so this walks the general through every gait, a
## turn, a look down at the horse and a look back over the rump. Drives only
## General's public state; the general's own controls must be off.

## (start s, gait, turn -1..1, neck yaw deg, neck pitch deg), in time order.
const SCHEDULE: Array[Array] = [
	[0.0, 0, 0.0, 0.0, 0.0],
	[2.0, 1, 0.0, 0.0, 0.0],
	[6.0, 2, 0.0, 0.0, -10.0],
	[10.0, 3, 0.0, 0.0, -10.0],
	[14.0, 4, 0.0, 0.0, 0.0],
	[16.0, 4, 1.0, 0.0, 0.0],
	[18.0, 4, 0.0, 0.0, 0.0],
	[20.0, 3, 0.0, 0.0, -50.0],
	[23.0, 2, 0.0, 110.0, -15.0],
	[26.0, 1, 0.0, 0.0, 0.0],
	[28.0, 0, 0.0, 0.0, 0.0],
]
const DURATION_S: float = 30.0
## How fast the head turns towards the scheduled gaze, rad/s.
const LOOK_RATE_RAD_S: float = 1.5

var elapsed: float = 0.0
var _general: General = null


func _init(general: General) -> void:
	_general = general
	name = "DemoRide"


## The schedule row in force at time t seconds.
static func row_at(t: float) -> PackedFloat32Array:
	var current: Array = SCHEDULE[0]
	for row: Array in SCHEDULE:
		if row[0] <= t:
			current = row
	return PackedFloat32Array(current)


func _physics_process(delta: float) -> void:
	elapsed += delta
	var row: PackedFloat32Array = row_at(elapsed)
	_general.motion.gait = int(row[1])
	_general.scripted_turn = row[2]
	var step: float = LOOK_RATE_RAD_S * delta
	_general.neck_yaw = move_toward(_general.neck_yaw, deg_to_rad(row[3]), step)
	_general.neck_pitch = move_toward(_general.neck_pitch, deg_to_rad(row[4]), step)
