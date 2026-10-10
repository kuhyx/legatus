class_name RideEnvironment
extends RefCounted
## Sky, sun and distance haze for the ride scene. The fog follows Visibility's
## haze: clear to VisionTable.HAZE_START_M, gone by VisionTable.MAX_DISTANCE_M.


static func build() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Environment"
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = _environment()
	root.add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-35.0, 40.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 600.0
	root.add_child(sun)
	return root


static func _environment() -> Environment:
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	# Summer haze: a clear blue zenith over a pale horizon, so the distant
	# haze, the sky and the ground read as three different tones.
	sky_material.sky_top_color = Color(0.3, 0.5, 0.78)
	sky_material.sky_horizon_color = Color(0.75, 0.78, 0.8)
	sky_material.ground_horizon_color = Color(0.75, 0.78, 0.8)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# Full sky ambient flattened the ground to grey-blue. The other half is
	# ambient_light_color (black): the sun carries the shading.
	env.ambient_light_sky_contribution = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.77, 0.8)
	# Depth fog ramps from HAZE_START_M to MAX_DISTANCE_M (density = the fog's
	# maximum, reached at the end): no fog on the near/mid ground, ~0.5 at
	# BLOB_M (the midpoint), terrain gone by 3 km, as Visibility's haze.
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = VisionTable.HAZE_START_M
	env.fog_depth_end = VisionTable.MAX_DISTANCE_M
	env.fog_depth_curve = 1.0
	env.fog_density = 1.0
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.5
	return env
