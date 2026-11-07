class_name CalibrationBands
extends RefCounted
## Per-seed morale bands (DOCS-design-army §4) over calibrate_morale.gd's
## `result ...` line. scripts/calibrate.sh gates medians; this, every seed.

const BANDS: Array[Array] = [
	["loser_killed", "loser killed", 14.0, 16.0],
	["winner_killed", "winner killed", 4.0, 5.0],
	["loser_break_median", "loser break losses", 0.0, 10.0],
]
const PREFIX: String = "result "


static func result_line(log_text: String) -> String:
	for line: String in log_text.split("\n"):
		if line.begins_with(PREFIX):
			return line.strip_edges()
	return ""


static func parse(line: String) -> Dictionary:
	var out: Dictionary = {}
	for pair: String in line.trim_prefix(PREFIX).split(" ", false):
		var kv: PackedStringArray = pair.split("=")
		if kv.size() == 2 and kv[1].is_valid_float():
			out[kv[0]] = kv[1].to_float()
	return out


## One message per band the seed misses; empty = in band.
static func failures(seed: int, line: String) -> PackedStringArray:
	var out: Array[String] = []
	var r: Dictionary = parse(line)
	if r.is_empty():
		out.append("seed %d: no result line (the run crashed or timed out)" % seed)
		return PackedStringArray(out)
	for band: Array in BANDS:
		var low: float = band[2]
		var high: float = band[3]
		if not r.has(band[0]):
			out.append("seed %d: %s missing from the result line" % [seed, band[1]])
			continue
		var value: float = r[band[0]]
		if value < low or value > high:
			out.append("seed %d: %s %.2f %% outside %d-%d %%" % [seed, band[1], value, low, high])
	return PackedStringArray(out)
