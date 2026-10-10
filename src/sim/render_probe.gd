class_name RenderProbe
extends RefCounted
## Proof that the bench scenes actually drew something: tracks the largest
## per-frame primitive count seen over the run from both the Performance
## monitor and RenderingServer (the RenderingServer figure read 0 on kuhy's
## first Forward+ run while soldiers were on screen). scripts/bench.sh fails
## when both stay 0, so a frame time measured on an empty scene cannot pass.

var max_monitor: int = 0
var max_server: int = 0


func sample() -> void:
	var from_monitor: int = int(
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	)
	var from_server: int = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
	)
	max_monitor = maxi(max_monitor, from_monitor)
	max_server = maxi(max_server, from_server)


func summary() -> String:
	return "primitives max_monitor=%d max_server=%d" % [max_monitor, max_server]
