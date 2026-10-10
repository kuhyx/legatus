class_name BattleCommand
extends Node3D
## The general's orders in the live battle: keys 1/2/3 (OrderInput) send
## advance / hold / withdraw by courier to the Roman formation he is looking
## at (OrderPicker). Couriers are stepped on the sim tick and drawn as riders,
## each only while the general could see it (same sight test as soldiers).
## Engaged formations take only hold or withdraw (DOCS-design-command.md §3):
## an "advance" reaching a unit already in melee changes nothing.

## How long the HUD keeps the "courier sent" line, s.
const NOTE_S: float = 4.0
const ORDER_NAMES: PackedStringArray = ["advance", "hold", "withdraw"]
const HORSE_SIZE: Vector3 = Vector3(0.5, 1.0, 2.2)
const RIDER_SIZE: Vector3 = Vector3(0.45, 0.9, 0.35)

var service: CourierService = null
## Short player-facing line ("courier sent ..."), empty when nothing new.
var note: String = ""
var _sim: BattleSim = null
var _field: HeightField = null
var _general: General = null
var _riders: Array[Node3D] = []
var _note_left: float = 0.0


func setup(sim: BattleSim, field: HeightField, general: General, rng_seed: int) -> void:
	_sim = sim
	_field = field
	_general = general
	OrderInput.ensure_actions()
	var source: FormationSource = FormationSource.new()
	source.center = sim.get_formation_center
	source.side = sim.get_formation_side
	source.routed = sim.is_formation_routed
	source.engaged = sim.is_formation_engaged
	source.count = sim.get_formation_count
	source.deliver = deliver
	source.general_position = general_xz
	service = CourierService.new(source, CourierSettings.new(), rng_seed)
	for _i: int in service.couriers.size():
		_riders.append(_build_rider())


## One sim tick for every courier (call inside the fixed-tick loop).
func tick(dt: float) -> void:
	service.step(dt)
	_note_left = maxf(0.0, _note_left - dt)
	if _note_left <= 0.0:
		note = ""


## Where the couriers are drawn this frame; hidden if out of the general's sight.
func draw(eye: Vector3) -> void:
	for i: int in _riders.size():
		var courier: Courier = service.couriers[i]
		var rider: Node3D = _riders[i]
		rider.visible = false
		if not courier.is_riding():
			continue
		var p: Vector2 = courier.position
		var at: Vector3 = Vector3(p.x, _field.height_at(p.x, p.y), p.y)
		var head: Vector3 = at + Vector3.UP * VisionTable.TARGET_HEIGHT_M
		if _sim.sight_factor(eye, head) < VisionTable.VISIBLE_THRESHOLD:
			continue
		rider.position = at
		rider.rotation.y = courier.heading
		rider.visible = true


## The order as the formation's officer receives it.
func deliver(f: int, order: int) -> void:
	var engaged: bool = _sim.is_formation_engaged(f)
	if not (order == OrderInput.ADVANCE and engaged):
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
	_say("courier rides to formation %d: %s" % [target, ORDER_NAMES[order]])
	return target


func _say(text: String) -> void:
	note = text
	_note_left = NOTE_S


## A horse and rider from two boxes, in the courier's red cloak.
func _build_rider() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Courier"
	root.visible = false
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.36, 0.25, 0.17)
	root.add_child(_box(HORSE_SIZE, Vector3(0.0, 1.0, 0.0), material))
	var cloak: StandardMaterial3D = StandardMaterial3D.new()
	cloak.albedo_color = Color(0.55, 0.1, 0.08)
	root.add_child(_box(RIDER_SIZE, Vector3(0.0, 1.95, 0.0), cloak))
	add_child(root)
	return root


static func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	return instance
