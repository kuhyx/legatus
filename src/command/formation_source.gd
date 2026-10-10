class_name FormationSource
extends RefCounted
## The courier system's only view of the battle: injected Callables, so the
## service runs against BattleSim's formation API in the game and against
## plain lambdas in the tests. Every getter is typed here, once.
##
## Expected signatures:
## center(f: int) -> Vector2 (world XZ), side(f: int) -> int,
## routed(f: int) -> bool, engaged(f: int) -> bool, count() -> int,
## deliver(f: int, order: int) -> void, general_position() -> Vector2 (XZ);
## for ReportService only: cohesion(f: int) -> float, current_order(f: int) -> int.

var center: Callable
var side: Callable
var routed: Callable
var engaged: Callable
var count: Callable
var deliver: Callable
var general_position: Callable
var cohesion: Callable
var current_order: Callable
## A bound-method Callable does not keep a RefCounted target alive. Hold the
## object behind the Callables here when nothing else does (an adapter, a
## test fake); BattleSim and nodes are owned elsewhere and need no help.
var keep_alive: RefCounted = null


func center_of(f: int) -> Vector2:
	var c: Vector2 = center.call(f)
	return c


func side_of(f: int) -> int:
	var s: int = side.call(f)
	return s


func is_routed(f: int) -> bool:
	var r: bool = routed.call(f)
	return r


func is_engaged(f: int) -> bool:
	var e: bool = engaged.call(f)
	return e


func formation_count() -> int:
	var n: int = count.call()
	return n


func general_at() -> Vector2:
	var p: Vector2 = general_position.call()
	return p


func cohesion_of(f: int) -> float:
	var c: float = cohesion.call(f)
	return c


func order_of(f: int) -> int:
	var o: int = current_order.call(f)
	return o


func deliver_order(f: int, order: int) -> void:
	deliver.call(f, order)
