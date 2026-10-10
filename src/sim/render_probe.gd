class_name RenderProbe
extends RefCounted
## What the bench scenes really cost, independent of how frames are presented.
## - Primitives: the largest per-frame count over the run from both the
##   Performance monitor and RenderingServer; scripts/bench*.sh fail when both
##   stay 0, so a frame time measured on an empty scene cannot pass.
## - GPU time per frame from the viewport's own render-time measurement
##   (informational; the gate is the frame delta).

var max_monitor: int = 0
var max_server: int = 0
var gpu_ms: SimStats = SimStats.new()
var _viewport: RID


## Start measuring render time on `viewport` (call once from _ready).
func watch(viewport: Viewport) -> void:
	_viewport = viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport, true)


## Sample once per frame; `counted` false during warm-up.
func sample(counted: bool = true) -> void:
	var from_monitor: int = int(
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	)
	var from_server: int = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
	)
	max_monitor = maxi(max_monitor, from_monitor)
	max_server = maxi(max_server, from_server)
	if not counted or not _viewport.is_valid():
		return
	gpu_ms.add(RenderingServer.viewport_get_measured_render_time_gpu(_viewport))


func summary() -> String:
	return (
		"primitives max_monitor=%d max_server=%d\n%s"
		% [max_monitor, max_server, gpu_ms.summary("gpu_ms")]
	)
