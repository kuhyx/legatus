class_name HorseShape
extends RefCounted
## The general's horse as low-poly meshes, in General space (metres, -Z
## forward, y 0 = ground). Bay: a red-brown coat, black mane, tail and lower
## legs. Withers 1.4 m (DOCS-design.md numbers table). Animated parts are
## separate meshes with a pivot so RiderBody can turn them.
##
## Sizes are [design guess] proportions for a ~1.4 m Roman cavalry horse,
## placed so that from the rider's eye (2.3 m) the poll and ears sit ~15 deg
## below the horizon: the lower third of the frame, like a first-person rider.

## sRGB picks, converted by the material (vertex_color_is_srgb).
const COAT: Color = Color(0.46, 0.24, 0.12)
const COAT_DARK: Color = Color(0.36, 0.18, 0.09)
const BLACK: Color = Color(0.07, 0.055, 0.045)
const MUZZLE: Color = Color(0.17, 0.11, 0.08)
const STRAP: Color = Color(0.5, 0.09, 0.07)
const BRONZE: Color = Color(0.72, 0.53, 0.26)

## The head and neck nod about the base of the neck.
const NECK_BASE: Vector3 = Vector3(0.0, 1.22, -0.5)
const POLL: Vector3 = Vector3(0.0, 1.72, -1.33)
const MUZZLE_TIP: Vector3 = Vector3(0.0, 1.24, -1.74)
## Rein rings either side of the mouth (x mirrored) and the rein's resting
## point on the side of the neck, both moving with the nod.
const BIT: Vector3 = Vector3(0.085, 1.33, -1.64)
const REIN_NECK: Vector3 = Vector3(0.16, 1.6, -0.82)
## Mane hinges along the crest; ears at the poll; the tail at the dock.
const CREST_BASE: Vector3 = Vector3(0.0, 1.47, -0.33)
const CREST_TOP: Vector3 = Vector3(0.0, 1.84, -1.26)
const EAR_BASE: Vector3 = Vector3(0.06, 1.8, -1.3)
const TAIL_ROOT: Vector3 = Vector3(0.0, 1.36, 1.2)


## Barrel, chest, withers, rump, legs: everything that does not move alone.
static func body() -> ArrayMesh:
	var lp: LowPoly = LowPoly.new()
	lp.color = COAT
	lp.sides = 8
	var barrel: Vector2 = Vector2(0.29, 0.33)
	lp.frustum(Vector3(0, 1.05, -0.55), Vector3(0, 1.06, 0.5), LowPoly.even(barrel))
	lp.frustum(Vector3(0, 1.05, -0.55), Vector3(0, 1.0, -0.86), Vector4(0.29, 0.33, 0.2, 0.26))
	lp.frustum(Vector3(0, 1.3, -0.05), Vector3(0, 1.3, -0.55), Vector4(0.15, 0.12, 0.15, 0.1))
	# Forearms down to the knees; the black lower legs below.
	lp.mirrored(
		Vector3(0.16, 0.9, -0.66), Vector3(0.15, 0.48, -0.68), Vector4(0.08, 0.1, 0.05, 0.06)
	)
	lp.color = COAT_DARK
	lp.frustum(Vector3(0, 1.06, 0.5), Vector3(0, 1.1, 1.05), Vector4(0.29, 0.33, 0.28, 0.32))
	lp.frustum(Vector3(0, 1.1, 1.05), Vector3(0, 1.05, 1.24), Vector4(0.28, 0.32, 0.17, 0.22))
	lp.mirrored(Vector3(0.17, 0.95, 0.95), Vector3(0.15, 0.45, 1.05), Vector4(0.11, 0.2, 0.06, 0.1))
	lp.color = BLACK
	var cannon: Vector4 = Vector4(0.04, 0.05, 0.05, 0.06)
	lp.mirrored(Vector3(0.15, 0.48, -0.68), Vector3(0.15, 0.04, -0.68), cannon)
	lp.mirrored(Vector3(0.15, 0.45, 1.05), Vector3(0.15, 0.04, 1.0), cannon)
	return lp.commit()


## Neck, head, muzzle, bridle: one mesh that nods about NECK_BASE.
static func head() -> ArrayMesh:
	var lp: LowPoly = LowPoly.new()
	lp.color = COAT
	lp.sides = 8
	lp.frustum(NECK_BASE, POLL, Vector4(0.2, 0.3, 0.085, 0.13))
	var crown: Vector3 = POLL + Vector3(0.0, 0.0, -0.04)
	lp.frustum(crown, MUZZLE_TIP, Vector4(0.125, 0.15, 0.075, 0.09))
	lp.color = MUZZLE
	var nose: Vector3 = MUZZLE_TIP.lerp(crown, 0.25)
	lp.frustum(nose, MUZZLE_TIP + Vector3(0, -0.02, -0.02), Vector4(0.08, 0.095, 0.07, 0.08))
	# Bridle: brow band and nose band in red leather, a bronze ring each side.
	lp.color = STRAP
	var brow: Vector3 = crown.lerp(MUZZLE_TIP, 0.12)
	lp.frustum(brow, brow.lerp(MUZZLE_TIP, 0.06), Vector4(0.135, 0.16, 0.133, 0.157))
	var band: Vector3 = crown.lerp(MUZZLE_TIP, 0.68)
	lp.frustum(band, band.lerp(MUZZLE_TIP, 0.08), Vector4(0.09, 0.113, 0.088, 0.11))
	lp.color = BRONZE
	lp.mirrored(BIT, BIT + Vector3(0.025, 0.0, 0.0), LowPoly.even(Vector2(0.03, 0.03)))
	lp.color = BLACK
	lp.frustum(
		POLL + Vector3(0, 0.1, 0.0), POLL + Vector3(0, 0.0, -0.16), Vector4(0.04, 0.03, 0.03, 0.01)
	)
	return lp.commit()


## Short upright mane along the crest; flops sideways about CREST_BASE.
static func mane() -> ArrayMesh:
	var lp: LowPoly = LowPoly.new()
	lp.color = BLACK
	var lift: Vector3 = Vector3(0.0, 0.02, 0.0)
	var end: Vector3 = CREST_BASE.lerp(CREST_TOP, 0.88)
	lp.frustum(CREST_BASE + lift, end + lift, Vector4(0.02, 0.045, 0.016, 0.035))
	return lp.commit()


## One ear (side 1 = right, -1 = left), pivoting at EAR_BASE.
static func ear(side: float) -> ArrayMesh:
	var lp: LowPoly = LowPoly.new()
	lp.color = COAT_DARK
	var base: Vector3 = EAR_BASE * Vector3(side, 1.0, 1.0)
	var tip: Vector3 = base + Vector3(0.03 * side, 0.15, 0.03)
	lp.frustum(base, tip, Vector4(0.035, 0.022, 0.006, 0.004), Vector3.BACK)
	return lp.commit()


## Dock and hair, hanging from TAIL_ROOT.
static func tail() -> ArrayMesh:
	var lp: LowPoly = LowPoly.new()
	lp.color = BLACK
	var dock: Vector3 = TAIL_ROOT + Vector3(0.0, -0.32, 0.16)
	lp.frustum(TAIL_ROOT, dock, Vector4(0.06, 0.07, 0.07, 0.06))
	lp.frustum(dock, dock + Vector3(0.0, -0.55, 0.06), Vector4(0.09, 0.06, 0.05, 0.03))
	return lp.commit()
