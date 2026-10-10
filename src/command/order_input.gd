class_name OrderInput
extends RefCounted
## Order keys, registered at runtime like GeneralInput (no [input] section in
## project.godot). 1/2/3 are free: W/S/A/D, the arrows and Escape belong to
## the general. Order ids match BattleSim's ORDER_* constants.

const ADVANCE: int = 0
const HOLD: int = 1
const WITHDRAW: int = 2

const ORDER_ADVANCE: StringName = &"order_advance"
const ORDER_HOLD: StringName = &"order_hold"
const ORDER_WITHDRAW: StringName = &"order_withdraw"


static func ensure_actions() -> void:
	_add(ORDER_ADVANCE, KEY_1)
	_add(ORDER_HOLD, KEY_2)
	_add(ORDER_WITHDRAW, KEY_3)


## The order an input event asks for, or -1 if it is not an order key press.
static func order_for(event: InputEvent) -> int:
	if event.is_action_pressed(ORDER_ADVANCE):
		return ADVANCE
	if event.is_action_pressed(ORDER_HOLD):
		return HOLD
	if event.is_action_pressed(ORDER_WITHDRAW):
		return WITHDRAW
	return -1


static func _add(action: StringName, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)
