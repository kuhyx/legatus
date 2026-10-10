class_name GeneralInput
extends RefCounted
## InputMap actions for the general, registered at runtime so project.godot
## does not need an [input] section. Idempotent: safe to call per instance.

const GAIT_UP: StringName = &"general_gait_up"
const GAIT_DOWN: StringName = &"general_gait_down"
const TURN_LEFT: StringName = &"general_turn_left"
const TURN_RIGHT: StringName = &"general_turn_right"
const RELEASE_MOUSE: StringName = &"general_release_mouse"
## Mute / unmute every sound (RiderAudio).
const MUTE: StringName = &"general_mute"


static func ensure_actions() -> void:
	_add(GAIT_UP, [KEY_W, KEY_UP])
	_add(GAIT_DOWN, [KEY_S, KEY_DOWN])
	_add(TURN_LEFT, [KEY_A, KEY_LEFT])
	_add(TURN_RIGHT, [KEY_D, KEY_RIGHT])
	_add(RELEASE_MOUSE, [KEY_ESCAPE])
	_add(MUTE, [KEY_M])


static func _add(action: StringName, keys: Array[Key]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key: Key in keys:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
