class_name ReportLevel
extends RefCounted
## What an officer says about his formation (DOCS-design-perception.md §4):
## holding / engaged / hard pressed / breaking, or falling back while a
## withdraw order is being carried out. Cohesion comes first: a block out of
## contact but badly shaken (just rallied, just pulled out of the melee) is
## still hard pressed or breaking [design]. A shaken officer over-reports
## danger by one step (engaged -> hard pressed, hard pressed -> breaking),
## not always: the chance rises as cohesion falls (overstate_chance), so
## every level still reaches the general and "breaking" may be inflated
## (§4; thresholds [design guess]).

const HOLDING: int = 0
const ENGAGED: int = 1
const HARD_PRESSED: int = 2
const BREAKING: int = 3
const FALLING_BACK: int = 4
const NAMES: PackedStringArray = ["holding", "engaged", "hard pressed", "breaking", "falling back"]

const HARD_PRESSED_BELOW: float = 0.4
const BREAKING_BELOW: float = 0.15
## Below this cohesion an officer may overstate; at 0 he always does.
const SHAKEN_BELOW: float = 0.5


## The formation's true level. A withdrawing formation reports only that it
## is falling back, whatever its state [design].
static func actual(engaged: bool, cohesion: float, withdrawing: bool) -> int:
	if withdrawing:
		return FALLING_BACK
	if cohesion < BREAKING_BELOW:
		return BREAKING
	if cohesion < HARD_PRESSED_BELOW:
		return HARD_PRESSED
	if engaged:
		return ENGAGED
	return HOLDING


## Chance an officer at `cohesion` overstates by one step:
## (SHAKEN_BELOW - cohesion) / SHAKEN_BELOW, clamped (0.2 at 0.4, 0.7 at 0.15).
static func overstate_chance(cohesion: float) -> float:
	return clampf((SHAKEN_BELOW - cohesion) / SHAKEN_BELOW, 0.0, 1.0)


## What the officer says for true `level` at `cohesion`, given a uniform
## `roll` in [0, 1): one step up if roll < overstate_chance. Only engaged and
## hard pressed can be overstated.
static func stated(level: int, cohesion: float, roll: float) -> int:
	if level != ENGAGED and level != HARD_PRESSED:
		return level
	if roll < overstate_chance(cohesion):
		return level + 1
	return level
