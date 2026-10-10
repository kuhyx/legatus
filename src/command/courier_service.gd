class_name CourierService
extends RefCounted
## The general's courier pool (DOCS-design-command.md §3): every order rides
## out as a physical courier, is handed over after a search-and-explain delay,
## and the rider gallops back to wherever the general is now.
##
## Step it on the SIM tick (BenchScenario.TICK_DT, scaled with the sim clock,
## Decision 4), never on wall time. All randomness comes from one seeded RNG
## and is drawn at dispatch, so a run replays exactly from its seed.
## A lost courier or an order to a routed unit is NOT reported to the player:
## the signals and `history` are for debug HUDs and tests only.

signal order_delivered(formation: int, order: int)
## The courier arrived but the formation had routed: nobody to obey.
signal order_dropped(formation: int, order: int)
signal courier_lost(courier: Courier)

## Debug log lines kept, oldest first dropped.
const LOG_LIMIT: int = 64

var settings: CourierSettings = null
var source: FormationSource = null
var couriers: Array[Courier] = []
## Debug trail of what happened to orders (never shown to the player).
var history: PackedStringArray = PackedStringArray()
var delivered_count: int = 0
var dropped_count: int = 0
var lost_count: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time_s: float = 0.0


func _init(
	formation_source: FormationSource, courier_settings: CourierSettings, rng_seed: int
) -> void:
	source = formation_source
	settings = courier_settings if courier_settings != null else CourierSettings.new()
	_rng.seed = rng_seed
	for _i: int in settings.pool_size:
		couriers.append(Courier.new())


## Send `order` to formation `formation_id`, the courier leaving from `from`
## (world XZ, normally the general). False if no courier is free or the
## formation does not exist; nothing is consumed then.
func dispatch(order: int, formation_id: int, from: Vector2) -> bool:
	var courier: Courier = _free_courier()
	if courier == null or formation_id < 0 or formation_id >= source.formation_count():
		return false
	var target: Vector2 = source.center_of(formation_id)
	var chance: float = settings.loss_chance(from, target, source, source.side_of(formation_id))
	# Fixed draw order (roll, loss point, handoff) keeps runs replayable.
	var roll: float = _rng.randf()
	var point: float = _rng.randf()
	courier.handoff_s = settings.sample_handoff(_rng)
	var route_m: float = maxf(from.distance_to(target) - settings.arrival_radius_m, 0.0)
	var lost: bool = chance >= 1.0 or roll < chance
	courier.lose_after_m = point * route_m if lost else -1.0
	courier.dispatch(formation_id, order, from)
	_note("dispatch order %d -> formation %d (loss chance %.3f)" % [order, formation_id, chance])
	return true


## Advance every courier by `dt` sim seconds.
func step(dt: float) -> void:
	_time_s += dt
	var general: Vector2 = source.general_at()
	for courier: Courier in couriers:
		if courier.state == Courier.State.IDLE:
			courier.position = general
			continue
		if not courier.is_riding():
			continue
		var target: Vector2 = general
		if courier.state != Courier.State.RETURNING:
			target = source.center_of(courier.formation)
		var event: Courier.Event = courier.step(dt, target, settings)
		if event == Courier.Event.HANDED_OVER:
			_hand_over(courier)
		elif event == Courier.Event.LOST:
			lost_count += 1
			_note(
				(
					"courier lost at %v: order %d never reaches formation %d"
					% [courier.position, courier.order, courier.formation]
				)
			)
			courier_lost.emit(courier)


## Couriers in the pool, ready to ride.
func free_count() -> int:
	var n: int = 0
	for courier: Courier in couriers:
		if courier.state == Courier.State.IDLE:
			n += 1
	return n


func _hand_over(courier: Courier) -> void:
	if source.is_routed(courier.formation):
		dropped_count += 1
		_note("order %d to formation %d lost: it has routed" % [courier.order, courier.formation])
		order_dropped.emit(courier.formation, courier.order)
		return
	delivered_count += 1
	source.deliver_order(courier.formation, courier.order)
	_note("order %d delivered to formation %d" % [courier.order, courier.formation])
	order_delivered.emit(courier.formation, courier.order)


func _free_courier() -> Courier:
	for courier: Courier in couriers:
		if courier.state == Courier.State.IDLE:
			return courier
	return null


func _note(line: String) -> void:
	var stamped: String = "[%.1f s] %s" % [_time_s, line]
	print_verbose("couriers: ", stamped)
	# append() is true on failure; then there is nothing new to trim.
	if not history.append(stamped) and history.size() > LOG_LIMIT:
		history.remove_at(0)
