class_name DinSelect
extends RefCounted
## Which formations the general hears: the nearest noisy ones, by distance
## alone. Hearing is not seeing, so there is no sight-tile or courier
## visibility test here; a fight behind a hill is still heard.

## What a formation sounds like (kinds[f]).
const SILENT: int = 0
const ENGAGED: int = 1
const ROUTED: int = 2


## The kind of noise a formation makes: fighting, fleeing, or none. A routed
## formation that is engaged is still running, so ROUTED wins; no living men,
## no noise.
static func kind_of(engaged: bool, routed: bool, living: int) -> int:
	if living <= 0:
		return SILENT
	if routed:
		return ROUTED
	return ENGAGED if engaged else SILENT


## Ids of the at most `cap` formations with a non-SILENT kind within
## AudioTuning.DIN_MAX_DISTANCE_M of `listener` (world XZ), nearest first.
static func nearest(
	listener: Vector2, centres: PackedVector2Array, kinds: PackedByteArray, cap: int
) -> PackedInt32Array:
	var max_d2: float = AudioTuning.DIN_MAX_DISTANCE_M * AudioTuning.DIN_MAX_DISTANCE_M
	# (squared distance, id): Vector2 sorts by x, then y, so ties stay stable.
	var found: Array[Vector2] = []
	for f: int in mini(centres.size(), kinds.size()):
		if kinds[f] == SILENT:
			continue
		var d2: float = listener.distance_squared_to(centres[f])
		if d2 <= max_d2:
			found.append(Vector2(d2, f))
	found.sort()
	var picked: PackedInt32Array = PackedInt32Array()
	for i: int in mini(cap, found.size()):
		# append() returns true on failure; a PackedInt32Array never refuses.
		if picked.append(int(found[i].y)):
			break
	return picked
