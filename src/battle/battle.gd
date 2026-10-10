extends Node3D
## The playable battle (scenes/battle/battle.tscn, the main scene): the general
## rides around the live 2 x 50k battle on the procedural terrain, and only
## soldiers in sight tiles he can see are drawn (R4: "you only see what a
## general from a horse could see"). Fixed 20 Hz sim tick with render
## interpolation, like bench_battle.gd. User args (after `--`):
## `--seconds=N` quit after N s (default: never), `--screenshot=PATH` save the
## last frame as PNG, `--eye=X,Z` start the general there, not on the vantage,
## `--order=N` send order N (0 advance, 1 hold, 2 withdraw) at start to the
## formation in view, `--debug` show soldier counts on the HUD (a real general
## has no such readout), `--demo-ride` ride the scripted DemoRide (recordings).

const MAX_CATCH_UP: int = 3
const HUD_PERIOD_S: float = 0.25
## Frames in the first second (loading, first sweep) are not counted.
const WARMUP_SEC: float = 1.0

@export var world_seed: int = 7

var world: BattleWorld = null
var _sight: BattleSight = null
var _army: ArmyRenderer = null
var _command: BattleCommand = null
var _seconds: float = 0.0
var _elapsed: float = 0.0
var _accum: float = 0.0
var _hud_timer: float = 0.0
var _debug_hud: bool = false
var _frame_ms: SimStats = SimStats.new()
var _probe: RenderProbe = RenderProbe.new()

@onready var _general: General = $General
@onready var _hud: Label = $Hud/Status


func _ready() -> void:
	_seconds = BenchScenario.arg("seconds", "0").to_float()
	BenchScenario.apply_render_size(get_tree().root)
	_probe.watch(get_viewport())
	_debug_hud = BenchScenario.arg("debug", "false") == "true"
	# A timed run is a measurement: the view must not follow a stray mouse.
	_general.controls_enabled = _seconds <= 0.0
	world = BattleWorld.build(world_seed, BenchScenario.PER_SIDE)
	_build_scenery()
	_place_general(_start_position())
	if BenchScenario.arg("demo-ride", "false") == "true":
		add_child(DemoRide.new(_general))
	_army = ArmyRenderer.new()
	_army.name = "Army"
	add_child(_army)
	_army.setup(world.sim, world.render_bounds())
	_command = BattleCommand.new()
	_command.name = "Command"
	add_child(_command)
	_command.setup(world.sim, world.field, _general, world_seed)
	var sound: BattleSound = BattleSound.new()
	add_child(sound)
	sound.setup(world, _general, _command, world_seed)
	var order: int = BenchScenario.arg("order", "-1").to_int()
	if order >= 0:
		print("order %d sent to formation %d" % [order, _command.send(order, _view())])
	# One synchronous sweep so the first frame is already culled.
	_sight = BattleSight.new(world.sim)
	var tiles: int = _sight.full_sweep(_general.eye_position())
	_army.draw(0.0, _general.eye_position())
	_report("start (%d tiles visible)" % tiles)
	_update_hud()


func _build_scenery() -> void:
	var terrain: Terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(world.field)
	var forest: ForestView = ForestView.new()
	forest.name = "Forest"
	add_child(forest)
	forest.build(world.woods, world.field, world_seed)
	add_child(RideEnvironment.build())
	_general.woods = world.woods


func _start_position() -> Vector2:
	var eye: PackedStringArray = BenchScenario.arg("eye", "").split(",")
	if eye.size() == 2:
		return Vector2(eye[0].to_float(), eye[1].to_float())
	return world.start_position()


## Stand the general at XZ, facing the enemy (+Z; heading PI, see HorseMotion).
## The general's head turned to the line: a timed run has no mouse-look.
func _view() -> Transform3D:
	_general.force_update_transform()
	return _general.camera().global_transform


func _place_general(at: Vector2) -> void:
	_general.position = Vector3(at.x, world.field.height_at(at.x, at.y) + 0.2, at.y)
	_general.motion.heading = PI
	_general.rotation.y = PI


func _process(delta: float) -> void:
	_elapsed += delta
	_probe.sample(_elapsed > WARMUP_SEC)
	if _elapsed > WARMUP_SEC:
		_frame_ms.add(delta * 1000.0)
	_accum += delta
	var steps: int = 0
	while _accum >= BenchScenario.TICK_DT and steps < MAX_CATCH_UP:
		world.sim.tick(BenchScenario.TICK_DT)
		_command.tick(BenchScenario.TICK_DT)
		_accum -= BenchScenario.TICK_DT
		steps += 1
	_accum = minf(_accum, BenchScenario.TICK_DT)
	_sight.step(_general.eye_position())
	_army.draw(_accum / BenchScenario.TICK_DT, _general.camera().global_position)
	_command.draw(_general.eye_position())
	_hud_timer += delta
	if _hud_timer >= HUD_PERIOD_S:
		_hud_timer = 0.0
		_update_hud()
	if _seconds > 0.0 and _elapsed >= _seconds:
		_report("end")
		print(_frame_ms.summary("frame_ms"))
		print(_probe.summary())
		_save_screenshot(BenchScenario.arg("screenshot", ""))
		get_tree().quit()


func _physics_process(_delta: float) -> void:
	var ground: float = world.field.height_at(_general.position.x, _general.position.z)
	if _general.position.y < ground - 1.0:
		push_error("General fell through the terrain at %s" % _general.position)
		_general.position.y = ground + 0.2


func _in_sight() -> int:
	return world.sim.get_visible_alive(0) + world.sim.get_visible_alive(1)


func _alive() -> int:
	return world.sim.get_alive(0) + world.sim.get_alive(1)


func _update_hud() -> void:
	var motion: HorseMotion = _general.motion
	_hud.text = (
		"gait: %s  speed: %.1f m/s  stamina: %d%%%s"
		% [
			GaitTable.GAIT_NAMES[motion.gait],
			motion.speed,
			roundi(motion.stamina * 100.0),
			"  (blown)" if motion.exhausted else "",
		]
	)
	if not _command.note.is_empty():
		_hud.text += "\n" + _command.note
	if _debug_hud:
		_hud.text += "\n[debug] soldiers in sight: %d / alive %d" % [_in_sight(), _alive()]


func _report(label: String) -> void:
	var sim: BattleSim = world.sim
	print(
		(
			(
				"battle %s: t=%.1fs eye=%s look=%.0f/%.0f deg drawn=%d in_sight=%d"
				+ " alive=%d tiles=%d/%d sweep_ms=%.2f"
			)
			% [
				label,
				_elapsed,
				_general.eye_position().snapped(Vector3.ONE * 0.1),
				rad_to_deg(_general.neck_yaw),
				rad_to_deg(_general.neck_pitch),
				sim.get_drawn_count(0) + sim.get_drawn_count(1),
				_in_sight(),
				_alive(),
				_sight.visible_tiles,
				sim.get_tile_count(),
				_sight.last_sweep_compute_usec / 1000.0,
			]
		)
	)


func _save_screenshot(path: String) -> void:
	if path.is_empty():
		return
	var err: Error = get_viewport().get_texture().get_image().save_png(path)
	print("screenshot %s: %s" % [path, error_string(err)])
