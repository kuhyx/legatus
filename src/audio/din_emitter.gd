class_name DinEmitter
extends Node3D
## The noise of one formation: a crowd loop (shouting while engaged, panic
## while routed) and, while engaged, a random stream of weapon clashes.
## BattleAudio moves it between formations; while it keeps its formation the
## loop is never restarted (a restart clicks).

## Formation it voices, -1 when free.
var formation: int = -1
var kind: int = DinSelect.SILENT
var crowd: AudioStreamPlayer3D = null
var clashes: VoicePool = null
var _bank: AudioBank = null
var _rng: RandomNumberGenerator = null
var _clash_in: float = 0.0


func _init(sounds: AudioBank, rng: RandomNumberGenerator) -> void:
	name = "Din"
	_bank = sounds
	_rng = rng
	crowd = AudioStreamPlayer3D.new()
	crowd.name = "Crowd"
	AudioTuning.configure_3d(crowd, AudioTuning.CROWD_UNIT_M, AudioTuning.DIN_MAX_DISTANCE_M)
	crowd.stream = sounds.crowd
	add_child(crowd)
	clashes = VoicePool.new(
		AudioTuning.CLASH_VOICES, AudioTuning.CLASH_UNIT_M, AudioTuning.DIN_MAX_DISTANCE_M
	)
	add_child(clashes)


## Voice formation `f` (kind `what`, `living` men) standing at `at`.
func assign(f: int, what: int, living: int, at: Vector3) -> void:
	position = at
	var fresh: bool = f != formation
	formation = f
	kind = what
	var routed: bool = what == DinSelect.ROUTED
	crowd.volume_db = (
		AudioTuning.CROWD_DB
		+ AudioTuning.strength_db(living)
		+ (AudioTuning.ROUTED_DB if routed else 0.0)
	)
	crowd.pitch_scale = AudioTuning.ROUTED_PITCH if routed else 1.0
	if crowd.stream != null and (fresh or not crowd.playing):
		# A random start, so emitters on one loop never phase-lock.
		crowd.play(_rng.randf_range(0.0, crowd.stream.get_length()))
	if fresh:
		_clash_in = _next_clash_s()


func release() -> void:
	formation = -1
	kind = DinSelect.SILENT
	crowd.stop()


## Advance the clash stream by `delta` seconds.
func step(delta: float) -> void:
	if kind != DinSelect.ENGAGED or _bank.clashes.is_empty():
		return
	_clash_in -= delta
	# A long frame (a hitch) must not burst every clash it skipped.
	_clash_in = maxf(_clash_in, -1.0 / AudioTuning.CLASH_PER_S)
	while _clash_in <= 0.0:
		clashes.play(
			AudioBank.pick(_bank.clashes, _rng),
			(
				AudioTuning.CLASH_DB
				+ _rng.randf_range(-AudioTuning.CLASH_DB_JITTER, AudioTuning.CLASH_DB_JITTER)
			),
			_rng.randf_range(AudioTuning.CLASH_PITCH_MIN, AudioTuning.CLASH_PITCH_MAX)
		)
		_clash_in += _next_clash_s()


## Exponential wait: clashes arrive as a Poisson stream of CLASH_PER_S.
func _next_clash_s() -> float:
	return -log(maxf(_rng.randf(), 1e-6)) / AudioTuning.CLASH_PER_S


func is_sounding() -> bool:
	return crowd.playing or clashes.playing_count() > 0
