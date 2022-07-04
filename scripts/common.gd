class_name Common


static func to_voxel_coords(v: Vector3) -> Vector3i:
	return Vector3i(v.floor())


static func to_real_coords(v: Vector3i) -> Vector3:
	return Vector3(v) + Vector3(0.5, 0.5, 0.5)


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


static func voxel_cast(voxel_tool: VoxelTool, origin: Vector3, to: Vector3) -> VoxelRaycastResult:
	return voxel_tool.raycast(origin, to.normalized(), to.length())
