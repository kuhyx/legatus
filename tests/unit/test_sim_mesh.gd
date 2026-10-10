extends GutTest
## The procedural soldier: triangle budget and Godot's clockwise front faces.


func _arrays(far: bool) -> Array:
	return SoldierMesh.build(far).surface_get_arrays(0)


func test_triangle_budgets() -> void:
	var near: PackedVector3Array = _arrays(false)[Mesh.ARRAY_VERTEX]
	var far: PackedVector3Array = _arrays(true)[Mesh.ARRAY_VERTEX]
	assert_eq(near.size() / 3, 96, "8 boxes")
	assert_eq(far.size() / 3, 24, "2 boxes")


func test_every_triangle_is_clockwise_seen_from_outside() -> void:
	for far: bool in [false, true]:
		var arrays: Array = _arrays(far)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for t: int in verts.size() / 3:
			var a: Vector3 = verts[t * 3]
			var ccw: Vector3 = (verts[t * 3 + 1] - a).cross(verts[t * 3 + 2] - a)
			assert_lt(ccw.dot(normals[t * 3]), 0.0, "triangle %d (far=%s)" % [t, far])


func test_feet_on_the_ground_and_weapon_in_front() -> void:
	var arrays: Array = _arrays(false)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var lowest: float = INF
	var tip: float = -INF
	for i: int in verts.size():
		lowest = minf(lowest, verts[i].y)
		if uvs[i].x > 0.5:
			tip = maxf(tip, verts[i].z)
	assert_almost_eq(lowest, 0.0, 1e-5)
	assert_gt(tip, 0.8, "the blade points at the enemy (+Z)")
