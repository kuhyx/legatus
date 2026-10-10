class_name BattleWorld
extends RefCounted
## The playable battle's world, without nodes: procedural terrain with a
## levelled plain for the two armies (generals offered battle on open ground,
## DOCS-design-prebattle.md §2), woods kept off it, the 2 x 50k BattleSim
## standing on that terrain in lines (triplex acies, DOCS-design-command §1),
## its sight-tile grid, and the general's start on rising ground behind the
## Roman line (side 0 deploys towards -Z). Every block starts on HOLD: the
## battle begins when an "advance" reaches it.

const SAMPLES_PER_SIDE: int = 257
const SAMPLE_SPACING_M: float = 15.625  # 256 cells * 15.625 m = 4 km square
const HILL_AMPLITUDE_M: float = 90.0
const WOODS_CLUSTERS: int = 24
## No wood within this radius of the battle centre: covers the plain, its
## blend and the start band, so no flank or start lies in the trees.
const WOODS_CLEAR_M: float = 1000.0
## The levelled plain is the sim's clamp box plus this margin, eased back to
## the natural relief over PLAIN_BLEND_M.
const PLAIN_MARGIN_M: float = 40.0
const PLAIN_BLEND_M: float = 300.0
## Sight tile edge. The tile grid covers the sim's clamp box, which no
## soldier ever leaves.
const TILE_SIZE_M: float = 25.0
## The general starts on the highest open ground between these distances
## behind his own front rank, within START_HALF_WIDTH_M of the centre line.
const START_BEHIND_M: Vector2 = Vector2(600.0, 900.0)
const START_HALF_WIDTH_M: float = 600.0
## Margin above the highest ground for the MultiMesh culling box (a soldier
## is ~1.8 m tall).
const SOLDIER_HEADROOM_M: float = 3.0
## Front ranks this far apart at the start [design guess]: out of contact,
## ~2 min of walking, so the first "advance" is a real decision.
const OPENING_GAP_M: float = 150.0
## Rear rank of one line to the front rank of the next [design guess].
const LINE_GAP_M: float = 80.0
## Share of each side per line, front first. Rome: hastati / principes /
## triarii at a legion's 1,200 / 1,200 / 600 (Part IIIb). The enemy: two lines.
const ROMAN_LINES: PackedFloat32Array = [0.4, 0.4, 0.2]
const ENEMY_LINES: PackedFloat32Array = [0.6, 0.4]
## A formation whose centre is within this of its side's front rank at the
## start belongs to the front line (blocks are ~15-25 m deep).
const FRONT_LINE_DEPTH_M: float = 40.0

var field: HeightField = null
var woods: Woods = null
var sim: BattleSim = null
var plain_height: float = 0.0
var plain: Rect2 = Rect2()
var tile_origin: Vector2 = Vector2.ZERO
var tile_cols: int = 0
var tile_rows: int = 0


## Terrain, woods and a BattleSim of `per_side` soldiers a side in lines.
static func build(world_seed: int, per_side: int) -> BattleWorld:
	var world: BattleWorld = BattleWorld.new()
	world.field = HeightField.from_noise(
		world_seed, SAMPLES_PER_SIDE, SAMPLE_SPACING_M, HILL_AMPLITUDE_M
	)
	world.sim = BattleSim.new()
	world.sim.setup_array(
		per_side,
		BenchScenario.FRONTAGE,
		OPENING_GAP_M,
		LINE_GAP_M,
		ROMAN_LINES,
		ENEMY_LINES,
		BenchScenario.SEED
	)
	for f: int in world.sim.get_formation_count():
		world.sim.set_formation_order(f, BattleSim.ORDER_HOLD)
	var bounds: Rect2 = world.sim.get_bounds()
	world.plain = bounds.grow(PLAIN_MARGIN_M)
	world.plain_height = world.field.mean_height(world.plain)
	# Flatten before anything reads the field: the terrain mesh, collision,
	# trees and soldiers must all stand on the same ground.
	world.field.flatten_rect(world.plain, world.plain_height, PLAIN_BLEND_M)
	world.woods = Woods.scatter(world_seed, world.field, WOODS_CLUSTERS, WOODS_CLEAR_M)
	var f: HeightField = world.field
	world.sim.set_height_field(f.heights, f.resolution, f.spacing, f.sample_position(0, 0))
	world.sim.set_sight(world.sight_config())
	world.tile_origin = bounds.position
	world.tile_cols = ceili(bounds.size.x / TILE_SIZE_M)
	world.tile_rows = ceili(bounds.size.y / TILE_SIZE_M)
	world.reset_tiles(1)
	return world


