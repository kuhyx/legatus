class_name GaitTable
extends RefCounted
## Horse and rider constants for the general.
##
## Source: DOCS-design.md numbers table (rows cited per constant). Rows the
## table marks [design] / [design guess] are game choices, not history.
##
## Gaits are plain ints, not an enum: shifting is `gait + 1`, and assigning an
## int back to an enum-typed var is a warning (= error in this project).

const HALT: int = 0
const WALK: int = 1
const TROT: int = 2
const CANTER: int = 3
const GALLOP: int = 4
const GAIT_COUNT: int = 5
const GAIT_NAMES: Array[String] = ["halt", "walk", "trot", "canter", "gallop"]

## Rider eye height: withers 1.4 m + ~0.9 m seated (DOCS-design.md numbers
## table, "Rider eye height above ground" [design]).
const EYE_HEIGHT_M: float = 2.3

## Steady-state ground speed per gait, m/s (index = gait). DOCS-design.md
## numbers table, "Horse walk/trot/canter/gallop": walk 1.9, trot 3.6, canter
## 4.4-7.5 (6.0 picked), gallop 11-13 (12.0 picked).
const SPEED_MPS: Array[float] = [0.0, 1.9, 3.6, 6.0, 12.0]

## Speed change limits between gaits, m/s^2 [design guess, not in the table].
## Braking is harder than urging on.
const ACCEL_MPS2: float = 2.0
const DECEL_MPS2: float = 3.0

## Yaw rate per gait, rad/s [design guess]: a galloping horse cannot pivot
## like a walking one.
const TURN_RATE_RAD_S: Array[float] = [0.9, 0.9, 0.7, 0.55, 0.4]

## Stamina is 0..1. Gallop drains it to zero in GALLOP_ENDURANCE_S seconds:
## 300 s = 5 min = 3.6 km at 12 m/s (DOCS-design.md numbers table, "Sustainable
## gallop": 3.2-4 km, ~4-6 min, then a walk to recover). Once exhausted the
## horse drops to canter and refuses to gallop until stamina is back to
## GALLOP_RESUME_STAMINA.
const STAMINA_MAX: float = 1.0
const GALLOP_ENDURANCE_S: float = 300.0
const GALLOP_RESUME_STAMINA: float = 0.3
## Stamina regained per second at each gait [design guess]: a walk gets a
## blown horse galloping again in 90 s. Canter is neutral: the table gives it
## ~11 km (~30 min), longer than any fight. Gallop entry unused (see above).
const STAMINA_RATE_PER_S: Array[float] = [0.005, 0.0033, 0.001, 0.0, 0.0]

## Head bob [design guess]: vertical amplitude (m).
const BOB_AMPLITUDE_M: Array[float] = [0.0, 0.015, 0.05, 0.035, 0.06]

## Stride clock [design guess]: full leg cycles per second per gait. One
## clock drives the bob, the horse's head nod and the hoof sounds, so they
## cannot drift apart. The rider bounces twice per stride at walk and trot
## (each diagonal / lateral push), once at canter and gallop (the suspension).
const STRIDE_HZ: Array[float] = [0.0, 0.9, 1.3, 1.9, 2.3]
const BOUNCES_PER_STRIDE: Array[int] = [0, 2, 2, 1, 1]
## Hoof strikes as stride-phase offsets (0..1) [design guess]: walk 4 even
## beats, trot 2 diagonal pairs, canter 3 beats then suspension, gallop 4
## beats bunched before the suspension.
const FOOTFALLS: Array[Array] = [
	[],
	[0.0, 0.25, 0.5, 0.75],
	[0.0, 0.5],
	[0.0, 0.2, 0.4],
	[0.0, 0.1, 0.25, 0.35],
]

## Rider neck + torso twist in the saddle, radians [design guess].
const NECK_YAW_LIMIT_RAD: float = deg_to_rad(110.0)
const NECK_PITCH_UP_RAD: float = deg_to_rad(50.0)
const NECK_PITCH_DOWN_RAD: float = deg_to_rad(-60.0)


static func speed(gait: int) -> float:
	return SPEED_MPS[clampi(gait, HALT, GALLOP)]


static func turn_rate(gait: int) -> float:
	return TURN_RATE_RAD_S[clampi(gait, HALT, GALLOP)]


## Hoof-strike stride phases for a gait (empty at halt).
static func footfalls(gait: int) -> PackedFloat32Array:
	return PackedFloat32Array(FOOTFALLS[clampi(gait, HALT, GALLOP)])


static func gallop_drain_per_s() -> float:
	return STAMINA_MAX / GALLOP_ENDURANCE_S
