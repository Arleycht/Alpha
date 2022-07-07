class_name World
extends Node3D


signal block_loaded
signal block_unloaded
signal mesh_updated

const BLOCK_SIZE := 16

var _loader: WorldLoader
var _loaded_blocks := {}


func _ready() -> void:
	_loader = WorldLoader.new()
	
	# Test generator
	var generator := VoxelGeneratorNoise2D.new()
	generator.noise = FastNoiseLite.new()
	generator.channel = VoxelBuffer.CHANNEL_TYPE
	generator.height_start = -25
	generator.height_range = 50
	
	# Test mesher
	var mesher := VoxelMesherBlocky.new()
	mesher.library = _loader.library

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	
	var mesh_collision := CollisionShape3D.new()
	mesh_collision.name = "CollisionShape3D"
	
	var buffer = VoxelBuffer.new()
	buffer.create(16, 16, 16)
	generator.generate_block(buffer, Vector3(0, 0, 0), 0)
	mesh_instance.mesh = mesher.build_mesh(buffer, _loader.materials)
	
	if mesh_instance.mesh != null:
		mesh_collision.shape = mesh_instance.mesh.create_trimesh_shape()
	
	add_child(mesh_instance)
	add_child(mesh_collision)
	move_child(mesh_instance, 0)
	move_child(mesh_collision, 1)
	
	for child in find_children("*", "Character", true):
		if "world" in child:
			child.world = self


func set_voxel(position: Vector3i, id: int) -> bool:
	printerr("Set voxel not implemented")
	return true


func get_voxel(position: Vector3i) -> int:
	printerr("Get voxel not implemented")
	return 0


func is_position_loaded(position: Vector3i):
	return to_block_coords(position) in _loaded_blocks


func to_block_coords(v: Vector3) -> Vector3i:
	return Vector3i((v / BLOCK_SIZE).floor())


func to_real_from_block_coords(v: Vector3i) -> Vector3:
	return (v * BLOCK_SIZE) as Vector3


func _load_block(bpos: Vector3i) -> void:
	printerr("Load block not implemented")
	block_loaded.emit(bpos)


func _unload_block(bpos: Vector3i) -> void:
	printerr("Unload block not implemented")
	block_unloaded.emit(bpos)


func _update_mesh() -> void:
	# TODO: Aggregate all loaded block meshes, build if necessary, and display
	# also updates collision mesh because they are technically the same mesh
	printerr("Update mesh not implemented")
	mesh_updated.emit()