## Fill the whole tile mask with one value (1 = all visible, 0 = all hidden).
func reset_tiles(value: int) -> void:
	var mask: PackedByteArray = PackedByteArray()
	if mask.resize(tile_cols * tile_rows) != OK:
		push_error("BattleWorld: cannot allocate %d sight tiles" % (tile_cols * tile_rows))
	mask.fill(value)
	sim.set_visibility_tiles(mask, tile_origin, TILE_SIZE_M, tile_cols, tile_rows)


## VisionTable constants and the woods, for BattleSim.set_sight.
func sight_config() -> Dictionary:
	return {
		"max_distance": VisionTable.MAX_DISTANCE_M,
		"haze_start": VisionTable.HAZE_START_M,
		"threshold": VisionTable.VISIBLE_THRESHOLD,
		"canopy_height": VisionTable.CANOPY_HEIGHT_M,
		"woods_extinction": VisionTable.WOODS_EXTINCTION_M,
		"dust_extinction": VisionTable.DUST_EXTINCTION_M,
		"terrain_tolerance": VisionTable.TERRAIN_TOLERANCE_M,
		"end_clearance": VisionTable.END_CLEARANCE_M,
		"earth_radius": VisionTable.EARTH_RADIUS_M,
		"target_height": VisionTable.TARGET_HEIGHT_M,
		"woods_centers": woods.centers if woods != null else PackedVector2Array(),
		"woods_radii": woods.radii if woods != null else PackedFloat32Array(),
	}


## World XZ of the highest open sample in the start band behind side 0.
func start_position() -> Vector2:
	var front: float = -OPENING_GAP_M * 0.5
	var best: Vector2 = Vector2(0.0, front - START_BEHIND_M.x)
	var best_height: float = -INF
	for z: int in field.resolution:
		for x: int in field.resolution:
			var p: Vector2 = field.sample_position(x, z)
			var behind: float = front - p.y
			if (
				behind >= START_BEHIND_M.x
				and behind <= START_BEHIND_M.y
				and absf(p.x) <= START_HALF_WIDTH_M
				and field.get_sample(x, z) > best_height
				and not woods.contains(p.x, p.y)
			):
				best = p
				best_height = field.get_sample(x, z)
	return best


## Formations of `side`'s front line, from where they stand now (call at the
## start, before anything moves).
func front_line(side: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for f: int in sim.get_formation_count():
		var depth: float = absf(sim.get_formation_center(f).y) - OPENING_GAP_M * 0.5
		# append() returns true on failure.
		if sim.get_formation_side(f) == side and depth < FRONT_LINE_DEPTH_M and out.append(f):
			push_error("BattleWorld: cannot list the front line")
	return out


## Culling box for the army MultiMeshes: the sim's clamp box, from the lowest
## to the highest ground under it plus a soldier's height.
func render_bounds() -> AABB:
	var area: Rect2 = sim.get_bounds().grow(field.spacing)
	var low: float = INF
	var high: float = -INF
	for z: int in field.resolution:
		for x: int in field.resolution:
			if area.has_point(field.sample_position(x, z)):
				low = minf(low, field.get_sample(x, z))
				high = maxf(high, field.get_sample(x, z))
	return AABB(
		Vector3(area.position.x, low - 1.0, area.position.y),
		Vector3(area.size.x, high - low + 1.0 + SOLDIER_HEADROOM_M, area.size.y)
	)
