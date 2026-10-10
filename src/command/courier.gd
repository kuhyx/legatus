class_name Courier
extends RefCounted
## One rider carrying one order: IDLE (in the pool, with the general) ->
## OUTBOUND -> HANDOFF -> RETURNING -> IDLE, or LOST on the way out.
##
## No RNG and no battle access of its own: CourierService draws every random
## value at dispatch and feeds the targets each step, so a run is fully
## determined by the service seed. Positions are world XZ.

enum State { IDLE, OUTBOUND, HANDOFF, RETURNING, LOST }
## What a step() produced, for the service to act on.
enum Event { NONE, HANDED_OVER, LOST, RETURNED }

var state: State = State.IDLE
var position: Vector2 = Vector2.ZERO
## Same convention as HorseMotion.heading: forward = (-sin h, -cos h) in XZ,
## so a renderer can set rotation.y = heading.
var heading: float = 0.0
var order: int = -1
var formation: int = -1
## Distance ridden this leg.
var travelled_m: float = 0.0
## Outbound leg only: the courier is lost once travelled_m reaches this
## (negative = he gets through). Set at dispatch.
var lose_after_m: float = -1.0
## Seconds of finding and explaining, drawn at dispatch.
var handoff_s: float = 0.0
## CourierService's id for this dispatch, kept after the return so the
## acknowledgement can name the order it answers.
var ticket: int = -1
## Set at the handoff: the formation had routed, he rides back with that news.
var found_broken: bool = false
var _handoff_left: float = 0.0
## HANDOFF: where he stands relative to the (moving) formation centre.
var _offset: Vector2 = Vector2.ZERO


## Leave the pool from `from` with `order` for formation `f`.
func dispatch(f: int, order_id: int, from: Vector2) -> void:
	formation = f
	order = order_id
	position = from
	travelled_m = 0.0
	found_broken = false
	state = State.OUTBOUND


## True while the rider is on the field (drawn), not in the pool or dead.
func is_riding() -> bool:
	return state == State.OUTBOUND or state == State.HANDOFF or state == State.RETURNING


## Advance by `dt` sim seconds. `target` is the formation centre (OUTBOUND,
## HANDOFF) or the general's position (RETURNING), re-read every tick.
func step(dt: float, target: Vector2, settings: CourierSettings) -> Event:
	var event: Event = Event.NONE
	match state:
		State.OUTBOUND:
			event = _step_outbound(dt, target, settings)
		State.HANDOFF:
			event = _step_handoff(dt, target)
		State.RETURNING:
			if _ride(dt, target, settings):
				state = State.IDLE
				order = -1
				formation = -1
				event = Event.RETURNED
	return event


func _step_outbound(dt: float, target: Vector2, settings: CourierSettings) -> Event:
	var arrived: bool = _ride(dt, target, settings)
	if lose_after_m >= 0.0 and (arrived or travelled_m >= lose_after_m):
		state = State.LOST
		return Event.LOST
	if arrived:
		state = State.HANDOFF
		_handoff_left = handoff_s
		_offset = position - target
	return Event.NONE


## He stays with the formation while it moves; then the order is handed over.
func _step_handoff(dt: float, target: Vector2) -> Event:
	position = target + _offset
	_handoff_left -= dt
	if _handoff_left > 0.0:
		return Event.NONE
	state = State.RETURNING
	travelled_m = 0.0
	return Event.HANDED_OVER


## Gallop straight at `target`; true once within the arrival radius.
func _ride(dt: float, target: Vector2, settings: CourierSettings) -> bool:
	var to_target: Vector2 = target - position
	var dist: float = to_target.length()
	if dist <= settings.arrival_radius_m:
		return true
	var move: float = settings.speed_mps() * dt
	heading = atan2(-to_target.x, -to_target.y)
	if move >= dist:
		position = target
		travelled_m += dist
		return true
	position += to_target / dist * move
	travelled_m += move
	return dist - move <= settings.arrival_radius_m
