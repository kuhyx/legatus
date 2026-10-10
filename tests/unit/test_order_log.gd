extends GutTest
## OrderLog: the general's list of sent orders and what came back.


func test_sent_then_acknowledged() -> void:
	var log: OrderLog = OrderLog.new()
	log.add(0, 12, OrderInput.WITHDRAW, 120.0)
	assert_eq(log.lines(), PackedStringArray(["08:02 block 12: withdraw — sent"]))
	assert_true(log.answer(0, OrderLog.Answer.ACKNOWLEDGED, 360.0))
	assert_eq(log.lines(), PackedStringArray(["08:02 block 12: withdraw — acknowledged 08:06"]))


func test_found_broken_carries_its_time() -> void:
	var log: OrderLog = OrderLog.new()
	log.add(3, 16, OrderInput.HOLD, 200.0)
	assert_true(log.answer(3, OrderLog.Answer.BROKEN, 453.0))
	assert_eq(log.lines(), PackedStringArray(["08:03 block 16: hold — found them broken 08:07"]))


func test_answered_entries_leave_after_the_keep_time() -> void:
	var log: OrderLog = OrderLog.new()
	log.add(0, 1, OrderInput.HOLD, 0.0)
	log.add(1, 2, OrderInput.HOLD, 0.0)
	assert_true(log.answer(0, OrderLog.Answer.ACKNOWLEDGED, 100.0))
	log.prune(100.0 + OrderLog.ANSWERED_KEEP_S)
	assert_eq(log.entries.size(), 2, "kept for exactly the keep time")
	log.prune(100.1 + OrderLog.ANSWERED_KEEP_S)
	assert_eq(log.entries.size(), 1)
	assert_eq(log.entries[0].ticket, 1, "an unanswered order stays")


func test_only_the_last_orders_are_listed() -> void:
	var log: OrderLog = OrderLog.new()
	for t: int in OrderLog.LIMIT + 2:
		log.add(t, t, OrderInput.ADVANCE, float(t))
	assert_eq(log.entries.size(), OrderLog.LIMIT)
	assert_eq(log.entries[0].ticket, 2, "oldest pushed out")
	assert_false(log.answer(0, OrderLog.Answer.ACKNOWLEDGED, 10.0), "answer to a dropped entry")
