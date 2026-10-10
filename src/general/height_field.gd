class_name HeightField
extends RefCounted
## Square heightmap centred on the world origin, CPU-side.
##
## One index convention everywhere (this, the render mesh and the
## HeightMapShape3D): row-major, x fastest, heights[z_index * resolution +
## x_index], sample (0, 0) at world (-half_size, -half_size). resolution is
## odd so the centre sample sits exactly on the origin, like HeightMapShape3D.

## Samples per side (odd).
var resolution: int = 0
## Metres between neighbouring samples.
var spacing: float = 1.0
var heights: PackedFloat32Array = PackedFloat32Array()


func _init(samples_per_side: int, sample_spacing: float) -> void:
	resolution = samples_per_side
	spacing = sample_spacing
	if heights.resize(resolution * resolution) != OK:
		push_error("HeightField: cannot allocate %d samples" % (resolution * resolution))
	heights.fill(0.0)


## Hilly field from seeded simplex noise. amplitude is the rough peak height.
static func from_noise(
	noise_seed: int, samples_per_side: int, sample_spacing: float, amplitude: float
) -> HeightField:
	var field: HeightField = HeightField.new(samples_per_side, sample_spacing)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.frequency = 1.0 / 1400.0
	# Fill a local array and assign once: indexing field.heights per sample
	# would go through the property and copy the whole array each time.
	var values: PackedFloat32Array = field.heights
	for z: int in samples_per_side:
		for x: int in samples_per_side:
			var pos: Vector2 = field.sample_position(x, z)
			# Shift to 0..1 then square: broad flat-ish plains, rounded hills.
			var n: float = (noise.get_noise_2d(pos.x, pos.y) + 1.0) * 0.5
			values[z * samples_per_side + x] = n * n * amplitude
	field.heights = values
	return field


## Edge length in metres.
func size() -> float:
	return spacing * float(resolution - 1)


## World XZ of sample (x_index, z_index), as Vector2(x, z).
func sample_position(x_index: int, z_index: int) -> Vector2:
	var half: float = size() * 0.5
	return Vector2(float(x_index) * spacing - half, float(z_index) * spacing - half)


func get_sample(x_index: int, z_index: int) -> float:
	var x: int = clampi(x_index, 0, resolution - 1)
	var z: int = clampi(z_index, 0, resolution - 1)
	return heights[z * resolution + x]


func set_sample(x_index: int, z_index: int, value: float) -> void:
	heights[z_index * resolution + x_index] = value


## Bilinear ground height at world (x, z); clamps outside the field.
func height_at(x: float, z: float) -> float:
	var half: float = size() * 0.5
	var gx: float = clampf((x + half) / spacing, 0.0, float(resolution - 1))
	var gz: float = clampf((z + half) / spacing, 0.0, float(resolution - 1))
	var x0: int = mini(int(gx), resolution - 2)
	var z0: int = mini(int(gz), resolution - 2)
	var fx: float = gx - float(x0)
	var fz: float = gz - float(z0)
	var row0: float = lerpf(get_sample(x0, z0), get_sample(x0 + 1, z0), fx)
	var row1: float = lerpf(get_sample(x0, z0 + 1), get_sample(x0 + 1, z0 + 1), fx)
	return lerpf(row0, row1, fz)


## Mean sample height inside an XZ rectangle (0 if no sample falls in it).
func mean_height(area: Rect2) -> float:
	var total: float = 0.0
	var count: int = 0
	for z: int in resolution:
		for x: int in resolution:
			if area.has_point(sample_position(x, z)):
				total += get_sample(x, z)
				count += 1
	return total / float(count) if count > 0 else 0.0


## Level an XZ rectangle to `height` (a battle plain) and ease back to the
## original relief over `blend` metres outside it with a smoothstep, so the
## plain's edge has no cliff. Samples further out are untouched.
func flatten_rect(area: Rect2, height: float, blend: float) -> void:
	var values: PackedFloat32Array = heights
	for z: int in resolution:
		for x: int in resolution:
			var p: Vector2 = sample_position(x, z)
			var dx: float = maxf(maxf(area.position.x - p.x, p.x - area.end.x), 0.0)
			var dz: float = maxf(maxf(area.position.y - p.y, p.y - area.end.y), 0.0)
			var keep: float = smoothstep(0.0, maxf(blend, 1e-3), Vector2(dx, dz).length())
			var i: int = z * resolution + x
			values[i] = lerpf(height, values[i], keep)
	heights = values


## Surface normal from central differences (for the render mesh).
func normal_at_sample(x_index: int, z_index: int) -> Vector3:
	var dx: float = get_sample(x_index + 1, z_index) - get_sample(x_index - 1, z_index)
	var dz: float = get_sample(x_index, z_index + 1) - get_sample(x_index, z_index - 1)
	return Vector3(-dx, 2.0 * spacing, -dz).normalized()
