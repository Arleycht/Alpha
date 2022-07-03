class_name Common
extends Node


static func to_voxel_coords(v: Vector3) -> Vector3i:
	return Vector3i(v.floor())


static func to_real_coords(v: Vector3i) -> Vector3:
	return Vector3(v) + Vector3(0.5, 0.5, 0.5)
