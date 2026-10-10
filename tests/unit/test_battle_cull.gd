extends GutTest
## BattleSim sight-tile culling: soldiers in hidden tiles are left out of the
## compacted fill buffers and every count; an all-visible mask changes nothing.

const STRIDE: int = 16
const TILE: float = 10.0


## 20 x 10 soldiers per side on a 2 m grid: side 0 at z in [-30, -12),
## side 1 at z in [12, 30), x in [-20, 20).
func _grid_sim() -> BattleSim:
	var pos: PackedVector2Array = PackedVector2Array()
	var sides: PackedByteArray = PackedByteArray()
	for side: int in 2:
		for row: int in 9:
			for col: int in 20:
				var z: float = -29.0 + row * 2.0 if side == 0 else 13.0 + row * 2.0
				assert_false(pos.append(Vector2(-19.0 + col * 2.0, z)))
				assert_false(sides.append(side))
	var sim: BattleSim = BattleSim.new()
	sim.setup_custom(pos, sides, 3)
	return sim


## 4 x 6 tiles of 10 m from (-20, -30); tiles with x < 0 are hidden.
func _hide_west(sim: BattleSim) -> void:
	var mask: PackedByteArray = PackedByteArray()
	for row: int in 6:
		for col: int in 4:
			assert_false(mask.append(1 if col >= 2 else 0))
	sim.set_visibility_tiles(mask, Vector2(-20.0, -30.0), TILE, 4, 6)


func _origins(buf: PackedFloat32Array, count: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in count:
		assert_false(out.append(Vector2(buf[i * STRIDE + 3], buf[i * STRIDE + 11])))
	return out


func test_hidden_tiles_absent_from_lod_buffers_and_counts() -> void:
	var sim: BattleSim = _grid_sim()
	_hide_west(sim)
	for side: int in 2:
		var near: int = sim.fill_lod(side, 1.0, Vector3(10.0, 2.5, 0.0), 22.0)
		var far: int = sim.get_lod_count(side, 1)
		assert_eq(near + far, 90, "only the eastern half of the 180 is drawn")
		assert_eq(sim.get_drawn_count(side), 90)
		assert_eq(sim.get_visible_alive(side), 90)
		assert_gt(near, 0)
		assert_gt(far, 0)
		var drawn: PackedVector2Array = _origins(sim.get_lod_buffer(side, 0), near)
		drawn.append_array(_origins(sim.get_lod_buffer(side, 1), far))
		for p: Vector2 in drawn:
			assert_gt(p.x, 0.0, "soldier at %s sits in a hidden tile" % p)


func test_hidden_tiles_absent_from_fill_transforms() -> void:
	var sim: BattleSim = _grid_sim()
	_hide_west(sim)
	var buf: PackedFloat32Array = sim.fill_transforms(1, 1.0)
	assert_eq(buf.size(), sim.get_side_count(1) * STRIDE, "buffer stays full size")
	assert_eq(sim.get_drawn_count(1), 90)
	for p: Vector2 in _origins(buf, sim.get_drawn_count(1)):
		assert_gt(p.x, 0.0)


func test_all_visible_tiles_equal_no_tiles() -> void:
	var plain: BattleSim = BattleSim.new()
	var masked: BattleSim = BattleSim.new()
	for sim: BattleSim in [plain, masked]:
		sim.setup_lines(600, 60.0, 30.0, 2)
		for _i: int in 5:
			sim.tick(0.05)
	var mask: PackedByteArray = PackedByteArray()
	assert_eq(mask.resize(20 * 20), OK)
	mask.fill(1)
	masked.set_visibility_tiles(mask, Vector2(-100.0, -100.0), TILE, 20, 20)
	for side: int in 2:
		assert_eq(masked.fill_transforms(side, 0.5), plain.fill_transforms(side, 0.5))
		assert_eq(masked.get_drawn_count(side), plain.get_side_count(side))
		var camera: Vector3 = Vector3(0.0, 2.5, -20.0)
		assert_eq(masked.fill_lod(side, 0.5, camera, 15.0), plain.fill_lod(side, 0.5, camera, 15.0))
		for lod: int in 2:
			assert_eq(masked.get_lod_count(side, lod), plain.get_lod_count(side, lod))
			assert_eq(masked.get_lod_buffer(side, lod), plain.get_lod_buffer(side, lod))
		assert_eq(masked.get_visible_alive(side), masked.get_alive(side))


func test_soldiers_outside_the_tile_grid_are_drawn() -> void:
	var sim: BattleSim = _grid_sim()
	var mask: PackedByteArray = PackedByteArray([0])
	sim.set_visibility_tiles(mask, Vector2(-20.0, -30.0), TILE, 1, 1)  # hides one 10 m tile
	assert_eq(sim.fill_transforms(0, 1.0).size(), 180 * STRIDE)
	assert_eq(sim.get_drawn_count(0), 180 - 25, "5 x 5 soldiers stood in the hidden tile")


func test_empty_mask_turns_culling_off() -> void:
	var sim: BattleSim = _grid_sim()
	_hide_west(sim)
	sim.set_visibility_tiles(PackedByteArray(), Vector2.ZERO, TILE, 0, 0)
	assert_eq(sim.fill_transforms(0, 1.0).size(), 180 * STRIDE)
	assert_eq(sim.get_drawn_count(0), 180)
	assert_eq(sim.get_tile_count(), 0)
