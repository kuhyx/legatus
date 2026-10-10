extends GutTest
## Visibility: terrain occlusion, distance, woods, dust, horizon.

const RES: int = 101
const SPACING: float = 10.0  # 1 km square, centred on the origin
const EYE: Vector3 = Vector3(-300.0, 2.4, 0.0)
const TARGET: Vector3 = Vector3(300.0, 1.7, 0.0)


## Flat field with a 20 m north-south ridge across x = 0.
func _ridge_field() -> HeightField:
	var field: HeightField = HeightField.new(RES, SPACING)
	var centre: int = (RES - 1) / 2
	for z: int in RES:
		for x: int in range(centre - 2, centre + 3):
			field.set_sample(x, z, 20.0)
	return field


func test_point_behind_hill_is_hidden() -> void:
	var vis: Visibility = Visibility.new(_ridge_field())
	assert_true(vis.terrain_blocks(EYE, TARGET), "ridge should block the sight line")
	assert_false(vis.is_visible(EYE, TARGET), "point behind the ridge")
	assert_eq(vis.visibility_factor(EYE, TARGET), 0.0)


func test_same_point_without_hill_is_visible() -> void:
	var vis: Visibility = Visibility.new(HeightField.new(RES, SPACING))
	assert_false(vis.terrain_blocks(EYE, TARGET))
	assert_true(vis.is_visible(EYE, TARGET), "flat ground: nothing in the way")


func test_point_on_the_ridge_top_is_visible() -> void:
	var vis: Visibility = Visibility.new(_ridge_field())
	assert_true(vis.is_visible(EYE, Vector3(0.0, 21.7, 0.0)), "rider on the crest")


func test_beyond_max_distance_is_hidden() -> void:
	var vis: Visibility = Visibility.new()
	var far: Vector3 = Vector3(0.0, 1.7, -(VisionTable.MAX_DISTANCE_M + 50.0))
	var near: Vector3 = Vector3(0.0, 1.7, -VisionTable.HAZE_START_M)
	assert_false(vis.is_visible(Vector3(0.0, 2.4, 0.0), far))
	assert_true(vis.is_visible(Vector3(0.0, 2.4, 0.0), near))


func test_haze_falls_off_with_distance() -> void:
	assert_eq(Visibility.haze_factor(100.0), 1.0)
	assert_almost_eq(Visibility.haze_factor(VisionTable.MAX_DISTANCE_M), 0.0, 1e-6)
	assert_lt(Visibility.haze_factor(2000.0), Visibility.haze_factor(1000.0))


func test_point_inside_woods_is_hidden() -> void:
	var woods: Woods = Woods.new()
	woods.add_cluster(Vector2(200.0, 0.0), 100.0)
	var inside: Vector3 = Vector3(200.0, 1.7, 0.0)
	assert_true(woods.contains(inside.x, inside.z))
	assert_false(Visibility.new(null, woods).is_visible(EYE, inside), "deep in the trees")
	assert_true(Visibility.new().is_visible(EYE, inside), "same point, no woods")


func test_woods_seen_over_from_high_ground() -> void:
	var woods: Woods = Woods.new()
	woods.add_cluster(Vector2(0.0, 0.0), 50.0)
	var high_eye: Vector3 = Vector3(-300.0, 80.0, 0.0)
	var beyond: Vector3 = Vector3(300.0, 60.0, 0.0)
	assert_eq(woods.depth_along(high_eye, beyond, null), 0.0, "sight line above the canopy")
	assert_gt(woods.depth_along(EYE, TARGET, null), 90.0, "ground level: through the wood")


func test_dust_reduces_visibility() -> void:
	var vis: Visibility = Visibility.new()
	var clear: float = vis.visibility_factor(EYE, TARGET)
	vis.dust_density = 1.0
	assert_lt(vis.visibility_factor(EYE, TARGET), clear)
	assert_false(vis.is_visible(EYE, TARGET), "600 m of thick dust")


func test_horizon_distance_for_rider() -> void:
	# DOCS-design.md numbers table: 5.4 km geometric at 2.3 m (3.57 * sqrt(h)).
	var expected: float = 3570.0 * sqrt(GaitTable.EYE_HEIGHT_M)
	assert_almost_eq(Visibility.horizon_distance(GaitTable.EYE_HEIGHT_M), expected, 20.0)
	assert_almost_eq(expected, 5400.0, 100.0)
	assert_eq(Visibility.horizon_distance(0.0), 0.0)
