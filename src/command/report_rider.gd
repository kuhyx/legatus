class_name ReportRider
extends Courier
## An officer's rider carrying one report to the general: OUTBOUND, then IDLE
## on arrival (HANDED_OVER) or LOST on the way. Rides with Courier's maths
## and CourierSettings' speed and arrival radius; the target is the general,
## re-read every tick. `formation` is the sender; `order` is unused.

## ReportLevel the officer reported.
var level: int = -1
## Sim time the officer saw it (= when he sent the rider).
var seen_s: float = 0.0


## Leave formation `f`'s centre `from` with `report_level` seen at `now_s`.
func send(f: int, report_level: int, from: Vector2, now_s: float) -> void:
	dispatch(f, -1, from)
	level = report_level
	seen_s = now_s


func step(dt: float, target: Vector2, settings: CourierSettings) -> Event:
	if state != State.OUTBOUND:
		return Event.NONE
	var arrived: bool = _ride(dt, target, settings)
	if lose_after_m >= 0.0 and (arrived or travelled_m >= lose_after_m):
		state = State.LOST
		return Event.LOST
	if not arrived:
		return Event.NONE
	state = State.IDLE
	return Event.HANDED_OVER
