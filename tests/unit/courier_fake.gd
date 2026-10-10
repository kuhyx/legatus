class_name CourierFake
extends RefCounted
## A fake battle for the courier tests: plain arrays behind FormationSource's
## Callables (bound methods, so the tests can mutate state between ticks).

var centres: Array[Vector2] = []
var sides: Array[int] = []
var routed: Array[bool] = []
var engaged: Array[bool] = []
## For ReportService: per-formation cohesion and current order.
var cohesions: Array[float] = []
var orders: Array[int] = []
var general: Vector2 = Vector2.ZERO
## (formation, order) per delivered order, in delivery order.
var deliveries: Array[Vector2i] = []


## Append a formation; its index is the previous count.
func add(centre: Vector2, side: int) -> void:
	centres.append(centre)
	sides.append(side)
	routed.append(false)
	engaged.append(false)
	cohesions.append(1.0)
	orders.append(OrderInput.HOLD)


func source() -> FormationSource:
	var s: FormationSource = FormationSource.new()
	s.center = _center
	s.side = _side
	s.routed = _routed
	s.engaged = _engaged
	s.count = _count
	s.deliver = _deliver
	s.general_position = _general
	s.cohesion = _cohesion
	s.current_order = _order
	s.keep_alive = self
	return s


func _center(f: int) -> Vector2:
	return centres[f]


func _side(f: int) -> int:
	return sides[f]


func _routed(f: int) -> bool:
	return routed[f]


func _engaged(f: int) -> bool:
	return engaged[f]


func _count() -> int:
	return centres.size()


func _deliver(f: int, order: int) -> void:
	deliveries.append(Vector2i(f, order))


func _general() -> Vector2:
	return general


func _cohesion(f: int) -> float:
	return cohesions[f]


func _order(f: int) -> int:
	return orders[f]
