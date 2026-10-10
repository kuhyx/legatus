class_name OrderLog
extends RefCounted
## The general's own list of the orders he sent (HUD text, Decision 8):
## "08:02 block 12: withdraw — sent", then "— acknowledged 08:06" or "— found
## them broken 08:06" once the courier is back. Nothing more: a lost courier never
## returns, and an ignored order is acknowledged all the same, so the player
## learns the rest by watching (DOCS-design-command.md §3). Answered entries
## leave ANSWERED_KEEP_S after the answer; unanswered ones stay until newer
## orders push them out of the last LIMIT [design guess].

enum Answer { NONE, ACKNOWLEDGED, BROKEN }

const LIMIT: int = 6
const ANSWERED_KEEP_S: float = 60.0

var entries: Array[Entry] = []


## One sent order.
class Entry:
	extends RefCounted
	var ticket: int = -1
	var formation: int = -1
	var order: int = -1
	var sent_s: float = 0.0
	var reply: Answer = Answer.NONE
	var reply_s: float = 0.0


func add(ticket: int, formation: int, order: int, now_s: float) -> void:
	var entry: Entry = Entry.new()
	entry.ticket = ticket
	entry.formation = formation
	entry.order = order
	entry.sent_s = now_s
	entries.append(entry)
	if entries.size() > LIMIT:
		entries.remove_at(0)


## The courier with `ticket` is back with `kind`; false if the entry has
## already been pushed out of the list.
func answer(ticket: int, kind: Answer, now_s: float) -> bool:
	for entry: Entry in entries:
		if entry.ticket == ticket:
			entry.reply = kind
			entry.reply_s = now_s
			return true
	return false


## Drop answered entries older than ANSWERED_KEEP_S.
func prune(now_s: float) -> void:
	for i: int in range(entries.size() - 1, -1, -1):
		var entry: Entry = entries[i]
		if entry.reply != Answer.NONE and now_s - entry.reply_s > ANSWERED_KEEP_S:
			entries.remove_at(i)


## HUD lines, oldest first.
func lines() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for entry: Entry in entries:
		var status: String = "sent"
		if entry.reply == Answer.ACKNOWLEDGED:
			status = "acknowledged " + BattleClock.hhmm(entry.reply_s)
		elif entry.reply == Answer.BROKEN:
			status = "found them broken " + BattleClock.hhmm(entry.reply_s)
		var line: String = (
			"%s block %d: %s — %s"
			% [
				BattleClock.hhmm(entry.sent_s),
				entry.formation,
				BattleCommand.ORDER_NAMES[entry.order],
				status,
			]
		)
		# append() returns true on failure.
		if out.append(line):
			push_error("OrderLog: cannot build the HUD lines")
	return out
