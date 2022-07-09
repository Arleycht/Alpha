extends Node3D

# Initialization constants

const BLOCK_SIZE := 16
const MODULES_PATH := "user://modules"
const CORE_MODULE_PATH := "res://modules/core"
const DEFAULT_TEXTURE_PATH := "res://modules/core/textures/null.png"
const DEFAULT_TEXTURE_ID := "core/null.png"


## Returns the vector aligned to coordinates
static func align_vector(v: Vector3) -> Vector3i:
	return Vector3i(v.floor())


static func physics_cast(camera: Camera3D, origin: Vector3, to: Vector3) -> PhysicsRaycastResult:
	## Wrapper around PhysicsDirectSpaceState3D.intersect_ray
	var result := PhysicsRaycastResult.new()
	var result_dict := {}
	var params := PhysicsRayQueryParameters3D.new()
	params.from = origin
	params.to = origin + to
	result_dict = camera.get_world_3d().direct_space_state.intersect_ray(params)
	
	if result_dict.is_empty():
		return null
	
	result.collider = result_dict['collider']
	result.normal = result_dict['normal']
	result.position = result_dict['position']
	result.rid = result_dict['rid']
	result.shape = result_dict['shape']
	
	return result


static func voxel_cast(world: World, origin: Vector3, to: Vector3) -> VoxelRaycastResult:
	return world.tool.raycast(origin, to.normalized(), to.length())
