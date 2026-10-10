class_name CourierAudio
extends Node3D
## Courier riders' hooves, positional, for every courier riding within
## AudioTuning.COURIER_HEAR_M of the general: in sight or not (hearing is not
## seeing). Each galloping courier keeps its own stride clock on the
## GaitTable gallop rate and footfalls; standing at a handoff is silent.

var _couriers: Array[Courier] = []
var _pools: Array[VoicePool] = []
var _strides: PackedFloat64Array = PackedFloat64Array()
var _height: Callable
var _listener: Node3D = null
var _bank: AudioBank = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## `couriers` is CourierService.couriers; `height(x, z) -> float` the ground;
## `listener` where the general hears from; `bank` the samples.
func setup(couriers: Array[Courier], height: Callable, listener: Node3D, bank: AudioBank) -> void:
	name = "CourierAudio"
	_couriers = couriers
	_height = height
	_listener = listener
	_bank = bank
	_rng.seed = couriers.size() * 7919 + 17
	if bank.hooves.is_empty():
		return  # nothing to play: no pools, no work
	if _strides.resize(couriers.size()) != OK:
		push_error("CourierAudio: cannot size the stride clocks")
		return
	for i: int in couriers.size():
		var pool: VoicePool = VoicePool.new(
			2, AudioTuning.COURIER_UNIT_M, AudioTuning.COURIER_HEAR_M
		)
		pool.name = "Courier%d" % i
		_pools.append(pool)
		add_child(pool)
		# Couriers start out of step with each other.
		_strides[i] = _rng.randf()


func _process(delta: float) -> void:
	step(delta)


## Advance every heard courier's stride clock by `delta` seconds.
func step(delta: float) -> void:
	if _pools.is_empty() or _listener == null:
		return
	var ear: Vector3 = _listener.global_position
	var ear_xz: Vector2 = Vector2(ear.x, ear.z)
	var rate: float = GaitTable.STRIDE_HZ[GaitTable.GALLOP]
	var beats: PackedFloat32Array = GaitTable.footfalls(GaitTable.GALLOP)
	for i: int in _couriers.size():
		var courier: Courier = _couriers[i]
		if not galloping(courier):
			continue
		var before: float = _strides[i]
		_strides[i] = before + rate * delta
		if courier.position.distance_to(ear_xz) > AudioTuning.COURIER_HEAR_M:
			continue
		var hits: int = Footfalls.crossed(before, _strides[i], beats)
		if hits <= 0:
			continue
		var p: Vector2 = courier.position
		var ground: float = _height.call(p.x, p.y)
		_pools[i].position = Vector3(p.x, ground + 0.5, p.y)
		for _h: int in mini(hits, Footfalls.MAX_HITS_PER_STEP):
			_pools[i].play(
				AudioBank.pick(_bank.hooves, _rng),
				(
					AudioTuning.COURIER_HOOF_DB
					+ _rng.randf_range(-AudioTuning.HOOF_DB_JITTER, AudioTuning.HOOF_DB_JITTER)
				),
				(
					AudioTuning.HOOF_PITCH[GaitTable.GALLOP]
					+ _rng.randf_range(
						-AudioTuning.HOOF_PITCH_JITTER, AudioTuning.HOOF_PITCH_JITTER
					)
				)
			)


## Riding out or back (a courier at a handoff stands with the formation).
static func galloping(courier: Courier) -> bool:
	return courier.state == Courier.State.OUTBOUND or courier.state == Courier.State.RETURNING


## Hoof strikes played since start, all couriers (tests, debug).
func started() -> int:
	var n: int = 0
	for pool: VoicePool in _pools:
		n += pool.started()
	return n
