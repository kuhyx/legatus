extends Node3D
## Ride-around scene: procedural hills and woods, the general, and a few dummy
## formation blocks to look at. Run: godot --path . scenes/general/ride.tscn

const SAMPLES_PER_SIDE: int = 257
const SAMPLE_SPACING_M: float = 15.625  # 256 cells * 15.625 m = 4 km square
const HILL_AMPLITUDE_M: float = 90.0
const WOODS_CLUSTERS: int = 24
const SIGHT_CHECK_S: float = 0.5
## Start on the highest ground within this radius of the centre: a general
## picks a vantage point before the battle.
const VANTAGE_SEARCH_M: float = 400.0
## No woods this close to the centre, so the nearest dummies are in the open.
const OPEN_START_RADIUS_M: float = 700.0
## Dummy formations around the start: (bearing deg, distance m, facing deg).
## Distances span the DOCS-design perception bands (detail .. blob .. max).
const FORMATIONS: Array[Vector3] = [
	Vector3(0.0, 250.0, 0.0),
	Vector3(40.0, 600.0, 20.0),
	Vector3(-50.0, 900.0, -15.0),
	Vector3(110.0, 1200.0, 90.0),
	Vector3(200.0, 1600.0, 45.0),
	Vector3(-120.0, 2400.0, 0.0),
]

@export var world_seed: int = 7

var field: HeightField = null
var woods: Woods = null
var visibility: Visibility = null
var _markers: Array[Node3D] = []
var _sight_timer: float = 0.0

@onready var _general: General = $General
@onready var _hud: Label = $Hud/Status


func _ready() -> void:
	field = HeightField.from_noise(world_seed, SAMPLES_PER_SIDE, SAMPLE_SPACING_M, HILL_AMPLITUDE_M)
	woods = Woods.scatter(world_seed, field, WOODS_CLUSTERS, OPEN_START_RADIUS_M)
	visibility = Visibility.new(field, woods)
	var terrain: Terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(field)
	var forest: ForestView = ForestView.new()
	forest.name = "Forest"
	add_child(forest)
	forest.build(woods, field, world_seed)
	add_child(RideEnvironment.build())
	_general.woods = woods
	add_child(RiderAudio.new(_general.motion, AudioBank.load_dir(), world_seed))
	var start: Vector2 = _vantage_point()
	_general.position = Vector3(start.x, field.height_at(start.x, start.y) + 0.2, start.y)
	for spec: Vector3 in FORMATIONS:
		var bearing: Vector2 = Vector2.UP.rotated(deg_to_rad(spec.x)) * spec.y
		_markers.append(_formation_marker(start + bearing, spec.z))
	_update_hud()


func _physics_process(delta: float) -> void:
	var ground: float = field.height_at(_general.position.x, _general.position.z)
	if _general.position.y < ground - 1.0:
		push_error("General fell through the terrain at %s" % _general.position)
		_general.position.y = ground + 0.2
	_sight_timer += delta
	if _sight_timer >= SIGHT_CHECK_S:
		_sight_timer = 0.0
		_update_hud()


## World XZ of the highest open (not wooded) sample near the origin.
func _vantage_point() -> Vector2:
	var best: Vector2 = Vector2.ZERO
	var best_height: float = -INF
	for z: int in field.resolution:
		for x: int in field.resolution:
			var pos: Vector2 = field.sample_position(x, z)
			if (
				pos.length() <= VANTAGE_SEARCH_M
				and field.get_sample(x, z) > best_height
				and not woods.contains(pos.x, pos.y)
			):
				best = pos
				best_height = field.get_sample(x, z)
	return best


## A 60 m x 20 m block of 2 m height: a stand-in for a formation.
func _formation_marker(at: Vector2, facing_deg: float) -> Node3D:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(60.0, 2.0, 20.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.12, 0.1)
	box.material = material
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.name = "Formation%d" % _markers.size()
	marker.mesh = box
	marker.position = Vector3(at.x, field.height_at(at.x, at.y) + 1.0, at.y)
	marker.rotation_degrees = Vector3(0.0, facing_deg, 0.0)
	add_child(marker)
	return marker


func _update_hud() -> void:
	var eye: Vector3 = _general.eye_position()
	var seen: int = 0
	for marker: Node3D in _markers:
		if visibility.is_visible(eye, marker.position + Vector3.UP):
			seen += 1
	var motion: HorseMotion = _general.motion
	_hud.text = (
		"gait: %s  speed: %.1f m/s  stamina: %d%%%s\nformations in sight: %d/%d"
		% [
			GaitTable.GAIT_NAMES[motion.gait],
			motion.speed,
			roundi(motion.stamina * 100.0),
			"  (blown)" if motion.exhausted else "",
			seen,
			_markers.size(),
		]
	)
