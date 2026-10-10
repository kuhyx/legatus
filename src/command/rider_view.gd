class_name RiderView
extends Node3D
## Riders on the field (couriers, officers' report riders), each a horse and
## rider from two boxes in the given cloak colour, drawn only while the
## general could see them (same sight test as soldiers).

const HORSE_SIZE: Vector3 = Vector3(0.5, 1.0, 2.2)
const RIDER_SIZE: Vector3 = Vector3(0.45, 0.9, 0.35)
const HORSE_COLOR: Color = Color(0.36, 0.25, 0.17)

var _riders: Array[Courier] = []
var _nodes: Array[Node3D] = []
var _sim: BattleSim = null
var _field: HeightField = null


## One drawn rider per entry of `riders` (the array is shared, not copied).
func setup(riders: Array[Courier], cloak: Color, sim: BattleSim, field: HeightField) -> void:
	_riders = riders
	_sim = sim
	_field = field
	for _i: int in riders.size():
		_nodes.append(_build(cloak))


## Where the riders are drawn this frame; hidden if out of the general's sight.
func draw(eye: Vector3) -> void:
	for i: int in _nodes.size():
		var courier: Courier = _riders[i]
		var node: Node3D = _nodes[i]
		node.visible = false
		if not courier.is_riding():
			continue
		var p: Vector2 = courier.position
		var at: Vector3 = Vector3(p.x, _field.height_at(p.x, p.y), p.y)
		var head: Vector3 = at + Vector3.UP * VisionTable.TARGET_HEIGHT_M
		if _sim.sight_factor(eye, head) < VisionTable.VISIBLE_THRESHOLD:
			continue
		node.position = at
		node.rotation.y = courier.heading
		node.visible = true


func _build(cloak: Color) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Rider"
	root.visible = false
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = HORSE_COLOR
	root.add_child(_box(HORSE_SIZE, Vector3(0.0, 1.0, 0.0), material))
	var cloth: StandardMaterial3D = StandardMaterial3D.new()
	cloth.albedo_color = cloak
	root.add_child(_box(RIDER_SIZE, Vector3(0.0, 1.95, 0.0), cloth))
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
