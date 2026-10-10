extends GutTest
## Render interpolation: alpha 0 = previous tick, alpha 1 = current tick, and
## the MultiMesh buffer layout (origin in slots 3/7/11, stride 16).

const STRIDE: int = 16


func _sim() -> BattleSim:
	var sim: BattleSim = BattleSim.new()
	sim.setup_lines(600, 60.0, 30.0, 2)
	for _i: int in 5:
		sim.tick(0.05)
	return sim


func _origin(buf: PackedFloat32Array, i: int) -> Vector2:
	return Vector2(buf[i * STRIDE + 3], buf[i * STRIDE + 11])


func test_alpha_zero_is_previous_and_one_is_current() -> void:
	var sim: BattleSim = _sim()
	var before: PackedVector2Array = sim.get_positions(1.0)
	sim.tick(0.05)
	var now: PackedVector2Array = sim.get_positions(1.0)
	assert_eq(sim.get_positions(0.0), before)
	assert_ne(now, before, "the lines are advancing")
	var at0: PackedFloat32Array = sim.fill_transforms(0, 0.0)
	var at1: PackedFloat32Array = sim.fill_transforms(0, 1.0)
	var half: PackedFloat32Array = sim.fill_transforms(0, 0.5)
	assert_eq(at1.size(), sim.get_side_count(0) * STRIDE)
	for i: int in range(0, sim.get_side_count(0), 13):
		assert_eq(_origin(at0, i), before[i])
		assert_eq(_origin(at1, i), now[i])
		assert_almost_eq(_origin(half, i), (before[i] + now[i]) * 0.5, Vector2(1e-4, 1e-4))
		assert_eq(at1[i * STRIDE + 7], 0.0, "living soldiers stand on the ground")


func test_returned_buffer_is_not_overwritten_by_the_next_fill() -> void:
	var sim: BattleSim = _sim()
	var old: PackedFloat32Array = sim.fill_transforms(1, 1.0)
	var copy: PackedFloat32Array = old.duplicate()
	sim.tick(0.05)
	var fresh: PackedFloat32Array = sim.fill_transforms(1, 1.0)
	assert_eq(old, copy, "copy-on-write kept the caller's buffer intact")
	assert_ne(fresh, old, "the new fill sees the new tick")


func test_lod_split_covers_every_soldier_once() -> void:
	var sim: BattleSim = _sim()
	var near: int = sim.fill_lod(0, 1.0, Vector3(0, 2.5, -20), 15.0)
	assert_eq(near, sim.get_lod_count(0, 0))
	assert_eq(near + sim.get_lod_count(0, 1), sim.get_side_count(0))
	assert_gt(near, 0)
	var buf: PackedFloat32Array = sim.get_lod_buffer(0, 0)
	for i: int in near:
		assert_lt(_origin(buf, i).distance_to(Vector2(0, -20)), 15.0 + 1e-3)
