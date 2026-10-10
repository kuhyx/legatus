class_name ArmyRenderer
extends Node3D
## Draws every soldier of both sides through RenderingServer MultiMeshes,
## refilled from BattleSim each frame (interpolated between the last two
## ticks). With `near_distance` > 0 each side gets two MultiMeshes: the full
## soldier within that radius of the camera, the 24-triangle stand-in beyond.
## Shadows are off for the crowd (spike); terrain still receives sun shadows.

const TINTS: Array[Color] = [Color(0.62, 0.1, 0.08), Color(0.16, 0.26, 0.55)]
const SHADER: Shader = preload("res://src/sim/soldier.gdshader")

var near_distance: float = 120.0
var _sim: BattleSim
var _meshes: Array[ArrayMesh] = []
var _materials: Array[ShaderMaterial] = []
# Index side * 2 + lod (lod 0 = near/full, 1 = far stand-in).
var _multimeshes: Array[RID] = []
var _instances: Array[RID] = []


func setup(sim: BattleSim, bounds: AABB) -> void:
	_sim = sim
	_meshes = [SoldierMesh.build(false), SoldierMesh.build(true)]
	for side: int in 2:
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("tint", TINTS[side])
		_materials.append(mat)
		for lod: int in 2:
			_add_multimesh(side, lod, bounds)


func _add_multimesh(side: int, lod: int, bounds: AABB) -> void:
	var mm: RID = RenderingServer.multimesh_create()
	RenderingServer.multimesh_allocate_data(
		mm, _sim.get_side_count(side), RenderingServer.MULTIMESH_TRANSFORM_3D, false, true
	)
	RenderingServer.multimesh_set_mesh(mm, _meshes[lod].get_rid())
	RenderingServer.multimesh_set_custom_aabb(mm, bounds)
	RenderingServer.multimesh_set_visible_instances(mm, 0)
	var inst: RID = RenderingServer.instance_create2(mm, get_world_3d().scenario)
	RenderingServer.instance_geometry_set_cast_shadows_setting(
		inst, RenderingServer.SHADOW_CASTING_SETTING_OFF
	)
	RenderingServer.instance_geometry_set_material_override(inst, _materials[side].get_rid())
	_multimeshes.append(mm)
	_instances.append(inst)


## Push this frame's interpolated soldiers to the GPU.
func draw(alpha: float, camera_pos: Vector3) -> void:
	for side: int in 2:
		var near_mm: RID = _multimeshes[side * 2]
		var far_mm: RID = _multimeshes[side * 2 + 1]
		if near_distance <= 0.0:
			RenderingServer.multimesh_set_buffer(near_mm, _sim.fill_transforms(side, alpha))
			RenderingServer.multimesh_set_visible_instances(near_mm, -1)
			continue
		var near: int = _sim.fill_lod(side, alpha, camera_pos, near_distance)
		RenderingServer.multimesh_set_buffer(near_mm, _sim.get_lod_buffer(side, 0))
		RenderingServer.multimesh_set_visible_instances(near_mm, near)
		RenderingServer.multimesh_set_buffer(far_mm, _sim.get_lod_buffer(side, 1))
		RenderingServer.multimesh_set_visible_instances(far_mm, _sim.get_lod_count(side, 1))


func _exit_tree() -> void:
	for rid: RID in _instances + _multimeshes:
		RenderingServer.free_rid(rid)
	_instances.clear()
	_multimeshes.clear()
