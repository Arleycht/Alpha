extends Node3D

## Returns the vector aligned to coordinates
static func align_vector(v: Vector3) -> Vector3i:
	return Vector3i(v.floor())


## Returns the AABB that describes the volume between u and v
static func get_aabb(u: Vector3i, v: Vector3i) -> AABB:
	var size: Vector3i = abs(v - u)
	var pos: Vector3i = get_min_axes(u, v)
	return AABB(pos, size)


static func get_min_axes(u: Vector3i, v: Vector3i) -> Vector3i:
	return Vector3i(min(u.x, v.x), min(u.y, v.y), min(u.z, v.z))


static func get_max_axes(u: Vector3i, v: Vector3i) -> Vector3i:
	return Vector3i(max(u.x, v.x), max(u.y, v.y), max(u.z, v.z))


## Calls the function f over all cell positions in a given block.
## Loop can be broken early if f returns true.
static func for_each_cell_YXZ(bpos: Vector3i, f: Callable) -> void:
	var origin := bpos * Constants.BLOCK_SIZE
	
	for j in Constants.BLOCK_SIZE:
		for i in Constants.BLOCK_SIZE:
			for k in Constants.BLOCK_SIZE:
				if f.call(origin + Vector3i(i, j, k)):
					return


static func physics_cast(camera: Camera3D,
		max_distance: float = 100.0) -> PhysicsRaycastResult:
	var params := _get_raycast_params(camera)
	var origin: Vector3 = params[0]
	var to: Vector3 = params[1] * max_distance
	var result := PhysicsRaycastResult.new()
	var result_dict := {}
	var query_params := PhysicsRayQueryParameters3D.new()
	query_params.from = origin
	query_params.to = origin + to
	result_dict = camera.get_world_3d().direct_space_state.intersect_ray(query_params)
	
	if result_dict.is_empty():
		return null
	
	result.collider = result_dict['collider']
	result.normal = result_dict['normal']
	result.position = result_dict['position']
	result.rid = result_dict['rid']
	result.shape = result_dict['shape']
	
	return result


static func voxel_cast(camera: Camera3D, world: World,
		max_distance: float = 100.0) -> VoxelRaycastResult:
	var params := _get_raycast_params(camera)
	var origin: Vector3 = params[0]
	var to: Vector3 = params[1] * max_distance
	return world.tool.raycast(origin, to.normalized(), to.length())


static func _get_raycast_params(camera: Camera3D) -> Array:
	var mouse_pos := camera.get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	return [origin, direction]
