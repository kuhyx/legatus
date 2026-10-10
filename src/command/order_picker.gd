class_name OrderPicker
extends RefCounted
## Which formation is the general pointing at? The player's own (side 0),
## not-routed formation whose centre lies closest in bearing to where the
## camera looks, inside a narrow cone and a max range. Horizontal plane only:
## centres are 2D and the eye height is tiny next to the ranges involved, so
## head pitch does not change the pick.

const PLAYER_SIDE: int = 0
## Half-angle of the pointing cone.
const CONE_DEG: float = 8.0
## Beyond this a block is a "barely visible blob" (numbers table, ~1 mile+).
const MAX_RANGE_M: float = 3000.0


## Index of the picked formation, or -1. `camera` is the camera's global
## transform (looks along -Z); `centres` (world XZ), `sides` and `routed`
## (non-zero = routed) are parallel per-formation arrays.
static func pick(
	camera: Transform3D,
	centres: PackedVector2Array,
	sides: PackedInt32Array,
	routed: PackedByteArray
) -> int:
	var forward: Vector3 = -camera.basis.z
	var look: Vector2 = Vector2(forward.x, forward.z)
	if look.length_squared() < 1e-8:
		return -1
	var eye: Vector2 = Vector2(camera.origin.x, camera.origin.z)
	var best: int = -1
	var best_angle: float = deg_to_rad(CONE_DEG)
	for f: int in mini(centres.size(), mini(sides.size(), routed.size())):
		if sides[f] != PLAYER_SIDE or routed[f] != 0:
			continue
		var to_centre: Vector2 = centres[f] - eye
		var dist: float = to_centre.length()
		if dist > MAX_RANGE_M or dist < 1e-3:
			continue
		var angle: float = absf(look.angle_to(to_centre))
		if angle <= best_angle:
			best_angle = angle
			best = f
	return best
