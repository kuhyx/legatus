class_name Woods
extends RefCounted
## Woods as circular clusters: a cheap CPU query structure for line of sight
## (and "is the horse in the trees"), plus tree placement for the visuals.

var centers: PackedVector2Array = PackedVector2Array()
var radii: PackedFloat32Array = PackedFloat32Array()


func add_cluster(center: Vector2, radius: float) -> void:
	# Packed*Array.append returns true on failure.
	var failed: bool = centers.append(center)
	failed = radii.append(radius) or failed
	if failed:
		push_error("Woods: cannot grow cluster arrays")


## Seeded random clusters over a field. No tree stands within clear_radius
## of the origin, so the start area is open country.
static func scatter(noise_seed: int, field: HeightField, count: int, clear_radius: float) -> Woods:
	var woods: Woods = Woods.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = noise_seed
	var half: float = field.size() * 0.45
	while woods.centers.size() < count:
		var center: Vector2 = Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		var radius: float = rng.randf_range(60.0, 220.0)
		if center.length() > clear_radius + radius:
			woods.add_cluster(center, radius)
	return woods


## True if world (x, z) is inside any cluster.
func contains(x: float, z: float) -> bool:
	var p: Vector2 = Vector2(x, z)
	for i: int in centers.size():
		if p.distance_squared_to(centers[i]) <= radii[i] * radii[i]:
			return true
	return false


## Metres of forest the segment eye->point passes through below the canopy.
## field may be null (flat ground at y = 0).
func depth_along(eye: Vector3, point: Vector3, field: HeightField) -> float:
	var total: float = 0.0
	for i: int in centers.size():
		var span: Vector2 = _chord(eye, point, centers[i], radii[i])
		if span.y > span.x:
			total += _below_canopy(eye, point, span, field) * eye.distance_to(point)
	return total


## Jittered grid of tree positions inside every cluster.
func tree_positions(tree_spacing: float, noise_seed: int) -> PackedVector2Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = noise_seed
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in centers.size():
		var steps: int = int(radii[i] / tree_spacing)
		for gz: int in range(-steps, steps + 1):
			for gx: int in range(-steps, steps + 1):
				var jitter: Vector2 = Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * tree_spacing
				var p: Vector2 = Vector2(gx, gz) * tree_spacing + jitter
				if p.length() <= radii[i] and out.append(centers[i] + p):
					push_error("Woods: cannot grow tree array")
	return out


## Segment parameter range [t0, t1] inside the circle, in Vector2(t0, t1);
## empty (t1 <= t0) when the segment misses it.
static func _chord(eye: Vector3, point: Vector3, center: Vector2, radius: float) -> Vector2:
	var a: Vector2 = Vector2(eye.x, eye.z)
	var d: Vector2 = Vector2(point.x, point.z) - a
	var f: Vector2 = a - center
	var qa: float = d.dot(d)
	if qa < 1e-6:
		return Vector2.ZERO
	var qb: float = 2.0 * f.dot(d)
	var disc: float = qb * qb - 4.0 * qa * (f.dot(f) - radius * radius)
	if disc <= 0.0:
		return Vector2.ZERO
	var root: float = sqrt(disc)
	return Vector2(
		clampf((-qb - root) / (2.0 * qa), 0.0, 1.0), clampf((-qb + root) / (2.0 * qa), 0.0, 1.0)
	)


## Fraction of the whole segment, within span, where the sight line runs
## below the canopy top. Clearance is taken as linear between entry and exit.
static func _below_canopy(eye: Vector3, point: Vector3, span: Vector2, field: HeightField) -> float:
	var c0: float = _clearance(eye, point, span.x, field)
	var c1: float = _clearance(eye, point, span.y, field)
	var width: float = span.y - span.x
	if c0 >= 0.0 and c1 >= 0.0:
		return 0.0
	if c0 < 0.0 and c1 < 0.0:
		return width
	var under: float = c0 if c0 < 0.0 else c1
	return width * (-under) / absf(c1 - c0)


static func _clearance(eye: Vector3, point: Vector3, t: float, field: HeightField) -> float:
	var p: Vector3 = eye.lerp(point, t)
	var ground: float = 0.0 if field == null else field.height_at(p.x, p.z)
	return p.y - (ground + VisionTable.CANOPY_HEIGHT_M)
