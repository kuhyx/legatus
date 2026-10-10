class_name BattleHud
extends RefCounted
## The HUD text (Decision 8: text, no map or unit readouts): the general's
## own horse, the battle clock (BattleClock), the last command note, the
## orders he sent and what came back (OrderLog), and the officers' reports
## that reached him (ReportService), each stamped hh:mm of sim time.


## `debug` is an extra line for `--debug` runs, empty otherwise.
static func compose(motion: HorseMotion, command: BattleCommand, debug: String) -> String:
	var text: String = (
		"gait: %s  speed: %.1f m/s  stamina: %d%%%s"
		% [
			GaitTable.GAIT_NAMES[motion.gait],
			motion.speed,
			roundi(motion.stamina * 100.0),
			"  (blown)" if motion.exhausted else "",
		]
	)
	text += "\n" + BattleClock.hhmm(command.time_s)
	if not command.note.is_empty():
		text += "\n" + command.note
	text += _section("orders", command.orders.lines())
	text += _section("reports", command.reports.lines())
	if not debug.is_empty():
		text += "\n" + debug
	return text


static func _section(title: String, lines: PackedStringArray) -> String:
	if lines.is_empty():
		return ""
	return "\n%s:\n  %s" % [title, "\n  ".join(lines)]
