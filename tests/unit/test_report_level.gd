extends GutTest
## ReportLevel: the true level (cohesion first, falling back while withdrawing)
## and the shaken officer's one-step overstatement, a roll whose chance rises
## as cohesion falls.


func test_true_levels() -> void:
	assert_eq(ReportLevel.actual(false, 1.0, false), ReportLevel.HOLDING)
	assert_eq(ReportLevel.actual(true, 0.8, false), ReportLevel.ENGAGED)
	assert_eq(ReportLevel.actual(true, 0.39, false), ReportLevel.HARD_PRESSED)
	assert_eq(ReportLevel.actual(true, 0.1, false), ReportLevel.BREAKING)


func test_cohesion_comes_before_contact() -> void:
	assert_eq(ReportLevel.actual(false, 0.3, false), ReportLevel.HARD_PRESSED, "just rallied")
	assert_eq(ReportLevel.actual(false, 0.1, false), ReportLevel.BREAKING)


func test_withdrawing_only_falls_back() -> void:
	assert_eq(ReportLevel.actual(true, 0.1, true), ReportLevel.FALLING_BACK)
	assert_eq(ReportLevel.actual(false, 1.0, true), ReportLevel.FALLING_BACK)


func test_overstate_chance_rises_as_cohesion_falls() -> void:
	assert_eq(ReportLevel.overstate_chance(0.8), 0.0, "steady officer")
	assert_eq(ReportLevel.overstate_chance(0.5), 0.0)
	assert_almost_eq(ReportLevel.overstate_chance(0.4), 0.2, 1e-6)
	assert_almost_eq(ReportLevel.overstate_chance(0.15), 0.7, 1e-6)
	assert_eq(ReportLevel.overstate_chance(0.0), 1.0)


func test_stated_steps_up_only_below_the_chance() -> void:
	# Hard pressed at 0.3: chance 0.4.
	assert_eq(ReportLevel.stated(ReportLevel.HARD_PRESSED, 0.3, 0.39), ReportLevel.BREAKING)
	assert_eq(ReportLevel.stated(ReportLevel.HARD_PRESSED, 0.3, 0.41), ReportLevel.HARD_PRESSED)
	# Engaged at 0.45: chance 0.1.
	assert_eq(ReportLevel.stated(ReportLevel.ENGAGED, 0.45, 0.05), ReportLevel.HARD_PRESSED)
	assert_eq(ReportLevel.stated(ReportLevel.ENGAGED, 0.45, 0.5), ReportLevel.ENGAGED)


func test_true_hard_pressed_can_still_be_reported() -> void:
	# The fixed-threshold bias read every true "hard pressed" as "breaking".
	var honest: int = 0
	for i: int in 100:
		var said: int = ReportLevel.stated(ReportLevel.HARD_PRESSED, 0.35, (i + 0.5) / 100.0)
		honest += 1 if said == ReportLevel.HARD_PRESSED else 0
	assert_eq(honest, 70, "chance 0.3 at cohesion 0.35")


func test_other_levels_are_never_overstated() -> void:
	for level: int in [ReportLevel.HOLDING, ReportLevel.BREAKING, ReportLevel.FALLING_BACK]:
		assert_eq(ReportLevel.stated(level, 0.0, 0.0), level)
