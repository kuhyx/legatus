class_name LowPoly
extends RefCounted
## Flat-shaded low-poly geometry built in code (no imported models): tapered
## boxes ("frusta") between two cross-sections, coloured per vertex with sRGB
## picks. Set `color`, add parts, then commit() one ArrayMesh = one draw call.

## Colour (sRGB) of the parts added from now on.
var color: Color = Color.WHITE
## Cross-section corners of the parts added from now on: 4 = box, 8 = a
## rounder octagon (necks, limbs), same extents.
var sides: int = 4
var _tool: SurfaceTool = SurfaceTool.new()
var _empty: bool = true


func _init() -> void:
	_tool.begin(Mesh.PRIMITIVE_TRIANGLES)


## A tapered box from centre `a` to centre `b`. `halves` = (x, y) half sizes
## at `a`, then at `b`; x is sideways, y towards the part's top, which faces
## `up` as far as the axis allows (a vertical part falls back to +Z).
func frustum(a: Vector3, b: Vector3, halves: Vector4, up: Vector3 = Vector3.UP) -> void:
	var axis: Vector3 = (b - a).normalized()
	var hint: Vector3 = up.normalized()
	if absf(axis.dot(hint)) > 0.95:
		hint = Vector3.BACK
	var side: Vector3 = axis.cross(hint).normalized()
	var top: Vector3 = side.cross(axis).normalized()
	var ca: PackedVector3Array = _ring(a, side * halves.x, top * halves.y)
	var cb: PackedVector3Array = _ring(b, side * halves.z, top * halves.w)
	var n: int = ca.size()
	for i: int in n:
		var j: int = (i + 1) % n
		_poly(PackedVector3Array([ca[i], ca[j], cb[j], cb[i]]), (a + b) * 0.5)
	_poly(ca, b)
	_poly(cb, a)


## A box of half size `half`, rotated by `basis` about its centre.
func box(center: Vector3, half: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var offset: Vector3 = basis * Vector3(0.0, 0.0, half.z)
	frustum(center - offset, center + offset, even(Vector2(half.x, half.y)), basis * Vector3.UP)


## Both sides of the horse/rider at once: the part and its mirror in x.
func mirrored(a: Vector3, b: Vector3, halves: Vector4, up: Vector3 = Vector3.UP) -> void:
	frustum(a, b, halves, up)
	var flip: Vector3 = Vector3(-1.0, 1.0, 1.0)
	frustum(a * flip, b * flip, halves, up * flip)


func commit() -> ArrayMesh:
	if _empty:
		return ArrayMesh.new()
	return _tool.commit()


## Halves for a part tapering from `a` to `b`.
static func taper(a: Vector2, b: Vector2) -> Vector4:
	return Vector4(a.x, a.y, b.x, b.y)


## Halves for a straight (untapered) part.
static func even(half: Vector2) -> Vector4:
	return Vector4(half.x, half.y, half.x, half.y)


## Corners of a cross-section, in order around it: a box, or an octagon
## whose flat faces touch the same box.
func _ring(c: Vector3, sx: Vector3, sy: Vector3) -> PackedVector3Array:
	if sides != 8:
		return PackedVector3Array([c - sx - sy, c + sx - sy, c + sx + sy, c - sx + sy])
	var ring: PackedVector3Array = PackedVector3Array()
	if ring.resize(8) != OK:
		push_error("LowPoly: cannot allocate a ring")
	var grow: float = 1.0 / cos(PI / 8.0)
	for k: int in 8:
		var angle: float = PI / 8.0 + k * PI / 4.0
		ring[k] = c + (sx * cos(angle) + sy * sin(angle)) * grow
	return ring


## One flat convex polygon (fanned from its first corner), wound so its front
## faces away from `inside` (Godot's front faces are clockwise from outside).
func _poly(p: PackedVector3Array, inside: Vector3) -> void:
	var normal: Vector3 = Vector3.ZERO
	var middle: Vector3 = Vector3.ZERO
	for k: int in p.size():
		normal += p[k].cross(p[(k + 1) % p.size()])
		middle += p[k] / p.size()
	if normal.length_squared() < 1e-14:
		return
	var flip: bool = normal.dot(middle - inside) > 0.0
	_tool.set_color(color)
	_tool.set_normal(normal.normalized() * (1.0 if flip else -1.0))
	for k: int in range(1, p.size() - 1):
		_tool.add_vertex(p[0])
		_tool.add_vertex(p[k + 1] if flip else p[k])
		_tool.add_vertex(p[k] if flip else p[k + 1])
	_empty = false
