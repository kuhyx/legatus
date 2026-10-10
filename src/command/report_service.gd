class_name ReportService
extends RefCounted
## Officers' reports (DOCS-design-perception.md §4): "Officers send riders
## back with short reports ('Legio II holding, hard pressed'). These are
## subject to the same courier delay and loss as orders", and are "biased by
## their morale" (ReportLevel). Player side only; a routed block sends nothing.
##
## An officer sends a rider when his block's true level differs from the one
## he last reported on, at most once per MIN_GAP_S: a change inside the gap
## waits and goes out when it ends, with the level of that moment, and is not
## sent at all if it changed back. What he says is rolled at dispatch
## (ReportLevel.stated), so a re-roll cannot make reports flicker. The rider
## leaves the block's rear (CourierSettings.delivery_standoff_m from the
## centre toward the general: he does not cross his own melee) and
## gallops to wherever the general is now; one loss roll at dispatch
## (CourierSettings.loss_chance), a lost rider simply never arrives. Officers
## have their own RIDERS (not the general's pool). If all are out, nothing is
## dropped: the change stays pending at its formation, like one inside the
## gap, and goes out (as it then is) when a rider is free, lowest formation id
## first [design; recycling the oldest rider instead lost 9 of 25 reports
## at the first clash, all sent in the same tick]. Step on the sim tick; all
## randomness is seeded.

const PLAYER_SIDE: int = 0
## Officers' riders on the field at once [design guess].
const RIDERS: int = 16
## One report per formation per this many sim seconds [design guess].
const MIN_GAP_S: float = 60.0
## The HUD keeps the last SHOWN reports, each SHOWN_FOR_S after arrival.
const SHOWN: int = 5
const SHOWN_FOR_S: float = 90.0

## The riders, typed as Courier so RiderView draws them; all are ReportRider.
var riders: Array[Courier] = []
## Reports that reached the general, oldest first: x = formation,
## y = ReportLevel, z = seen at (sim s), w = arrived at (sim s).
var arrived: Array[Vector4] = []
var settings: CourierSettings = null
var source: FormationSource = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time_s: float = 0.0
## Per formation: the true level its officer last reported on, and when.
var _sent_level: PackedInt32Array = PackedInt32Array()
var _sent_s: PackedFloat64Array = PackedFloat64Array()


func _init(
	formation_source: FormationSource, courier_settings: CourierSettings, rng_seed: int
) -> void:
	source = formation_source
	settings = courier_settings if courier_settings != null else CourierSettings.new()
	_rng.seed = rng_seed
	for _i: int in RIDERS:
		riders.append(ReportRider.new())
	var count: int = source.formation_count()
	if _sent_level.resize(count) != OK or _sent_s.resize(count) != OK:
		push_error("ReportService: cannot size the formation tables")
		return
	# The general saw them deployed and holding: no report until that changes.
	_sent_level.fill(ReportLevel.HOLDING)
	_sent_s.fill(-MIN_GAP_S)


## Advance every rider by `dt` sim seconds, then let the officers look.
func step(dt: float) -> void:
	_time_s += dt
	var general: Vector2 = source.general_at()
	for courier: Courier in riders:
		if not courier.is_riding():
			continue
		var rider: ReportRider = courier as ReportRider
		var event: Courier.Event = rider.step(dt, general, settings)
		if event == Courier.Event.HANDED_OVER:
			_arrive(rider)
		elif event == Courier.Event.LOST:
			_note("rider lost at %v: %s never arrives" % [rider.position, describe(rider)])
	_observe()
	while not arrived.is_empty() and _time_s - arrived[0].w > SHOWN_FOR_S:
		arrived.remove_at(0)


## HUD lines, oldest first: "08:07 block 12: hard pressed (seen 08:05)".
func lines() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for r: Vector4 in arrived:
		var line: String = (
			"%s block %d: %s (seen %s)"
			% [
				BattleClock.hhmm(r.w),
				int(r.x),
				ReportLevel.NAMES[int(r.y)],
				BattleClock.hhmm(r.z),
			]
		)
		# append() returns true on failure.
		if out.append(line):
			push_error("ReportService: cannot build the HUD lines")
	return out


static func describe(rider: ReportRider) -> String:
	return (
		"block %d '%s' (seen %s)"
		% [rider.formation, ReportLevel.NAMES[rider.level], BattleClock.hhmm(rider.seen_s)]
	)


func _observe() -> void:
	for f: int in mini(source.formation_count(), _sent_level.size()):
		if source.side_of(f) != PLAYER_SIDE or source.is_routed(f):
			continue
		if _time_s - _sent_s[f] < MIN_GAP_S:
			continue
		var level: int = ReportLevel.actual(
			source.is_engaged(f), source.cohesion_of(f), source.order_of(f) == OrderInput.WITHDRAW
		)
		if level == _sent_level[f]:
			continue
		var rider: ReportRider = _free_rider()
		if rider == null:
			return  # all riders out: the rest wait for the next tick
		_dispatch(rider, f, level)


func _dispatch(rider: ReportRider, f: int, level: int) -> void:
	var general: Vector2 = source.general_at()
	var from: Vector2 = source.center_of(f).move_toward(general, settings.delivery_standoff_m)
	var chance: float = settings.loss_chance(from, general, source, PLAYER_SIDE)
	# Fixed draw order (loss roll, loss point, bias) keeps runs replayable.
	rider.lose_after_m = settings.sample_loss_point(from, general, chance, _rng)
	var said: int = ReportLevel.stated(level, source.cohesion_of(f), _rng.randf())
	rider.send(f, said, from, _time_s)
	_sent_level[f] = level
	_sent_s[f] = _time_s
	_note(
		(
			"dispatch %s (true '%s', loss chance %.3f)"
			% [describe(rider), ReportLevel.NAMES[level], chance]
		)
	)


## A rider not on the field, or null if all are out.
func _free_rider() -> ReportRider:
	for courier: Courier in riders:
		if not courier.is_riding():
			return courier as ReportRider
	return null


func _arrive(rider: ReportRider) -> void:
	arrived.append(Vector4(rider.formation, rider.level, rider.seen_s, _time_s))
	if arrived.size() > SHOWN:
		arrived.remove_at(0)
	_note("arrived %s" % describe(rider))


func _note(line: String) -> void:
	print_verbose("reports: [%.1f s %s] %s" % [_time_s, BattleClock.hhmm(_time_s), line])
