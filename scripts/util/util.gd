extends Node3D

## Returns the vector aligned to coordinates
static func align_vector(v: Vector3) -> Vector3i:
	return Vector3i(v.floor())


static func get_block_pos(v: Vector3) -> Vector3i:
	return align_vector(v / Constants.BLOCK_SIZE)


## Returns the AABB that describes the volume between u and v
static func get_aabb(u: Vector3i, v: Vector3i) -> AABB:
	var size: Vector3i = abs(v - u)
	var pos: Vector3i = get_min_pos(u, v)
	return AABB(pos, size)


static func get_min_pos(u: Vector3i, v: Vector3i) -> Vector3i:
	return Vector3i(min(u.x, v.x), min(u.y, v.y), min(u.z, v.z))


static func get_max_pos(u: Vector3i, v: Vector3i) -> Vector3i:
	return Vector3i(max(u.x, v.x), max(u.y, v.y), max(u.z, v.z))


## Calls the function f over all cell positions in a given AABB.
## Loop can be broken early if f returns true.
static func for_each_cell(aabb: AABB, f: Callable) -> void:
	var start := align_vector(aabb.position)
	var end := align_vector(aabb.end)
	
	for j in end.y - start.y + 1:
		for i in end.x - start.x + 1:
			for k in end.z - start.z + 1:
				if f.call(start + Vector3i(i, j, k)):
					return


## Calls the function f over all cell positions in a given block.
## Loop can be broken early if f returns true.
static func for_each_cell_in_block(bpos: Vector3i, f: Callable) -> void:
	var pos := bpos * Constants.BLOCK_SIZE
	var size := Vector3i.ONE * Constants.BLOCK_SIZE
	for_each_cell(AABB(pos, size), f)


static func get_cells(aabb: AABB) -> Array:
	var positions := []
	var start := align_vector(aabb.position)
	var end := align_vector(aabb.end)
	
	for j in end.y - start.y + 1:
		for i in end.x - start.x + 1:
			for k in end.z - start.z + 1:
				positions.append(start + Vector3i(i, j, k))
	
	return positions


static func raycast(world3d: World3D, from: Vector3, to: Vector3) -> Dictionary:
	var result_dict := {}
	var query_params := PhysicsRayQueryParameters3D.new()
	query_params.from = from
	query_params.to = from + to
	result_dict = world3d.direct_space_state.intersect_ray(query_params)
	
	if result_dict.is_empty():
		return {
			'collider': null,
			'normal': Vector3.ZERO,
			'position': to,
			'rid': null,
			'shape': null,
		}
	else:
		return result_dict


static func raycast_from_screen(camera: Camera3D,
		max_distance: float = 100.0) -> Dictionary:
	var mouse_pos := camera.get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	var to: Vector3 = direction * max_distance
	return raycast(camera.get_world_3d(), from, to)


static func voxel_cast(world: World, from: Vector3, direction: Vector3,
		max_distance: float = 100.0) -> Dictionary:
	var result := world.tool.raycast(from, direction, max_distance)
	
	if result == null:
		return {
			'hit': false,
			'previous_position': align_vector(from),
			'position': align_vector(direction * max_distance),
		}
	else:
		return {
			'hit': true,
			'previous_position': result.previous_position,
			'position': result.position,
		}


static func voxel_cast_from_screen(world: World, camera: Camera3D,
		max_distance: float = 100.0) -> Dictionary:
	var mouse_pos := camera.get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	return voxel_cast(world, from, direction, max_distance)
