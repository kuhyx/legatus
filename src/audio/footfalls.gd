class_name Footfalls
extends RefCounted
## Beat edges on the horse's stride clock (HorseMotion.stride_count +
## stride_phase): the hoof sounds fire on exactly the clock that drives the
## bob and the head nod, so they cannot drift apart.

## More hits than this in one frame means a hitch, not a gallop: play this many.
const MAX_HITS_PER_STEP: int = 4


## Stride position as one number: whole strides plus the phase.
static func position(motion: HorseMotion) -> float:
	return float(motion.stride_count) + motion.stride_phase


## Beats crossed moving from stride position `before` to `now`, interval
## (before, now]: count of k + offset with k a whole stride. `offsets` are
## stride phases 0..1 (GaitTable.footfalls). A beat exactly at `before` was
## counted by the previous call, so a start at 0.0 does not fire.
static func crossed(before: float, now: float, offsets: PackedFloat32Array) -> int:
	if now <= before:
		return 0
	var hits: int = 0
	for offset: float in offsets:
		hits += floori(now - offset) - floori(before - offset)
	return hits


## Stride phases where the rider sits down into the saddle, once per bounce
## (GaitTable.BOUNCES_PER_STRIDE): the bottom of HorseMotion.bob_offset's
## sine, where the tack takes the weight and creaks.
static func saddle_beats(gait: int) -> PackedFloat32Array:
	var beats: PackedFloat32Array = PackedFloat32Array()
	var bounces: int = GaitTable.BOUNCES_PER_STRIDE[clampi(gait, GaitTable.HALT, GaitTable.GALLOP)]
	for i: int in bounces:
		# append() returns true on failure; a PackedFloat32Array never refuses.
		if beats.append((0.75 + i) / bounces):
			break
	return beats
