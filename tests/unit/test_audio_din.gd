extends GutTest
## The battle din: which formations get an emitter (DinSelect), how
## BattleAudio keeps them, couriers' hooves by distance. Synthetic streams.


## `n` engaged formations on a line along +X, 50 m apart from x = 100.
func _line(n: int) -> CourierFake:
	var fake: CourierFake = CourierFake.new()
	for i: int in n:
		fake.add(Vector2(100.0 + 50.0 * i, 0.0), i % 2)
		fake.engaged[i] = true
	return fake


func _strength(_f: int) -> int:
	return 500


func _flat(_x: float, _z: float) -> float:
	return 0.0


func _din(fake: CourierFake) -> BattleAudio:
	var listener: Node3D = Node3D.new()
	add_child_autofree(listener)
	var din: BattleAudio = BattleAudio.new()
	din.setup(fake.source(), _strength, _flat, listener)
	din.build(AudioFake.bank(), 5)
	add_child_autofree(din)
	din.set_process(false)
	return din


func test_kind_of() -> void:
	assert_eq(DinSelect.kind_of(false, false, 100), DinSelect.SILENT)
	assert_eq(DinSelect.kind_of(true, false, 100), DinSelect.ENGAGED)
	assert_eq(DinSelect.kind_of(true, true, 100), DinSelect.ROUTED)
	assert_eq(DinSelect.kind_of(true, true, 0), DinSelect.SILENT, "no one left")


func test_nearest_caps_and_sorts() -> void:
	var centres: PackedVector2Array = PackedVector2Array()
	var kinds: PackedByteArray = PackedByteArray()
	assert_eq(centres.resize(45), OK)
	assert_eq(kinds.resize(45), OK)
	# 40 engaged formations, listed far to near, plus silent ones nearest of all.
	for i: int in 40:
		centres[i] = Vector2(0.0, 1000.0 - 20.0 * i)
		kinds[i] = DinSelect.ENGAGED
	for i: int in 5:
		centres[40 + i] = Vector2(1.0 * i, 1.0)
		kinds[40 + i] = DinSelect.SILENT
	var picked: PackedInt32Array = DinSelect.nearest(Vector2.ZERO, centres, kinds, 16)
	assert_eq(picked.size(), 16)
	for i: int in picked.size():
		assert_eq(picked[i], 39 - i, "nearest engaged first")


func test_nearest_ignores_beyond_hearing() -> void:
	var centres: PackedVector2Array = [Vector2(0.0, 500.0), Vector2(0.0, 2500.0)]
	var kinds: PackedByteArray = [DinSelect.ROUTED, DinSelect.ENGAGED]
	var picked: PackedInt32Array = DinSelect.nearest(Vector2.ZERO, centres, kinds, 16)
	assert_eq(Array(picked), [0])


func test_battle_audio_fills_sixteen_nearest() -> void:
	var fake: CourierFake = _line(30)
	var din: BattleAudio = _din(fake)
	din.update()
	assert_eq(din.active_count(), AudioTuning.MAX_EMITTERS)
	var voiced: Array[int] = []
	for emitter: DinEmitter in din.emitters:
		voiced.append(emitter.formation)
	voiced.sort()
	assert_eq(voiced, range(AudioTuning.MAX_EMITTERS))


func test_emitters_keep_their_formation() -> void:
	var fake: CourierFake = _line(20)
	var din: BattleAudio = _din(fake)
	din.update()
	var before: Array[int] = []
	for emitter: DinEmitter in din.emitters:
		before.append(emitter.formation)
	din.update()
	for i: int in din.emitters.size():
		assert_eq(din.emitters[i].formation, before[i], "emitter %d moved" % i)


func test_routed_and_quiet_formations() -> void:
	var fake: CourierFake = _line(4)
	fake.engaged[1] = false
	fake.routed[2] = true
	var din: BattleAudio = _din(fake)
	din.update()
	assert_eq(din.active_count(), 3, "the quiet one gets no emitter")
	for emitter: DinEmitter in din.emitters:
		if emitter.formation == 2:
			assert_eq(emitter.kind, DinSelect.ROUTED)
			assert_almost_eq(emitter.crowd.pitch_scale, AudioTuning.ROUTED_PITCH, 1e-4)


func test_courier_hooves_only_within_hearing() -> void:
	var near: Courier = Courier.new()
	near.state = Courier.State.OUTBOUND
	near.position = Vector2(100.0, 0.0)
	var far: Courier = Courier.new()
	far.state = Courier.State.RETURNING
	far.position = Vector2(AudioTuning.COURIER_HEAR_M + 50.0, 0.0)
	var listener: Node3D = Node3D.new()
	add_child_autofree(listener)
	var couriers: CourierAudio = CourierAudio.new()
	couriers.setup([near] as Array[Courier], _flat, listener, AudioFake.bank())
	add_child_autofree(couriers)
	couriers.set_process(false)
	for _i: int in 60:
		couriers.step(1.0 / 60.0)
	# One second of gallop: 2.3 strides x 4 footfalls, give or take one.
	var per_s: float = GaitTable.STRIDE_HZ[GaitTable.GALLOP] * 4.0
	assert_almost_eq(float(couriers.started()), per_s, 4.0)
	var heard: int = couriers.started()
	near.position = far.position
	for _i: int in 60:
		couriers.step(1.0 / 60.0)
	assert_eq(couriers.started(), heard, "nothing from 350 m")
