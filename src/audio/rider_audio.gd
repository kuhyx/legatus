class_name RiderAudio
extends Node
## What the general hears of his own horse and ride, non-positional (he sits
## on it): a hoof strike on every footfall of the stride clock, the saddle
## creaking once per bounce, snorts and blowing when the horse is tired, and
## wind rising with speed^2. Also the M key: mute everything (Master bus).
##
## Reads HorseMotion only, never writes it. Random variation comes from this
## node's own RandomNumberGenerator, never from the simulation's.

const BUS_MASTER: int = 0

var motion: HorseMotion = null
var bank: AudioBank = null
var hooves: VoicePool = null
var creaks: VoicePool = null
var snorts: VoicePool = null
var wind: AudioStreamPlayer = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_stride: float = 0.0
var _primed: bool = false
var _snort_in: float = 0.0


func _init(horse: HorseMotion, sounds: AudioBank, rng_seed: int = 1) -> void:
	name = "RiderAudio"
	motion = horse
	bank = sounds
	_rng.seed = rng_seed
	hooves = VoicePool.new(4)
	hooves.name = "Hooves"
	creaks = VoicePool.new(2)
	creaks.name = "Creaks"
	snorts = VoicePool.new(1)
	snorts.name = "Snorts"
	wind = AudioStreamPlayer.new()
	wind.name = "Wind"
	wind.stream = bank.wind
	_snort_in = _next_snort_s()


func _ready() -> void:
	GeneralInput.ensure_actions()
	for child: Node in [hooves, creaks, snorts, wind]:
		add_child(child)


func _physics_process(delta: float) -> void:
	step(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(GeneralInput.MUTE):
		print_verbose("audio: muted %s" % toggle_mute())


## Mute or unmute every sound; returns the new muted state.
static func toggle_mute() -> bool:
	var muted: bool = not AudioServer.is_bus_mute(BUS_MASTER)
	AudioServer.set_bus_mute(BUS_MASTER, muted)
	return muted


## One physics step: read the horse after HorseMotion.step has run.
func step(delta: float) -> void:
	var now: float = Footfalls.position(motion)
	if _primed:
		_play_beats(_last_stride, now)
	_last_stride = now
	_primed = true
	_step_snorts(delta)
	_step_wind()


func _play_beats(before: float, now: float) -> void:
	var gait: int = motion.gait
	var share: float = motion.speed_share()
	var hits: int = Footfalls.crossed(before, now, GaitTable.footfalls(gait))
	for _i: int in mini(hits, Footfalls.MAX_HITS_PER_STEP):
		hooves.play(
			AudioBank.pick(bank.hooves, _rng),
			AudioTuning.HOOF_DB[gait] + linear_to_db(share) + _jitter(AudioTuning.HOOF_DB_JITTER),
			AudioTuning.HOOF_PITCH[gait] + _jitter(AudioTuning.HOOF_PITCH_JITTER)
		)
	var sits: int = Footfalls.crossed(before, now, Footfalls.saddle_beats(gait))
	if sits > 0:
		creaks.play(
			AudioBank.pick(bank.creaks, _rng),
			AudioTuning.CREAK_DB[gait] + linear_to_db(share),
			_rng.randf_range(AudioTuning.CREAK_PITCH_MIN, AudioTuning.CREAK_PITCH_MAX)
		)


func _step_snorts(delta: float) -> void:
	_snort_in -= delta
	if _tired():
		# Blown just now: do not sit out the rest of a relaxed wait.
		_snort_in = minf(_snort_in, AudioTuning.TIRED_SNORT_S.y)
	if _snort_in > 0.0:
		return
	_snort_in = _next_snort_s()
	var gain: float = AudioTuning.TIRED_SNORT_DB if _tired() else AudioTuning.RELAXED_SNORT_DB
	# A relaxed horse snorts at rest, not while working at a trot or faster.
	if _tired() or motion.gait <= GaitTable.WALK:
		snorts.play(
			AudioBank.pick(bank.snorts, _rng),
			gain,
			_rng.randf_range(AudioTuning.SNORT_PITCH_MIN, AudioTuning.SNORT_PITCH_MAX)
		)


func _next_snort_s() -> float:
	if not _tired():
		return _rng.randf_range(AudioTuning.RELAXED_SNORT_S.x, AudioTuning.RELAXED_SNORT_S.y)
	var wait: float = _rng.randf_range(AudioTuning.TIRED_SNORT_S.x, AudioTuning.TIRED_SNORT_S.y)
	return wait * (AudioTuning.GALLOP_SNORT_FACTOR if motion.gait == GaitTable.GALLOP else 1.0)


func _tired() -> bool:
	return motion.exhausted or motion.stamina < AudioTuning.TIRED_STAMINA


## Wind noise ~ speed^2, silent (stopped) at a halt.
func _step_wind() -> void:
	if wind.stream == null:
		return
	var share: float = clampf(motion.speed / GaitTable.speed(GaitTable.GALLOP), 0.0, 1.0)
	var level: float = share * share
	if level < AudioTuning.WIND_SILENT_LINEAR:
		if wind.playing:
			wind.stop()
		return
	wind.volume_db = AudioTuning.WIND_DB_AT_GALLOP + linear_to_db(level)
	wind.pitch_scale = lerpf(AudioTuning.WIND_PITCH_MIN, AudioTuning.WIND_PITCH_MAX, share)
	if not wind.playing:
		wind.play(_rng.randf_range(0.0, wind.stream.get_length()))


func _jitter(spread: float) -> float:
	return _rng.randf_range(-spread, spread)
