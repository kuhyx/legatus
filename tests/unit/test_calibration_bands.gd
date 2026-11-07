extends GutTest
## CalibrationBands: the per-seed band check behind the 5-seed regression
## test (DOCS-design-army §4: loser killed 14-16 %, winner 4-5 %, the
## loser's median break losses <= 10 %). Lines as calibrate_morale.gd prints.

const IN_BAND: String = (
	"result loser=0 loser_killed=14.37" + " winner_killed=4.51 loser_break_median=4.29"
)


func test_parses_the_result_line() -> void:
	var r: Dictionary = CalibrationBands.parse(IN_BAND)
	var want: Dictionary = {
		"loser": 0.0, "loser_killed": 14.37, "winner_killed": 4.51, "loser_break_median": 4.29
	}
	assert_eq(r, want)


func test_finds_the_result_line_in_a_log() -> void:
	var log_text: String = "tuning: {}\nt 60.0s | s0 dead 0.1%%\n%s\n" % IN_BAND
	assert_eq(CalibrationBands.result_line(log_text), IN_BAND)
	assert_eq(CalibrationBands.result_line("no result here\n"), "")


func test_a_seed_in_band_has_no_failures() -> void:
	assert_eq(CalibrationBands.failures(2, IN_BAND), PackedStringArray())


## Seed 1 on main (DOCS-calibration-log): both sides collapse.
func test_out_of_band_names_the_seed_and_each_field() -> void:
	var line: String = "result loser=1 loser_killed=13.50 winner_killed=10.20 loser_break_median=4.00"
	var out: PackedStringArray = CalibrationBands.failures(1, line)
	assert_eq(out.size(), 2)
	assert_eq(out[0], "seed 1: loser killed 13.50 % outside 14-16 %")
	assert_eq(out[1], "seed 1: winner killed 10.20 % outside 4-5 %")


## Seed 2 on main: the all-or-nothing cascade, winner too unhurt.
func test_winner_too_unhurt_fails() -> void:
	var line: String = "result loser=0 loser_killed=16.20 winner_killed=2.40 loser_break_median=6.00"
	assert_eq(
		CalibrationBands.failures(2, line),
		PackedStringArray(
			[
				"seed 2: loser killed 16.20 % outside 14-16 %",
				"seed 2: winner killed 2.40 % outside 4-5 %",
			]
		)
	)


func test_late_breaks_fail() -> void:
	var line: String = "result loser=0 loser_killed=15.00 winner_killed=4.50 loser_break_median=12.50"
	assert_eq(
		CalibrationBands.failures(3, line),
		PackedStringArray(["seed 3: loser break losses 12.50 % outside 0-10 %"])
	)


func test_band_edges_are_inside() -> void:
	var line: String = "result loser=0 loser_killed=16.00 winner_killed=4.00 loser_break_median=10.00"
	assert_eq(CalibrationBands.failures(4, line), PackedStringArray())


func test_a_missing_result_line_fails() -> void:
	assert_eq(
		CalibrationBands.failures(5, ""),
		PackedStringArray(["seed 5: no result line (the run crashed or timed out)"])
	)
