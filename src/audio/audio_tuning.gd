class_name AudioTuning
extends RefCounted
## Loudness, pitch and timing of every sound. All of it is [design guess]:
## nothing in DOCS-design*.md covers sound yet, so these are tuned by ear
## against the --demo-ride recording. Arrays are indexed by gait (GaitTable).

# --- own horse --------------------------------------------------------------
## Hoof strike level per gait, dB: a gallop lands far harder than a walk.
const HOOF_DB: Array[float] = [-80.0, -13.0, -10.0, -9.0, -7.0]
## Base pitch per gait: heavier, lower strikes at speed.
const HOOF_PITCH: Array[float] = [1.0, 1.06, 1.0, 0.94, 0.88]
## Per-strike random spread (+-): no two hooves land alike.
const HOOF_DB_JITTER: float = 2.0
const HOOF_PITCH_JITTER: float = 0.06
## Saddle and bridle leather, once per bounce; trot rattles the most.
const CREAK_DB: Array[float] = [-80.0, -26.0, -18.0, -21.0, -17.0]
const CREAK_PITCH_MIN: float = 0.85
const CREAK_PITCH_MAX: float = 1.1
## A horse below this stamina (or blown) blows and snorts often.
const TIRED_STAMINA: float = 0.3
## Seconds between snorts when tired, halved at the gallop (one breath per
## stride is the most a galloping horse can take).
const TIRED_SNORT_S: Vector2 = Vector2(1.5, 4.0)
const GALLOP_SNORT_FACTOR: float = 0.5
const TIRED_SNORT_DB: float = -6.0
## A relaxed horse at halt or walk still snorts now and then.
const RELAXED_SNORT_S: Vector2 = Vector2(12.0, 35.0)
const RELAXED_SNORT_DB: float = -14.0
## The samples are a person's nose and breath: pitched down towards a horse.
const SNORT_PITCH_MIN: float = 0.68
const SNORT_PITCH_MAX: float = 0.82
## Wind in the rider's ears at full gallop, dB; scales with speed^2 (wind
## noise follows dynamic pressure) and is stopped below WIND_SILENT_LINEAR.
const WIND_DB_AT_GALLOP: float = 13.0
const WIND_SILENT_LINEAR: float = 0.001
const WIND_PITCH_MIN: float = 0.8
const WIND_PITCH_MAX: float = 1.2

# --- battle din -------------------------------------------------------------
const MAX_EMITTERS: int = 16
## Farthest din worth an emitter: a big fight is faint at 1.5-2 km.
const DIN_MAX_DISTANCE_M: float = 2000.0
## Emitter re-selection rate; the din itself plays continuously.
const DIN_UPDATE_S: float = 0.25
## Inverse-distance unit sizes, m: a formation front shouts from ~60 m wide.
const CROWD_UNIT_M: float = 60.0
const CLASH_UNIT_M: float = 30.0
const CROWD_DB: float = 0.0
const CLASH_DB: float = 0.0
const CLASH_DB_JITTER: float = 4.0
const CLASH_PITCH_MIN: float = 0.85
const CLASH_PITCH_MAX: float = 1.15
## Weapon clashes per second from one engaged formation (a Poisson stream).
const CLASH_PER_S: float = 6.0
const CLASH_VOICES: int = 3
## Panic: a routed formation screams higher and louder, no clash of arms.
const ROUTED_DB: float = 4.0
const ROUTED_PITCH: float = 1.15
## Living men for 0 dB of crowd; louder or quieter by 10 log10(share).
const REF_STRENGTH: float = 1000.0
const STRENGTH_SHARE_MIN: float = 0.1
const STRENGTH_SHARE_MAX: float = 3.0
## Emitters sound from head height above the formation centre.
const EMITTER_HEIGHT_M: float = 1.7

# --- couriers ---------------------------------------------------------------
## A courier's hooves are heard to here, in sight or not.
const COURIER_HEAR_M: float = 300.0
const COURIER_UNIT_M: float = 8.0
const COURIER_HOOF_DB: float = -2.0


## Inverse-distance attenuation, no doppler; the engine's distance low-pass
## (attenuation_filter_*) stays on, so far din loses its highs as in air.
static func configure_3d(player: AudioStreamPlayer3D, unit_size: float, max_m: float) -> void:
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = unit_size
	player.max_distance = max_m
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED


## Crowd gain for a formation of `living` men, dB.
static func strength_db(living: int) -> float:
	var share: float = clampf(float(living) / REF_STRENGTH, STRENGTH_SHARE_MIN, STRENGTH_SHARE_MAX)
	return 10.0 * log(share) / log(10.0)
