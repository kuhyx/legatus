class_name CourierSettings
extends Resource
## Courier constants (DOCS-design.md numbers table; Decision 7: the loss
## numbers are [design guess] settings to tune after playtests).
##
## Loss model, one roll per order at dispatch, over the straight route from
## the general to the target formation's centre at that moment:
## - behind own lines: 1 - (1 - loss_per_km)^km;
## - each ENEMY formation (side != the target's side) counts at most once:
##   engaged and its centre within melee_radius_m of the route -> the melee
##   crossing roll (supersedes the near-enemy roll for that formation);
##   otherwise centre within near_enemy_radius_m -> the near-enemy roll.
## Chances combine as independent survivals. A courier to a unit locked in
## melee therefore usually takes the melee roll: the enemy centre sits a few
## dozen metres past the contact line, i.e. at the end of his route.
## The ride back is not rolled: the order is already delivered or lost.

## Gallop ~40 km/h (Part II, §Signals and Shouting).
@export var speed_kmh: float = 40.0
## Finding the centurion/tribune and explaining [design guess].
@export var handoff_min_s: float = 60.0
@export var handoff_max_s: float = 180.0
## Behind own lines, per km of route [design guess].
@export var loss_per_km: float = 0.01
## Per pass within near_enemy_radius_m of an enemy formation [design guess].
@export var loss_near_enemy: float = 0.15
@export var near_enemy_radius_m: float = 200.0
## Crossing the melee zone: an engaged enemy centre within melee_radius_m of
## the route [design guess]. 40 m ~ the depth of the fighting front.
@export var loss_melee_crossing: float = 0.5
@export var melee_radius_m: float = 40.0
## The general's courier pool [design: 6-10] (DOCS-design-command.md §3).
@export var pool_size: int = 8
## The rider reins in this close to the formation centre (or the general).
@export var arrival_radius_m: float = 15.0


func speed_mps() -> float:
	return speed_kmh / 3.6


## Chance in [0, 1] that an order sent from `from` to the formation centre
## `to` is lost on the way, given the formations' state at dispatch.
func loss_chance(from: Vector2, to: Vector2, source: FormationSource, own_side: int) -> float:
	var survive: float = pow(1.0 - clampf(loss_per_km, 0.0, 1.0), from.distance_to(to) / 1000.0)
	for f: int in source.formation_count():
		if source.side_of(f) == own_side:
			continue
		var gap: float = _segment_distance(source.center_of(f), from, to)
		if gap <= melee_radius_m and source.is_engaged(f):
			survive *= 1.0 - clampf(loss_melee_crossing, 0.0, 1.0)
		elif gap <= near_enemy_radius_m:
			survive *= 1.0 - clampf(loss_near_enemy, 0.0, 1.0)
	return clampf(1.0 - survive, 0.0, 1.0)


## Uniform handoff duration in [handoff_min_s, handoff_max_s].
func sample_handoff(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(handoff_min_s, maxf(handoff_min_s, handoff_max_s))


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq <= 0.0:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)
