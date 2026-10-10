class_name Terrain
extends Node3D
## Render mesh + HeightMapShape3D collision for a HeightField. Both read the
## field with its own index convention (row-major, x fastest, centred), so the
## horse rides on exactly the hills Visibility tests against.

const LOW_COLOR: Color = Color(0.31, 0.42, 0.18)
const HIGH_COLOR: Color = Color(0.55, 0.5, 0.3)

var field: HeightField = null


func build(height_field: HeightField) -> void:
	field = height_field
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = _build_mesh()
	add_child(mesh_instance)
	add_child(_build_collision())


func _build_mesh() -> ArrayMesh:
	var res: int = field.resolution
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var count: int = res * res
	if verts.resize(count) != OK or normals.resize(count) != OK or colors.resize(count) != OK:
		push_error("Terrain: cannot allocate %d vertices" % count)
	var top: float = maxf(_max_height(), 1.0)
	for z: int in res:
		for x: int in res:
			var i: int = z * res + x
			var pos: Vector2 = field.sample_position(x, z)
			var h: float = field.heights[i]
			verts[i] = Vector3(pos.x, h, pos.y)
			normals[i] = field.normal_at_sample(x, z)
			colors[i] = LOW_COLOR.lerp(HIGH_COLOR, h / top)
	var arrays: Array = []
	if arrays.resize(Mesh.ARRAY_MAX) != OK:
		push_error("Terrain: cannot allocate mesh arrays")
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = _build_indices(res)
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	# LOW_COLOR/HIGH_COLOR are sRGB picks; read as linear they render ~1.5x
	# brighter and wash out to pale cream under the tonemapper.
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	# Dry grass is diffuse; the default 0.5 mirrored the pale sky at grazing angles.
	material.metallic_specular = 0.2
	mesh.surface_set_material(0, material)
	return mesh


## Two triangles per cell, wound so the faces point up (+Y).
static func _build_indices(res: int) -> PackedInt32Array:
	var cells: int = res - 1
	var indices: PackedInt32Array = PackedInt32Array()
	if indices.resize(cells * cells * 6) != OK:
		push_error("Terrain: cannot allocate indices")
	var k: int = 0
	for z: int in cells:
		for x: int in cells:
			var a: int = z * res + x
			var b: int = a + 1
			var c: int = a + res
			var d: int = c + 1
			indices[k] = a
			indices[k + 1] = b
			indices[k + 2] = c
			indices[k + 3] = b
			indices[k + 4] = d
			indices[k + 5] = c
			k += 6
	return indices


func _build_collision() -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Collision"
	var shape: HeightMapShape3D = HeightMapShape3D.new()
	shape.map_width = field.resolution
	shape.map_depth = field.resolution
	# HeightMapShape3D samples are 1 unit apart. Scale the node uniformly by
	# the spacing (non-uniform collision scale is unsupported) and divide the
	# heights by it to match.
	var scaled: PackedFloat32Array = field.heights.duplicate()
	for i: int in scaled.size():
		scaled[i] /= field.spacing
	shape.map_data = scaled
	var holder: CollisionShape3D = CollisionShape3D.new()
	holder.shape = shape
	holder.scale = Vector3.ONE * field.spacing
	body.add_child(holder)
	return body


func _max_height() -> float:
	var top: float = 0.0
	for h: float in field.heights:
		top = maxf(top, h)
	return top
