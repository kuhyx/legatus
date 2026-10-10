class_name SimStats
extends RefCounted
## Timing samples (milliseconds) with the percentiles both benches print.

var _samples: PackedFloat64Array = PackedFloat64Array()


func add(ms: float) -> void:
	var appended: bool = _samples.push_back(ms)
	assert(not appended, "PackedFloat64Array.push_back reports failure as true")


func size() -> int:
	return _samples.size()


## Nearest-rank percentile, p in [0, 1]. 0.0 when there are no samples.
func percentile(p: float) -> float:
	if _samples.is_empty():
		return 0.0
	var sorted: PackedFloat64Array = _samples.duplicate()
	sorted.sort()
	var rank: int = clampi(ceili(p * sorted.size()) - 1, 0, sorted.size() - 1)
	return sorted[rank]


func mean() -> float:
	if _samples.is_empty():
		return 0.0
	var total: float = 0.0
	for s: float in _samples:
		total += s
	return total / _samples.size()


## One line: "label p50=.. p99=.. max=.. mean=.. (n=..)".
func summary(label: String) -> String:
	return (
		"%s p50=%.2f p99=%.2f max=%.2f mean=%.2f (n=%d)"
		% [label, percentile(0.5), percentile(0.99), percentile(1.0), mean(), size()]
	)
