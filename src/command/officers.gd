class_name Officers
extends RefCounted
## Officers' obedience (DOCS-design-command.md §3; numbers table "Order
## ignored (junior courier, no token)"): each formation's officer has his own
## chance of ignoring an order, uniform in [ignore_min, ignore_max], drawn at
## setup in formation-id order. Every delivered order that would change
## something is then one roll against it (BattleCommand.deliver; a no-op takes
## no roll), from a stream of its own: seeded by (battle seed, formation, how
## many rolls that officer has had), so one more order elsewhere changes no other
## roll (one shared RNG made the battle's first order ignored every time with
## the default seed). Couriers are all junior riders without a token for now,
## so the chance does not depend on who carries the order. Seeded: a battle
## replays exactly.

## Per formation, the chance its officer ignores an order.
var chances: PackedFloat32Array = PackedFloat32Array()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed: int = 0
## Per formation, the orders its officer has rolled for so far.
var _rolled: PackedInt32Array = PackedInt32Array()


func _init(count: int, settings: CourierSettings, rng_seed: int) -> void:
	_rng.seed = rng_seed
	_seed = rng_seed
	if chances.resize(count) != OK or _rolled.resize(count) != OK:
		push_error("Officers: cannot size the chance table")
		return
	var top: float = maxf(settings.ignore_min, settings.ignore_max)
	for f: int in count:
		chances[f] = _rng.randf_range(settings.ignore_min, top)


## One roll: true if formation `f`'s officer ignores this order.
func ignores(f: int) -> bool:
	if f < 0 or f >= chances.size():
		return false
	var roll: RandomNumberGenerator = RandomNumberGenerator.new()
	roll.seed = hash([_seed, f, _rolled[f]])
	_rolled[f] += 1
	return roll.randf() < chances[f]
