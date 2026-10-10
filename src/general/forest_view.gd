class_name ForestView
extends MultiMeshInstance3D
## Tree visuals for Woods: one MultiMesh of plain cones. No per-tree physics;
## Woods itself is the query structure for sight lines and "in the trees".

const TREE_SPACING_M: float = 9.0
const CROWN_RADIUS_M: float = 3.0


func build(woods: Woods, field: HeightField, noise_seed: int) -> void:
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = CROWN_RADIUS_M
	cone.height = VisionTable.CANOPY_HEIGHT_M
	cone.radial_segments = 6
	cone.rings = 1
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.13, 0.24, 0.11)
	material.roughness = 1.0
	cone.material = material
	var positions: PackedVector2Array = woods.tree_positions(TREE_SPACING_M, noise_seed)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = positions.size()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = noise_seed
	for i: int in positions.size():
		var p: Vector2 = positions[i]
		var size: float = rng.randf_range(0.75, 1.15)
		var basis: Basis = Basis.from_scale(Vector3.ONE * size)
		var y: float = field.height_at(p.x, p.y) + cone.height * 0.5 * size
		mm.set_instance_transform(i, Transform3D(basis, Vector3(p.x, y, p.y)))
	multimesh = mm
