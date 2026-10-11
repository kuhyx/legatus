extends GutTest
## ContactProbe: the fps gate's proof that the timed window had melee.


## Two 10 x 3 blocks, fronts `gap` m apart (side 0 faces +z).
func _blocks(gap: float) -> BattleSim:
	var pos: PackedVector2Array = PackedVector2Array()
	var sides: PackedByteArray = PackedByteArray()
	for side: int in 2:
		var dir: float = -1.0 if side == 0 else 1.0
		for r: int in 3:
			for f: int in 10:
				assert(not pos.append(Vector2(f - 4.5, dir * (0.5 * gap + r * 1.1))))
				assert(not sides.append(side))
	var sim: BattleSim = BattleSim.new()
	sim.setup_custom(pos, sides, 3)
	return sim


func test_no_samples_reads_zero() -> void:
	var probe: ContactProbe = ContactProbe.new()
	assert_eq(probe.summary(), "contact engaged_min=0 engaged_max=0 of=0 (n=0)")


func test_armies_apart_are_not_in_contact() -> void:
	var sim: BattleSim = _blocks(300.0)
	var probe: ContactProbe = ContactProbe.new()
	for _i: int in 5:
		sim.tick(0.05)
		probe.sample(sim)
	assert_eq(probe.summary(), "contact engaged_min=0 engaged_max=0 of=2 (n=5)")


func test_blocks_face_to_face_are_engaged() -> void:
	var sim: BattleSim = _blocks(1.5)
	var probe: ContactProbe = ContactProbe.new()
	for _i: int in 40:
		sim.tick(0.05)
	for _i: int in 5:
		sim.tick(0.05)
		probe.sample(sim)
	assert_eq(probe.summary(), "contact engaged_min=2 engaged_max=2 of=2 (n=5)")
