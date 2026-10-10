extends GutTest
## OrderPicker (which formation the general points at), the loss-chance rules
## of CourierSettings, and the order keys.

## Camera at the origin looking along -Z (Transform3D.IDENTITY).
const EYE: Transform3D = Transform3D.IDENTITY

var _centres: PackedVector2Array = PackedVector2Array()
var _sides: PackedInt32Array = PackedInt32Array()
var _routed: PackedByteArray = PackedByteArray()


func before_each() -> void:
	_centres = PackedVector2Array()
	_sides = PackedInt32Array()
	_routed = PackedByteArray()
	_add(Vector2(0.0, -1000.0), 0, false)  # 0: dead ahead, ours
	_add(Vector2(0.0, -900.0), 1, false)  # 1: dead ahead, enemy
	_add(Vector2(10.0, -800.0), 0, true)  # 2: ahead, ours but routed
	_add(Vector2(500.0, -1000.0), 0, false)  # 3: ours, ~27 deg off
	_add(Vector2(0.0, -4000.0), 0, false)  # 4: ours, out of range


func _add(centre: Vector2, side: int, is_routed: bool) -> void:
	assert_false(_centres.append(centre))
	assert_false(_sides.append(side))
	assert_false(_routed.append(1 if is_routed else 0))


func _pick(camera: Transform3D) -> int:
	return OrderPicker.pick(camera, _centres, _sides, _routed)


func test_picks_own_formation_in_the_cone() -> void:
	assert_eq(_pick(EYE), 0, "ignores the enemy and the routed block in front of it")


func test_none_when_only_ignored_formations_are_ahead() -> void:
	_routed[0] = 1
	assert_eq(_pick(EYE), -1, "enemy, routed, out of cone, out of range: nothing")


func test_closest_bearing_wins() -> void:
	_add(Vector2(-30.0, -1000.0), 0, false)  # 5: ~1.7 deg left
	var right_5deg: Transform3D = EYE.rotated(Vector3.UP, deg_to_rad(-5.0))
	assert_eq(_pick(right_5deg), 0, "0 is 5 deg off, 5 is ~6.7 deg off")
	var left_2deg: Transform3D = EYE.rotated(Vector3.UP, deg_to_rad(2.0))
	assert_eq(_pick(left_2deg), 5)


func test_turning_to_a_block_picks_it() -> void:
	var to_three: Transform3D = EYE.rotated(Vector3.UP, -atan2(500.0, 1000.0))
	assert_eq(_pick(to_three), 3)


func test_head_pitch_does_not_matter() -> void:
	var down: Transform3D = EYE.rotated_local(Vector3.RIGHT, deg_to_rad(-20.0))
	assert_eq(_pick(down), 0)


func test_loss_behind_own_lines_scales_with_distance() -> void:
	var settings: CourierSettings = CourierSettings.new()
	var src: FormationSource = _fake_with_enemy(Vector2(5000.0, 5000.0), false).source()
	var chance: float = settings.loss_chance(Vector2.ZERO, Vector2(0.0, 2000.0), src, 0)
	assert_almost_eq(chance, 1.0 - pow(0.99, 2.0), 1e-6, "1% per km over 2 km")


func test_loss_near_enemy_and_through_melee() -> void:
	var settings: CourierSettings = CourierSettings.new()
	settings.loss_per_km = 0.0
	var near: FormationSource = _fake_with_enemy(Vector2(150.0, 1000.0), false).source()
	var chance: float = settings.loss_chance(Vector2.ZERO, Vector2(0.0, 2000.0), near, 0)
	assert_almost_eq(chance, 0.15, 1e-6, "one pass within 200 m of an enemy block")
	var melee: FormationSource = _fake_with_enemy(Vector2(30.0, 1000.0), true).source()
	chance = settings.loss_chance(Vector2.ZERO, Vector2(0.0, 2000.0), melee, 0)
	assert_almost_eq(chance, 0.5, 1e-6, "melee crossing supersedes the near-enemy roll")
	var idle: FormationSource = _fake_with_enemy(Vector2(30.0, 1000.0), false).source()
	chance = settings.loss_chance(Vector2.ZERO, Vector2(0.0, 2000.0), idle, 0)
	assert_almost_eq(chance, 0.15, 1e-6, "an unengaged enemy is only a near pass")
	var friends: CourierFake = _fake_with_enemy(Vector2(30.0, 1000.0), true)
	friends.sides[1] = 0
	chance = settings.loss_chance(Vector2.ZERO, Vector2(0.0, 2000.0), friends.source(), 0)
	assert_almost_eq(chance, 0.0, 1e-6, "own formations, even fighting, are no danger")


func test_many_enemy_blocks_are_still_one_pass() -> void:
	var settings: CourierSettings = CourierSettings.new()
	settings.loss_per_km = 0.0
	var fake: CourierFake = _fake_with_enemy(Vector2(100.0, 1000.0), false)
	for i: int in 6:
		fake.add(Vector2(-100.0 + 40.0 * i, 1020.0), 1)
	var chance: float = settings.loss_chance(Vector2.ZERO, Vector2(0.0, 2000.0), fake.source(), 0)
	assert_almost_eq(chance, 0.15, 1e-6, "one roll per pass, not per enemy block")


func test_reaching_an_engaged_unit_from_behind_is_not_a_melee_crossing() -> void:
	var settings: CourierSettings = CourierSettings.new()
	settings.loss_per_km = 0.0
	# The enemy is locked with the target, 40 m past its centre.
	var fake: CourierFake = _fake_with_enemy(Vector2(0.0, 2040.0), true)
	var chance: float = settings.loss_chance(Vector2.ZERO, Vector2(0.0, 2000.0), fake.source(), 0)
	assert_almost_eq(chance, 0.15, 1e-6, "near the enemy, but not through the melee")


func test_order_keys_registered() -> void:
	OrderInput.ensure_actions()
	var two: InputEventKey = InputEventKey.new()
	two.physical_keycode = KEY_2
	two.pressed = true
	assert_eq(OrderInput.order_for(two), OrderInput.HOLD)
	var w: InputEventKey = InputEventKey.new()
	w.physical_keycode = KEY_W
	w.pressed = true
	assert_eq(OrderInput.order_for(w), -1, "W is the general's gait key")


## One own formation at the route's end, one enemy at `at`.
func _fake_with_enemy(at: Vector2, is_engaged: bool) -> CourierFake:
	var fake: CourierFake = CourierFake.new()
	fake.add(Vector2(0.0, 2000.0), 0)
	fake.add(at, 1)
	fake.engaged[1] = is_engaged
	return fake
