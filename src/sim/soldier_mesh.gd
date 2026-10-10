class_name SoldierMesh
extends RefCounted
## Procedural low-poly soldier, built from boxes in code (no binary assets).
## Local frame: feet at y = 0, +Z faces the enemy. UV.y indexes the PALETTE in
## soldier.gdshader (albedo + side-tint mask); UV.x = 1 marks the weapon arm the
## shader thrusts forward when fighting. Vertex COLOR is not used: it came
## through garbled on MultiMesh instances in the GL compatibility renderer.
## Godot treats CLOCKWISE triangles as front faces, which is what _face() emits.

# [center, size, palette index (soldier.gdshader PALETTE), weapon(0/1)].
const NEAR_PARTS: Array = [
	[Vector3(-0.11, 0.42, 0.0), Vector3(0.14, 0.84, 0.16), 0.0, 0.0],
	[Vector3(0.11, 0.42, 0.0), Vector3(0.14, 0.84, 0.16), 0.0, 0.0],
	[Vector3(0.0, 1.12, 0.0), Vector3(0.44, 0.6, 0.26), 1.0, 0.0],
	[Vector3(0.0, 1.58, 0.0), Vector3(0.2, 0.24, 0.22), 2.0, 0.0],
	[Vector3(0.0, 1.72, 0.0), Vector3(0.24, 0.1, 0.26), 3.0, 0.0],
	[Vector3(0.12, 1.05, 0.22), Vector3(0.55, 0.9, 0.06), 4.0, 0.0],
	[Vector3(-0.27, 1.15, 0.12), Vector3(0.1, 0.1, 0.42), 2.0, 1.0],
	[Vector3(-0.27, 1.15, 0.6), Vector3(0.04, 0.05, 0.6), 5.0, 1.0],
]
# Distance stand-in: body column + shield, 24 triangles.
const FAR_PARTS: Array = [
	[Vector3(0.0, 0.86, 0.0), Vector3(0.42, 1.72, 0.28), 1.0, 0.0],
	[Vector3(0.1, 1.0, 0.2), Vector3(0.5, 0.85, 0.06), 4.0, 0.0],
]
# Face normal with tangents u, v where u x v = normal.
const FACES: Array[Array] = [
	[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
	[Vector3.LEFT, Vector3.BACK, Vector3.UP],
	[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
	[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
	[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
	[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
]


static func build(far: bool) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Array in FAR_PARTS if far else NEAR_PARTS:
		for face: Array in FACES:
			_face(st, part, face)
	return st.commit()


static func _face(st: SurfaceTool, part: Array, face: Array) -> void:
	var center: Vector3 = part[0]
	var half: Vector3 = part[1] * 0.5
	var paint: float = part[2]
	var weapon: float = part[3]
	var n: Vector3 = face[0]
	var u: Vector3 = face[1]
	var v: Vector3 = face[2]
	var c: Vector3 = center + n * half
	var du: Vector3 = u * half
	var dv: Vector3 = v * half
	var corners: Array[Vector3] = [c - du - dv, c + du - dv, c + du + dv, c - du + dv]
	st.set_normal(n)
	st.set_uv(Vector2(weapon, paint))
	for k: int in [0, 2, 1, 0, 3, 2]:
		st.add_vertex(corners[k])
