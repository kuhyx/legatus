class_name RideEnvironment
extends RefCounted
## Sky, sun and distance haze for the ride scene. The fog is tuned so terrain
## fades out around VisionTable.MAX_DISTANCE_M, matching Visibility's haze.


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
	sky_material.sky_horizon_color = Color(0.75, 0.78, 0.8)
	sky_material.ground_horizon_color = Color(0.75, 0.78, 0.8)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.77, 0.8)
	# Exponential fog: ~1 - exp(-density * d). 0.0009 leaves ~7% contrast at 3 km.
	env.fog_density = 0.0009
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.5
	return env
