extends GutTest
## Soldiers stand on the height field (BattleSim samples it exactly like
## HeightField.height_at) and the battle plain is levelled.

const STRIDE: int = 16


func _hills() -> HeightField:
	return HeightField.from_noise(11, 65, 10.0, 60.0)  # 640 m square


func test_soldier_y_matches_height_field() -> void:
	var field: HeightField = _hills()
	var sim: BattleSim = BattleSim.new()
	sim.setup_lines(600, 60.0, 30.0, 2)
	sim.set_height_field(
		field.heights, field.resolution, field.spacing, field.sample_position(0, 0)
	)
	for _i: int in 3:
		sim.tick(0.05)
	var worst: float = 0.0
	for side: int in 2:
		var buf: PackedFloat32Array = sim.fill_transforms(side, 0.5)
		for i: int in sim.get_drawn_count(side):
			var x: float = buf[i * STRIDE + 3]
			var z: float = buf[i * STRIDE + 11]
			worst = maxf(worst, absf(buf[i * STRIDE + 7] - field.height_at(x, z)))
		var near: int = sim.fill_lod(side, 0.5, Vector3(0.0, 2.5, 0.0), 25.0)
		for lod: int in 2:
			var lod_buf: PackedFloat32Array = sim.get_lod_buffer(side, lod)
			var count: int = near if lod == 0 else sim.get_lod_count(side, 1)
			for i: int in count:
				var p: Vector2 = Vector2(lod_buf[i * STRIDE + 3], lod_buf[i * STRIDE + 11])
				worst = maxf(worst, absf(lod_buf[i * STRIDE + 7] - field.height_at(p.x, p.y)))
	assert_lt(worst, 0.01, "soldier y vs HeightField.height_at, metres")


func test_ground_height_matches_everywhere_including_outside() -> void:
	var field: HeightField = _hills()
	var sim: BattleSim = BattleSim.new()
	sim.set_height_field(
		field.heights, field.resolution, field.spacing, field.sample_position(0, 0)
	)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	for _i: int in 500:
		var x: float = rng.randf_range(-400.0, 400.0)  # field edge is 320 m: clamped
		var z: float = rng.randf_range(-400.0, 400.0)
		assert_almost_eq(sim.get_ground_height(x, z), field.height_at(x, z), 0.01)


func test_flatten_leaves_the_plain_within_half_a_metre() -> void:
	var field: HeightField = _hills()
	var before: PackedFloat32Array = field.heights.duplicate()
	var plain: Rect2 = Rect2(-100.0, -50.0, 200.0, 100.0)
	var level: float = field.mean_height(plain)
	field.flatten_rect(plain, level, 60.0)
	for z: int in field.resolution:
		for x: int in field.resolution:
			var p: Vector2 = field.sample_position(x, z)
			var h: float = field.get_sample(x, z)
			if plain.has_point(p):
				assert_almost_eq(h, level, 0.5, "inside the plain at %s" % p)
			elif not plain.grow(60.0).has_point(p):
				assert_eq(h, before[z * field.resolution + x], "beyond the blend at %s" % p)
	for z: int in range(-50, 51, 7):  # bilinear between samples too
		for x: int in range(-100, 101, 7):
			assert_almost_eq(field.height_at(x, z), level, 0.5)


func test_battle_world_soldiers_stand_on_the_plain() -> void:
	var world: BattleWorld = BattleWorld.build(7, 2000)
	var bounds: Rect2 = world.sim.get_bounds()
	assert_true(world.plain.encloses(bounds), "the plain covers every soldier")
	var buf: PackedFloat32Array = world.sim.fill_transforms(0, 1.0)
	for i: int in range(0, world.sim.get_drawn_count(0), 17):
		assert_almost_eq(buf[i * STRIDE + 7], world.plain_height, 0.5)
	var bounds_3d: AABB = world.render_bounds()
	assert_lt(bounds_3d.position.y, world.plain_height)
	assert_gt(bounds_3d.end.y, world.plain_height + 2.0, "room for a standing man")
