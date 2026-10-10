class_name RiderBody
extends Node3D
## What the general sees of himself and his horse: neck, head, ears and mane
## ahead and below, saddle, reins and gloved hands, thighs and boots below,
## rump and tail behind. Child of General (not of the Neck: the horse does
## not turn with the rider's head). Meshes only: no collision, no physics
## layer, no shadows, so it can never touch sight lines, rays or the ground.
## pose() applies a RiderMotion each physics step.

var _head: Node3D = null
var _mane: Node3D = null
var _ears: Array[Node3D] = []
var _tail: Node3D = null
var _torso: Node3D = null
var _hands: Array[MeshInstance3D] = []
var _forearms: Array[MeshInstance3D] = []
## Per side: hand -> side of the neck, side of the neck -> bit.
var _reins: Array[MeshInstance3D] = []
var _material: StandardMaterial3D = StandardMaterial3D.new()


func _init() -> void:
	name = "Body"
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.9
	_material.metallic_specular = 0.2
	add_child(_part(HorseShape.body(), Vector3.ZERO))
	add_child(_part(RiderShape.seat(), Vector3.ZERO))
	_head = _pivot(self, HorseShape.NECK_BASE, Vector3.ZERO, HorseShape.head())
	_mane = _pivot(_head, HorseShape.CREST_BASE, HorseShape.NECK_BASE, HorseShape.mane())
	for side: float in [1.0, -1.0]:
		var base: Vector3 = HorseShape.EAR_BASE * Vector3(side, 1.0, 1.0)
		_ears.append(_pivot(_head, base, HorseShape.NECK_BASE, HorseShape.ear(side)))
	_tail = _pivot(self, HorseShape.TAIL_ROOT, Vector3.ZERO, HorseShape.tail())
	_torso = _pivot(self, Vector3.ZERO, Vector3.ZERO, RiderShape.torso())
	var rein: ArrayMesh = RiderShape.strap(LowPoly.even(RiderShape.REIN_HALF), RiderShape.REIN)
	var forearm: ArrayMesh = RiderShape.strap(RiderShape.FOREARM, RiderShape.SKIN)
	var fist: ArrayMesh = RiderShape.hand()
	for _side: int in 2:
		_hands.append(_part(fist, Vector3.ZERO))
		_forearms.append(_part(forearm, Vector3.ZERO))
		_reins.append(_part(rein, Vector3.ZERO))
		_reins.append(_part(rein, Vector3.ZERO))
	for part: MeshInstance3D in _hands + _forearms + _reins:
		add_child(part)
	pose(RiderMotion.new())


## Every MeshInstance3D under this body (tests, shadow settings).
func meshes() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		found.append(node as MeshInstance3D)
	return found


## Place every moving part for this step's motion.
func pose(motion: RiderMotion) -> void:
	transform = motion.rig_transform()
	_torso.transform = motion.torso_transform()
	_head.rotation = Vector3(-motion.nod, 0.0, 0.0)
	var crest: Vector3 = (HorseShape.CREST_TOP - HorseShape.CREST_BASE).normalized()
	_mane.basis = Basis(crest, motion.mane)
	_ears[0].rotation = Vector3(motion.ear_right, 0.0, -motion.ear_right * 0.5)
	_ears[1].rotation = Vector3(motion.ear_left, 0.0, motion.ear_left * 0.5)
	_tail.rotation = Vector3(-motion.tail_lift, 0.0, motion.tail_swing)
	var reach: Vector3 = (
		Vector3(0.0, -0.3, -1.0) * motion.nod * RiderMotionTable.HAND_FOLLOW_M_PER_RAD
	)
	for i: int in 2:
		var flip: Vector3 = Vector3(1.0 if i == 0 else -1.0, 1.0, 1.0)
		var hand: Vector3 = _hand_at(RiderShape.HAND * flip, motion.twist) + reach
		var elbow: Vector3 = _torso.transform * (RiderShape.ELBOW * flip)
		var neck: Vector3 = _on_head(HorseShape.REIN_NECK * flip)
		var bit: Vector3 = _on_head(HorseShape.BIT * flip)
		stretch(_forearms[i], elbow, hand)
		_hands[i].transform = Transform3D(_aim(hand - elbow), hand)
		stretch(_reins[i * 2], hand, neck)
		stretch(_reins[i * 2 + 1], neck, bit)


## Lay a unit strap (RiderShape.strap) from `from` to `to`.
static func stretch(strap: Node3D, from: Vector3, to: Vector3) -> void:
	var length: float = from.distance_to(to)
	if length < 1e-4:
		return
	var basis: Basis = _aim(to - from)
	strap.transform = Transform3D(Basis(basis.x, basis.y, basis.z * length), from)


## A basis whose -Z points along `direction`.
static func _aim(direction: Vector3) -> Basis:
	var up: Vector3 = Vector3.UP
	if absf(direction.normalized().dot(up)) > 0.95:
		up = Vector3.BACK
	return Basis.looking_at(direction, up)


## A rein hand's rest point, carried part of the way round with the torso.
static func _hand_at(rest: Vector3, twist: float) -> Vector3:
	var spine: Vector3 = Vector3(0.0, rest.y, RiderMotionTable.SPINE_BEHIND_EYES_M)
	var turn: Basis = Basis(Vector3.UP, twist * RiderMotionTable.HAND_TWIST_SHARE)
	return spine + turn * (rest - spine)


## A point fixed to the horse's head, in body space after the nod.
func _on_head(point: Vector3) -> Vector3:
	return _head.transform * (point - HorseShape.NECK_BASE)


## A Node3D at `at` (General space) under `parent` whose own origin is at
## `parent_at`, holding `mesh` so that rotating the pivot turns the mesh
## about `at`.
func _pivot(parent: Node3D, at: Vector3, parent_at: Vector3, mesh: ArrayMesh) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = at - parent_at
	parent.add_child(pivot)
	pivot.add_child(_part(mesh, -at))
	return pivot


## A shadowless mesh instance with the body material.
func _part(mesh: ArrayMesh, at: Vector3) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.material_override = _material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return part
