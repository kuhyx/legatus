class_name BattleCommand
extends Node3D
## The general's orders in the live battle: keys 1/2/3 (OrderInput) send
## advance / hold / withdraw by courier to the Roman formation he is looking
## at (OrderPicker). Couriers are stepped on the sim tick and drawn as riders,
## each only while the general could see it (same sight test as soldiers).
## Engaged formations take only hold or withdraw (DOCS-design-command.md §3):
## an "advance" reaching a unit already in melee changes nothing, and neither
## does the order a unit already follows. An order that does apply may still
## be ignored by the officer (Officers). The
## couriers' returns fill `orders`; the officers' riders bring `reports`.

## How long the HUD keeps the "courier sent" line, s.
const NOTE_S: float = 4.0
const ORDER_NAMES: PackedStringArray = ["advance", "hold", "withdraw"]
const COURIER_CLOAK: Color = Color(0.55, 0.1, 0.08)
## Officers' riders wear a dark blue cloak [design].
const REPORT_CLOAK: Color = Color(0.12, 0.16, 0.42)

var service: CourierService = null
var officers: Officers = null
var reports: ReportService = null
## The orders the general sent and what came back (HUD).
var orders: OrderLog = OrderLog.new()
## Sim seconds since the battle began (the HUD clock).
var time_s: float = 0.0
## Short player-facing line ("courier sent ..."), empty when nothing new.
var note: String = ""
var _sim: BattleSim = null
var _general: General = null
var _note_left: float = 0.0


func setup(sim: BattleSim, field: HeightField, general: General, rng_seed: int) -> void:
	_sim = sim
	_general = general
	OrderInput.ensure_actions()
	var source: FormationSource = FormationSource.new()
	source.center = sim.get_formation_center
	source.side = sim.get_formation_side
	source.routed = sim.is_formation_routed
	source.engaged = sim.is_formation_engaged
	source.count = sim.get_formation_count
	source.cohesion = sim.get_formation_cohesion
	source.current_order = sim.get_formation_order
	source.deliver = deliver
	source.general_position = general_xz
	service = CourierService.new(source, CourierSettings.new(), rng_seed)
	# Own streams: the ignore roll must not track the courier loss roll.
	officers = Officers.new(sim.get_formation_count(), service.settings, hash([rng_seed, 1]))
	reports = ReportService.new(source, service.settings, hash([rng_seed, 2]))
	if (
		service.order_acknowledged.connect(_on_acknowledged) != OK
		or service.order_found_broken.connect(_on_found_broken) != OK
	):
		push_error("BattleCommand: cannot hear the couriers come back")
	_add_view("Couriers", service.couriers, COURIER_CLOAK, field)
	_add_view("ReportRiders", reports.riders, REPORT_CLOAK, field)


## One sim tick for every courier and report rider (call inside the
## fixed-tick loop).
func tick(dt: float) -> void:
	time_s += dt
	service.step(dt)
	reports.step(dt)
	orders.prune(time_s)
	_note_left = maxf(0.0, _note_left - dt)
	if _note_left <= 0.0:
		note = ""


## Where the riders are drawn this frame; hidden if out of the general's sight.
func draw(eye: Vector3) -> void:
	for child: Node in get_children():
		var view: RiderView = child as RiderView
		if view != null:
			view.draw(eye)


## The order as the formation's officer receives it.
func deliver(f: int, order: int) -> void:
	# The order it already follows: nothing to do, so nothing to roll or set
	# (re-setting hold would re-anchor the men, withdraw would walk them
	# further back). A routed block is left to the sim, which ignores it.
	if order == _sim.get_formation_order(f) and not _sim.is_formation_routed(f):
		print_verbose("orders: %s to formation %d: no change" % [ORDER_NAMES[order], f])
		return
	var engaged: bool = _sim.is_formation_engaged(f)
	var applies: bool = not (order == OrderInput.ADVANCE and engaged)
	# Rolled only for an order that would change something.
	if applies and officers.ignores(f):
		applies = false
		print_verbose("orders: %s IGNORED by formation %d's officer" % [ORDER_NAMES[order], f])
	if applies:
		_sim.set_formation_order(f, order)
	print_verbose(
		(
			"orders: %s reached formation %d (engaged %s): order now %d, cohesion %.2f"
			% [
				ORDER_NAMES[order],
				f,
				engaged,
				_sim.get_formation_order(f),
				_sim.get_formation_cohesion(f)
			]
		)
	)


func general_xz() -> Vector2:
	return Vector2(_general.position.x, _general.position.z)


func _unhandled_input(event: InputEvent) -> void:
	if _general == null or not _general.controls_enabled:
		return
	var order: int = OrderInput.order_for(event)
	if order < 0:
		return
	var target: int = send(order, _general.camera().global_transform)
	print_verbose("orders: key %d -> formation %d" % [order, target])


## Pick the formation on the line of sight of `view` and send it `order`.
## Returns the formation id, or -1 if none was in view or no courier was free.
func send(order: int, view: Transform3D) -> int:
	var centres: PackedVector2Array = PackedVector2Array()
	var sides: PackedInt32Array = PackedInt32Array()
	var routed: PackedByteArray = PackedByteArray()
	for f: int in _sim.get_formation_count():
		# append() returns true on failure.
		if (
			centres.append(_sim.get_formation_center(f))
			or sides.append(_sim.get_formation_side(f))
			or routed.append(1 if _sim.is_formation_routed(f) else 0)
		):
			push_error("BattleCommand: cannot build the formation list")
			return -1
	var target: int = OrderPicker.pick(view, centres, sides, routed)
	if target < 0:
		_say("no formation in view to send that order to")
		return -1
	return send_to(order, target)


## Send `order` to formation `target` by courier. Returns `target`, or -1 if
## no courier was free.
func send_to(order: int, target: int) -> int:
	if not service.dispatch(order, target, general_xz()):
		_say("no courier free")
		return -1
	orders.add(service.last_ticket, target, order, time_s)
	_say("courier rides to formation %d: %s" % [target, ORDER_NAMES[order]])
	return target


func _say(text: String) -> void:
	note = text
	_note_left = NOTE_S


func _on_acknowledged(ticket: int, f: int, order: int) -> void:
	var listed: bool = orders.answer(ticket, OrderLog.Answer.ACKNOWLEDGED, time_s)
	print_verbose(
		"orders: %s to formation %d acknowledged (listed %s)" % [ORDER_NAMES[order], f, listed]
	)


func _on_found_broken(ticket: int, f: int, order: int) -> void:
	var listed: bool = orders.answer(ticket, OrderLog.Answer.BROKEN, time_s)
	print_verbose(
		(
			"orders: %s to formation %d: found them broken (listed %s)"
			% [ORDER_NAMES[order], f, listed]
		)
	)


func _add_view(view_name: String, riders: Array[Courier], cloak: Color, field: HeightField) -> void:
	var view: RiderView = RiderView.new()
	view.name = view_name
	add_child(view)
	view.setup(riders, cloak, _sim, field)
