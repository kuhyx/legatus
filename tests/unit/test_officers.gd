extends GutTest
## Officers: each officer's ignore chance in [ignore_min, ignore_max], his
## rolls on a stream of his own (seed, formation, orders so far), replayable.

const COUNT: int = 400


func _officers(rng_seed: int) -> Officers:
	return Officers.new(COUNT, CourierSettings.new(), rng_seed)


func test_chances_lie_in_the_table_range() -> void:
	var officers: Officers = _officers(7)
	var settings: CourierSettings = CourierSettings.new()
	for c: float in officers.chances:
		assert_between(c, settings.ignore_min, settings.ignore_max)


func test_same_seed_same_rolls() -> void:
	var a: Officers = _officers(7)
	var b: Officers = _officers(7)
	for f: int in COUNT:
		assert_eq(a.ignores(f), b.ignores(f), "formation %d" % f)


func test_first_orders_are_not_all_ignored() -> void:
	# One shared RNG gave every officer the same first roll: with the default
	# seed the battle's first order was ignored every time.
	var officers: Officers = _officers(hash([7, 1]))
	var ignored: int = 0
	var expected: float = 0.0
	for f: int in COUNT:
		ignored += 1 if officers.ignores(f) else 0
		expected += officers.chances[f]
	assert_between(float(ignored), expected - 40.0, expected + 40.0, "~17.5 % of first orders")


func test_an_officers_rolls_do_not_depend_on_other_orders() -> void:
	var quiet: Officers = _officers(3)
	var busy: Officers = _officers(3)
	var others_ignored: int = 0
	for _i: int in 50:
		others_ignored += 1 if busy.ignores(0) else 0
	assert_lt(others_ignored, 50, "formation 0 rolled 50 times")
	for _i: int in 20:
		assert_eq(busy.ignores(1), quiet.ignores(1))


func test_successive_orders_roll_afresh() -> void:
	var officers: Officers = _officers(5)
	var ignored: int = 0
	for _i: int in COUNT:
		ignored += 1 if officers.ignores(0) else 0
	var expected: float = officers.chances[0] * COUNT
	assert_between(float(ignored), expected - 40.0, expected + 40.0)


func test_unknown_formation_never_ignores() -> void:
	var officers: Officers = _officers(1)
	assert_false(officers.ignores(-1))
	assert_false(officers.ignores(COUNT))
