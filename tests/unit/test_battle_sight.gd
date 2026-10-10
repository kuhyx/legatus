extends GutTest
## The C++ sight-tile ray march: same answers as GDScript Visibility, hides
## tiles behind a ridge, and on the real battle map the view from the start
## is partial and changes when the general rides elsewhere.

const RES: int = 101
const SPACING: float = 10.0  # 1 km square, centred on the origin
const EYE: Vector3 = Vector3(-300.0, 2.4, 0.0)

var _world: BattleWorld = null


func before_all() -> void:
	_world = BattleWorld.build(7, BenchScenario.PER_SIDE)


## Flat field with a 20 m north-south ridge across x = 0 (as in
## test_general_visibility.gd), plus a wood south-east of it.
func _ridge_sim() -> Array:
	var field: HeightField = HeightField.new(RES, SPACING)
	var centre: int = (RES - 1) / 2
	for z: int in RES:
		for x: int in range(centre - 2, centre + 3):
			field.set_sample(x, z, 20.0)
	var woods: Woods = Woods.new()
	woods.add_cluster(Vector2(-150.0, 200.0), 60.0)
	var config: BattleWorld = BattleWorld.new()
	config.woods = woods
	var sim: BattleSim = BattleSim.new()
	sim.set_height_field(
		field.heights, field.resolution, field.spacing, field.sample_position(0, 0)
	)
	sim.set_sight(config.sight_config())
	return [sim, Visibility.new(field, woods)]


func test_cpp_sight_matches_gdscript_visibility() -> void:
	var pair: Array = _ridge_sim()
	var sim: BattleSim = pair[0]
	var vis: Visibility = pair[1]
	var mismatches: int = 0
	var hidden: int = 0
	for eye: Vector3 in [EYE, Vector3(-300.0, 40.0, -200.0), Vector3(100.0, 22.0, 300.0)]:
		for z: int in range(-480, 481, 40):
			for x: int in range(-480, 481, 40):
				var point: Vector3 = Vector3(x, 1.7, z)
				var expected: float = vis.visibility_factor(eye, point)
				hidden += 1 if expected == 0.0 else 0
				if absf(sim.sight_factor(eye, point) - expected) > 1e-4:
					mismatches += 1
	assert_eq(mismatches, 0, "C++ vs GDScript visibility_factor")
	assert_between(hidden, 100, 3 * 25 * 25 - 100, "a mix of hidden and visible points")


func test_tiles_behind_the_ridge_are_hidden() -> void:
	var sim: BattleSim = _ridge_sim()[0]
	var mask: PackedByteArray = PackedByteArray()
	assert_eq(mask.resize(20 * 4), OK)
	mask.fill(0)
	sim.set_visibility_tiles(mask, Vector2(-500.0, -50.0), 50.0, 20, 4)  # x -500..500
	var seen: int = sim.compute_visibility_tiles(EYE, 0, sim.get_tile_count())
	var tiles: PackedByteArray = sim.get_visibility_tiles()
	assert_eq(seen, tiles.count(1))
	for row: int in 4:
		assert_eq(tiles[row * 20 + 3], 1, "x = -325: right by the eye")
		assert_eq(tiles[row * 20 + 9], 1, "x = -25: the near face of the ridge")
		assert_eq(tiles[row * 20 + 14], 0, "x = 225: in the ridge's shadow")


func test_start_view_is_partial() -> void:
	var counts: Vector2i = _view_from(_world.start_position())
	assert_gt(counts.x, 0, "tiles in sight from the start")
	assert_lt(counts.x, _world.sim.get_tile_count(), "some tiles hidden from the start")
	assert_gt(counts.y, 0, "soldiers in sight")
	assert_lt(counts.y, 2 * BenchScenario.PER_SIDE, "some soldiers hidden")


func test_view_changes_when_the_general_rides_behind_the_hill() -> void:
	var start: Vector2 = _world.start_position()
	var hilltop: Vector2i = _view_from(start)
	# 250 m further from the battle: down the back slope of the start hill.
	var behind: Vector2i = _view_from(start + Vector2(0.0, -250.0))
	assert_lt(behind.y, hilltop.y, "the crest hides the battle")
	gut.p("in sight: hilltop %d, behind the hill %d" % [hilltop.y, behind.y])


func test_incremental_sweep_fits_the_budget_and_matches_full() -> void:
	var sight: BattleSight = BattleSight.new(_world.sim)
	var eye: Vector3 = _eye_at(_world.start_position())
	var full: int = sight.full_sweep(eye)
	var expected: PackedByteArray = _world.sim.get_visibility_tiles()
	_world.reset_tiles(0)
	var before: int = sight.sweeps
	var frames: int = 0
	while sight.sweeps == before and frames < 1000:
		sight.step(eye)
		frames += 1
	assert_eq(sight.visible_tiles, full)
	assert_eq(_world.sim.get_visibility_tiles(), expected)
	assert_lte(frames, 30, "a sweep within 30 frames (0.5 s at 60 fps)")
	gut.p(
		(
			"tiles=%d full sweep %.2f ms, incremental: %d frames"
			% [_world.sim.get_tile_count(), sight.last_sweep_compute_usec / 1000.0, frames]
		)
	)


func _eye_at(at: Vector2) -> Vector3:
	var ground: float = _world.field.height_at(at.x, at.y)
	return Vector3(at.x, ground + 0.2 + GaitTable.EYE_HEIGHT_M, at.y)


## (visible tiles, living soldiers in visible tiles) from a rider at `at`.
func _view_from(at: Vector2) -> Vector2i:
	var eye: Vector3 = _eye_at(at)
	var sim: BattleSim = _world.sim
	var tiles: int = sim.compute_visibility_tiles(eye, 0, sim.get_tile_count())
	var seen: int = 0
	for side: int in 2:
		var near: int = sim.fill_lod(side, 1.0, eye, 120.0)
		assert_lte(near, sim.get_drawn_count(side))
		seen += sim.get_visible_alive(side)
	return Vector2i(tiles, seen)
