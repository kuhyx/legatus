class_name CourierSettings
extends Resource
## Courier constants (DOCS-design.md numbers table; Decision 7: the loss
## numbers are [design guess] settings to tune after playtests).
##
## Loss model, one roll per order at dispatch, over the straight route from
## the general to the target formation's centre at that moment:
## - behind own lines: 1 - (1 - loss_per_km)^km;
## - one near-enemy roll per pass: ANY enemy formation centre within
##   near_enemy_radius_m of the route (the table's "per pass", not per unit;
##   line infantry stands in for skirmishers and cavalry until those exist);
## - one melee roll if any ENGAGED enemy centre lies within melee_radius_m of
##   the route; it supersedes the near-enemy roll.
## The hazard route stops delivery_standoff_m short of the target: the rider
## reaches an engaged unit from its rear, he does not cross its melee.
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
## Hazards are judged on the route up to this far short of the target centre.
@export var delivery_standoff_m: float = 60.0
## The general's courier pool [design: 6-10] (DOCS-design-command.md §3).
@export var pool_size: int = 8
## The rider reins in this close to the formation centre (or the general).
@export var arrival_radius_m: float = 15.0
## An officer ignores an order from a junior courier with no token: each
## officer's chance is drawn uniformly in [ignore_min, ignore_max] at setup
## (numbers table "Order ignored", Officers) [design guess].
@export var ignore_min: float = 0.10
@export var ignore_max: float = 0.25


func speed_mps() -> float:
	return speed_kmh / 3.6


## Chance in [0, 1] that an order sent from `from` to the formation centre
## `to` is lost on the way, given the formations' state at dispatch.
func loss_chance(from: Vector2, to: Vector2, source: FormationSource, own_side: int) -> float:
	var survive: float = pow(1.0 - clampf(loss_per_km, 0.0, 1.0), from.distance_to(to) / 1000.0)
	var route: float = from.distance_to(to)
	var end: Vector2 = from.move_toward(to, maxf(route - delivery_standoff_m, 0.0))
	var near: bool = false
	var melee: bool = false
	for f: int in source.formation_count():
		if source.side_of(f) == own_side:
			continue
		var gap: float = _segment_distance(source.center_of(f), from, end)
		melee = melee or (gap <= melee_radius_m and source.is_engaged(f))
		near = near or gap <= near_enemy_radius_m
	if melee:
		survive *= 1.0 - clampf(loss_melee_crossing, 0.0, 1.0)
	elif near:
		survive *= 1.0 - clampf(loss_near_enemy, 0.0, 1.0)
	return clampf(1.0 - survive, 0.0, 1.0)


## How far along the route from `from` to `to` the rider is lost, in metres
## ridden, or -1 if he gets through: one roll against `chance`, then the loss
## point. Always both draws, in this order, so a run replays from its seed.
func sample_loss_point(
	from: Vector2, to: Vector2, chance: float, rng: RandomNumberGenerator
) -> float:
	var roll: float = rng.randf()
	var point: float = rng.randf()
	if chance < 1.0 and roll >= chance:
		return -1.0
	return point * maxf(from.distance_to(to) - arrival_radius_m, 0.0)


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
