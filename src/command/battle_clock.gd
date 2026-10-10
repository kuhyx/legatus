class_name BattleClock
extends RefCounted
## The battle-day clock the HUD shows: sim seconds since the battle began, as
## hh:mm from START_HOUR (battle-day morning, Decision 3; the hour is a
## [design guess]). Sim time, never wall time (Decision 4).

const START_HOUR: int = 8


static func hhmm(sim_s: float) -> String:
	var minutes: int = START_HOUR * 60 + floori(maxf(sim_s, 0.0) / 60.0)
	return "%02d:%02d" % [floori(minutes / 60.0) % 24, minutes % 60]
