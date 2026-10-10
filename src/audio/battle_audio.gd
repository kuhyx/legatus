class_name BattleAudio
extends Node3D
## The battle's din: a fixed pool of AudioTuning.MAX_EMITTERS DinEmitters,
## re-assigned DIN_UPDATE_S times a second to the nearest engaged or routed
## formations (DinSelect: distance only, no sight test). Per frame only the
## clash timers run, so the cost is a few dozen formation getters at 4 Hz.

var emitters: Array[DinEmitter] = []
var _source: FormationSource = null
var _strength: Callable
var _height: Callable
var _listener: Node3D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _update_in: float = 0.0
var _last_active: int = -1


## `source` gives centres / engaged / routed / count; `strength(f) -> int`
## the living men; `height(x, z) -> float` the ground; `listener` is where
## the general hears from (his camera).
func setup(source: FormationSource, strength: Callable, height: Callable, listener: Node3D) -> void:
	_source = source
	_strength = strength
	_height = height
	_listener = listener


## Build the emitter pool from `bank`; `rng_seed` is this node's own (never
## the simulation's).
func build(bank: AudioBank, rng_seed: int) -> void:
	name = "BattleAudio"
	_rng.seed = rng_seed
	if bank.crowd == null and bank.clashes.is_empty():
		return  # nothing to play: no emitters, no work
	for _i: int in AudioTuning.MAX_EMITTERS:
		var emitter: DinEmitter = DinEmitter.new(bank, _rng)
		emitters.append(emitter)
		add_child(emitter)


func _process(delta: float) -> void:
	if emitters.is_empty() or _source == null:
		return
	_update_in -= delta
	if _update_in <= 0.0:
		_update_in = AudioTuning.DIN_UPDATE_S
		update()
	for emitter: DinEmitter in emitters:
		emitter.step(delta)


## Re-pick the formations to voice and move the emitters onto them.
func update() -> void:
	var count: int = _source.formation_count()
	var centres: PackedVector2Array = PackedVector2Array()
	var kinds: PackedByteArray = PackedByteArray()
	var living: PackedInt32Array = PackedInt32Array()
	if centres.resize(count) != OK or kinds.resize(count) != OK or living.resize(count) != OK:
		push_error("BattleAudio: cannot size the formation lists")
		return
	for f: int in count:
		var men: int = _strength.call(f)
		living[f] = men
		centres[f] = _source.center_of(f)
		kinds[f] = DinSelect.kind_of(_source.is_engaged(f), _source.is_routed(f), men)
	var ear: Vector3 = _listener.global_position
	var picked: PackedInt32Array = DinSelect.nearest(
		Vector2(ear.x, ear.z), centres, kinds, emitters.size()
	)
	var free: Array[DinEmitter] = []
	var kept: Dictionary[int, DinEmitter] = {}
	for emitter: DinEmitter in emitters:
		if emitter.formation >= 0 and picked.has(emitter.formation):
			kept[emitter.formation] = emitter
		else:
			emitter.release()
			free.append(emitter)
	for f: int in picked:
		var emitter: DinEmitter = kept.get(f, null)
		if emitter == null:
			emitter = free.pop_back()
		var c: Vector2 = centres[f]
		var ground: float = _height.call(c.x, c.y)
		emitter.assign(
			f, kinds[f], living[f], Vector3(c.x, ground + AudioTuning.EMITTER_HEIGHT_M, c.y)
		)
	if picked.size() != _last_active:
		_last_active = picked.size()
		print_verbose("audio: din emitters %d / %d formations" % [picked.size(), count])


## Emitters voicing a formation now.
func active_count() -> int:
	var n: int = 0
	for emitter: DinEmitter in emitters:
		n += 1 if emitter.formation >= 0 else 0
	return n
