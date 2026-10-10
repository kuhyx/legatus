extends Node3D
## Gate 2 scene (scenes/bench/bench.tscn): the BenchScenario battle rendered
## from a rider's eye (2.5 m) at the end of the engaged line, looking down it.
## Fixed 20 Hz sim tick with render interpolation; quits after `--seconds=N`
## (default 30) and prints frame and tick percentiles. `--no-lod` draws the
## full soldier everywhere. `--screenshot=PATH` saves the last frame as PNG.
## Frames in the first second are not counted.

const WARMUP_SEC: float = 1.0
const MAX_CATCH_UP: int = 3

var _sim: BattleSim
var _army: ArmyRenderer
var _camera: Camera3D
var _seconds: float = 30.0
var _elapsed: float = 0.0
var _accum: float = 0.0
var _frame_ms: SimStats = SimStats.new()
var _tick_ms: SimStats = SimStats.new()
var _threads: SimStats = SimStats.new()
var _draw_ms: SimStats = SimStats.new()
var _start_alive: int = 0
var _probe: RenderProbe = RenderProbe.new()


func _ready() -> void:
	_seconds = BenchScenario.arg("seconds", "30").to_float()
	_sim = BenchScenario.create()
	_start_alive = _sim.get_alive(0) + _sim.get_alive(1)
	_build_world()
	_army = ArmyRenderer.new()
	add_child(_army)
	if BenchScenario.arg("no-lod", "false") == "true":
		_army.near_distance = 0.0
	_army.setup(_sim, BenchScenario.bounds())


func _build_world() -> void:
	var half: float = BenchScenario.FRONTAGE * 0.5
	_camera = Camera3D.new()
	_camera.far = 4000.0
	add_child(_camera)
	_camera.look_at_from_position(Vector3(-half - 6.0, 2.5, -3.0), Vector3(half, 1.2, 0.0))
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	add_child(sun)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(4000.0, 4000.0)
	var soil: StandardMaterial3D = StandardMaterial3D.new()
	soil.albedo_color = Color(0.36, 0.42, 0.22)
	plane.material = soil
	ground.mesh = plane
	add_child(ground)


func _process(delta: float) -> void:
	_elapsed += delta
	_probe.sample()
	if _elapsed > WARMUP_SEC:
		_frame_ms.add(delta * 1000.0)
	_accum += delta
	var steps: int = 0
	while _accum >= BenchScenario.TICK_DT and steps < MAX_CATCH_UP:
		_sim.tick(BenchScenario.TICK_DT)
		_tick_ms.add(_sim.get_last_tick_usec() / 1000.0)
		_threads.add(_sim.get_last_tick_threads())
		_accum -= BenchScenario.TICK_DT
		steps += 1
	_accum = minf(_accum, BenchScenario.TICK_DT)
	var draw_start: int = Time.get_ticks_usec()
	_army.draw(_accum / BenchScenario.TICK_DT, _camera.global_position)
	_draw_ms.add((Time.get_ticks_usec() - draw_start) / 1000.0)
	if _elapsed >= _seconds:
		_report()
		_save_screenshot(BenchScenario.arg("screenshot", ""))
		get_tree().quit()


func _save_screenshot(path: String) -> void:
	if path.is_empty():
		return
	var err: Error = get_viewport().get_texture().get_image().save_png(path)
	print("screenshot %s: %s" % [path, error_string(err)])


func _report() -> void:
	var alive: int = _sim.get_alive(0) + _sim.get_alive(1)
	print(
		(
			"bench: soldiers=%d seconds=%.1f lod_near=%.0fm"
			% [_sim.get_count(), _elapsed, _army.near_distance]
		)
	)
	print("alive: start=%d end=%d casualties=%d" % [_start_alive, alive, _start_alive - alive])
	print(_frame_ms.summary("frame_ms"))
	print(_tick_ms.summary("tick_ms"))
	print(_threads.summary("threads_per_tick"))
	print(_draw_ms.summary("fill_upload_ms"))
	print(_probe.summary())
