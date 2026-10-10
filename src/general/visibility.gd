class_name Visibility
extends RefCounted
## What the general can see: CPU line of sight against the heightmap, woods,
## haze and dust. Meant to be asked per formation, not per soldier, so it
## samples the HeightField along the sight line instead of physics raycasts.

## Terrain to test against. null = flat ground at y = 0, nothing occludes.
var field: HeightField = null
## Woods clusters, or null for open country.
var woods: Woods = null
## Hook for the battle sim: 0 = clear air, 1 = thick dust. Stub until the sim
## publishes dust; it scales an extinction over the whole sight line.
var dust_density: float = 0.0


func _init(height_field: HeightField = null, forest: Woods = null) -> void:
	field = height_field
	woods = forest


## Visible at all (factor at or above VisionTable.VISIBLE_THRESHOLD).
func is_visible(eye: Vector3, point: Vector3) -> bool:
	return visibility_factor(eye, point) >= VisionTable.VISIBLE_THRESHOLD


## 0..1: how clearly point stands out from eye. 0 = hidden.
func visibility_factor(eye: Vector3, point: Vector3) -> float:
	var distance: float = eye.distance_to(point)
	if distance > VisionTable.MAX_DISTANCE_M or terrain_blocks(eye, point):
		return 0.0
	var factor: float = haze_factor(distance)
	if woods != null:
		factor *= exp(-woods.depth_along(eye, point, field) / VisionTable.WOODS_EXTINCTION_M)
	factor *= exp(-clampf(dust_density, 0.0, 1.0) * distance / VisionTable.DUST_EXTINCTION_M)
	return factor


## Linear haze falloff from HAZE_START_M to MAX_DISTANCE_M.
static func haze_factor(distance: float) -> float:
	var span: float = VisionTable.MAX_DISTANCE_M - VisionTable.HAZE_START_M
	return clampf(1.0 - (distance - VisionTable.HAZE_START_M) / span, 0.0, 1.0)


## Distance to the sea-level horizon for an eye eye_height metres up.
static func horizon_distance(eye_height: float) -> float:
	var h: float = maxf(eye_height, 0.0)
	return sqrt(2.0 * VisionTable.EARTH_RADIUS_M * h + h * h)


## True if the ground rises above the sight line anywhere between the two.
## Samples once per half grid cell and adds the earth's bulge, so a far point
## low on the plain also drops out of view.
func terrain_blocks(eye: Vector3, point: Vector3) -> bool:
	if field == null:
		return false
	var length: float = eye.distance_to(point)
	var usable: float = length - VisionTable.END_CLEARANCE_M
	if usable <= 0.0:
		return false
	var step: float = field.spacing * 0.5
	var samples: int = int(usable / step)
	var two_r: float = 2.0 * VisionTable.EARTH_RADIUS_M
	for i: int in range(1, samples + 1):
		var t: float = float(i) * step / length
		var p: Vector3 = eye.lerp(point, t)
		var bulge: float = t * (1.0 - t) * length * length / two_r
		if field.height_at(p.x, p.z) + bulge > p.y + VisionTable.TERRAIN_TOLERANCE_M:
			return true
	return false
