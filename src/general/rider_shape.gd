class_name RiderShape
extends RefCounted
## The general himself and his saddle as low-poly meshes, General space like
## HorseShape. Roman kit: red tunic and saddle cloth, bronze muscle cuirass,
## red sash (cingulum), leather pteruges, brown calcei, leather gloves. No
## stirrups (not Roman): the legs hang along the horse's sides.

const TUNIC: Color = Color(0.58, 0.1, 0.08)
const CLOTH: Color = Color(0.48, 0.07, 0.07)
const SADDLE: Color = Color(0.35, 0.21, 0.11)
const LEATHER: Color = Color(0.62, 0.5, 0.33)
const SKIN: Color = Color(0.74, 0.52, 0.39)
const BOOT: Color = Color(0.3, 0.18, 0.1)
const GLOVE: Color = Color(0.26, 0.16, 0.09)
const REIN: Color = Color(0.2, 0.12, 0.07)

## Rest positions (right side; x mirrored for the left).
const SHOULDER: Vector3 = Vector3(0.2, 1.95, 0.08)
const ELBOW: Vector3 = Vector3(0.17, 1.69, -0.05)
const HAND: Vector3 = Vector3(0.1, 1.57, -0.43)
const HIP: Vector3 = Vector3(0.13, 1.52, 0.02)
const KNEE: Vector3 = Vector3(0.37, 1.17, -0.45)
const ANKLE: Vector3 = Vector3(0.42, 0.85, -0.62)

const ARM_HALF: Vector2 = Vector2(0.045, 0.045)
## Forearm halves, elbow then wrist.
const FOREARM: Vector4 = Vector4(0.04, 0.036, 0.03, 0.026)
## Unit-length strap/limb meshes stretched between two points each frame.
const REIN_HALF: Vector2 = Vector2(0.012, 0.004)


## Saddle, saddle cloth and legs: fixed on the horse.
static func seat() -> ArrayMesh:
	var lp: LowPoly = LowPoly.new()
	lp.color = CLOTH
	lp.box(Vector3(0, 1.37, 0.03), Vector3(0.31, 0.025, 0.42))
	var flap: Vector4 = Vector4(0.012, 0.4, 0.012, 0.36)
	lp.mirrored(Vector3(0.24, 1.36, 0.03), Vector3(0.31, 1.04, 0.03), flap, Vector3.BACK)
	lp.color = SADDLE
	lp.box(Vector3(0, 1.43, 0.04), Vector3(0.2, 0.05, 0.3))
	# The four horns of the Roman saddle, the front pair over the thighs.
	var horn: Vector4 = Vector4(0.045, 0.03, 0.025, 0.02)
	lp.mirrored(Vector3(0.1, 1.44, -0.22), Vector3(0.14, 1.59, -0.31), horn)
	lp.mirrored(Vector3(0.1, 1.44, 0.3), Vector3(0.13, 1.56, 0.39), horn)
	lp.color = TUNIC
	var tunic_end: Vector3 = HIP.lerp(KNEE, 0.35)
	lp.mirrored(HIP, tunic_end, Vector4(0.09, 0.09, 0.085, 0.085))
	lp.color = SKIN
	lp.mirrored(tunic_end, KNEE, Vector4(0.075, 0.075, 0.06, 0.06))
	var boot_top: Vector3 = KNEE.lerp(ANKLE, 0.45)
	lp.mirrored(KNEE, boot_top, Vector4(0.055, 0.055, 0.05, 0.05), Vector3.FORWARD)
	lp.color = BOOT
	lp.mirrored(boot_top, ANKLE, Vector4(0.058, 0.058, 0.05, 0.05), Vector3.FORWARD)
	# Toes hang down: no stirrup to stand in.
	lp.mirrored(ANKLE, ANKLE + Vector3(0.06, -0.08, -0.17), Vector4(0.045, 0.045, 0.04, 0.03))
	return lp.commit()


## Cuirass, sash, tunic skirt, pteruges and upper arms: rocks with the torso.
static func torso() -> ArrayMesh:
	var lp: LowPoly = LowPoly.new()
	# The torso sits behind the eyes (eyes are at the front of the head), so
	# a look down sees the chest slope away to the hands and thighs.
	lp.color = HorseShape.BRONZE
	lp.sides = 8
	var waist: Vector3 = Vector3(0, 1.6, 0.07)
	var chest: Vector3 = Vector3(0, 1.97, 0.08)
	lp.frustum(waist, chest, Vector4(0.16, 0.12, 0.19, 0.12))
	lp.frustum(chest, chest + Vector3(0, 0.06, 0.01), Vector4(0.19, 0.12, 0.12, 0.08))
	lp.color = TUNIC
	lp.frustum(Vector3(0, 1.69, 0.07), Vector3(0, 1.74, 0.07), Vector4(0.18, 0.13, 0.183, 0.133))
	lp.frustum(Vector3(0, 1.47, 0.07), Vector3(0, 1.61, 0.07), Vector4(0.21, 0.16, 0.17, 0.13))
	lp.sides = 4
	# Pteruges: leather strips hanging over the tunic in front.
	lp.color = LEATHER
	for i: int in 5:
		var x: float = -0.14 + 0.07 * i
		lp.box(Vector3(x, 1.53, -0.08), Vector3(0.028, 0.08, 0.01), Basis(Vector3.RIGHT, -0.25))
	lp.color = TUNIC
	var sleeve: Vector3 = SHOULDER.lerp(ELBOW, 0.45)
	lp.mirrored(SHOULDER, sleeve, Vector4(0.06, 0.06, 0.055, 0.055), Vector3.FORWARD)
	lp.color = SKIN
	lp.mirrored(sleeve, ELBOW, LowPoly.even(ARM_HALF), Vector3.FORWARD)
	return lp.commit()


## A gloved fist around the reins, centred on the origin, knuckles forward.
static func hand() -> ArrayMesh:
	var lp: LowPoly = LowPoly.new()
	lp.color = GLOVE
	lp.box(Vector3.ZERO, Vector3(0.045, 0.05, 0.05))
	return lp.commit()


## A strap or limb of unit length along -Z from the origin, for
## RiderBody.stretch(): reins and forearms.
static func strap(halves: Vector4, color: Color) -> ArrayMesh:
	var lp: LowPoly = LowPoly.new()
	lp.color = color
	lp.sides = 8 if halves.x > 0.02 else 4
	lp.frustum(Vector3.ZERO, Vector3.FORWARD, halves)
	return lp.commit()
