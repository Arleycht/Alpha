class_name World
extends Node3D


signal block_loaded
signal block_unloaded
signal mesh_changed

const BLOCK_SIZE := 16

var _loader: WorldLoader
var _stream: VoxelStreamSQLite
var _generator: VoxelGenerator
var _mesher: VoxelMesherBlocky
var _materials: Array
var _loaded_blocks := {}
var _load_queue = []
var _unload_queue = []

var _mesh: ArrayMesh
var _mesh_instance: MeshInstance3D
var _mesh_collision: CollisionShape3D


func _ready() -> void:
	_loader = WorldLoader.new()
	
	# Test generator
	_generator = VoxelGeneratorNoise2D.new()
	_generator.noise = FastNoiseLite.new()
	_generator.channel = VoxelBuffer.CHANNEL_TYPE
	_generator.height_start = -25
	_generator.height_range = 50
	
	# Test mesher
	_mesher = VoxelMesherBlocky.new()
	_mesher.library = _loader.library
	
	_mesh = ArrayMesh.new()

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "MeshInstance3D"
	_mesh_instance.mesh = _mesh
	
	var body := StaticBody3D.new()
	
	_mesh_collision = CollisionShape3D.new()
	_mesh_collision.name = "CollisionShape3D"
	
	add_child(_mesh_instance)
	add_child(body)
	body.add_child(_mesh_collision)
	move_child(_mesh_instance, 0)
	move_child(body, 1)
	
	for child in find_children("*", "Character", true):
		if "world" in child:
			child.world = self
	
	for player in find_children("*", "Player", true):
		if "world" in player:
			player.world = self
	
	for i in 8:
		for j in 8:
			for k in 8:
				_load_block(Vector3i(i - 4, j - 4, k - 4))


func _physics_process(delta: float) -> void:
	if _load_queue.size() > 0:
		_update_mesh()
	
	var env := $WorldEnvironment as EnvironmentManager
	env.time += delta / 60.0


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


func _update_mesh():
	var new_meshes := {}
	
	for bpos in _load_queue:
		var block: Block = _loaded_blocks[bpos]
	
		if block.mesh == null:
			block.mesh = _mesher.build_mesh(block.buffer, _mesher.library.get_materials())
			if block.mesh != null:
				new_meshes[bpos] = block.mesh
	
		_load_queue.erase(bpos)
	
	# TODO: Remove unloaded meshes
	
	var index_offset := 0
	var surface_array := []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	surface_array[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	surface_array[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	surface_array[Mesh.ARRAY_INDEX] = PackedInt32Array()
	
	for i in _mesh.get_surface_count():
		var array := _mesh.surface_get_arrays(i)
		
		for j in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_NORMAL]:
			surface_array[j].append_array(array[j])
		
		for j in array[Mesh.ARRAY_INDEX].size():
			var index: int = array[Mesh.ARRAY_INDEX][j]
			surface_array[Mesh.ARRAY_INDEX].append(index + index_offset)
		
		index_offset += array[Mesh.ARRAY_INDEX].size()
	
	for bpos in new_meshes:
		var new_mesh: Mesh = new_meshes[bpos]
		
		for i in new_mesh.get_surface_count():
			var array := new_mesh.surface_get_arrays(i)
			for j in array[Mesh.ARRAY_VERTEX].size():
				array[Mesh.ARRAY_VERTEX][j] += (bpos * BLOCK_SIZE) as Vector3
			
			for j in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_NORMAL]:
				surface_array[j].append_array(array[j])
			
			for j in array[Mesh.ARRAY_INDEX].size():
				var index: int = array[Mesh.ARRAY_INDEX][j]
				surface_array[Mesh.ARRAY_INDEX].append(index + index_offset)
			
			index_offset += array[Mesh.ARRAY_INDEX].size()
	
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	
	_mesh_instance.material_override = _mesher.library.get_materials()[0]
	
	_mesh_collision.shape = _mesh.create_trimesh_shape()
	mesh_changed.emit()
	
	for bpos in new_meshes:
		block_loaded.emit(bpos)


func _load_block(bpos: Vector3i) -> void:
	if bpos in _loaded_blocks:
		return
	
	if _stream != null:
		# TODO
		pass
	else:
		var block = Block.new()
		block.create(BLOCK_SIZE)
		_generator.generate_block(block.buffer, bpos * BLOCK_SIZE, 0)
		_loaded_blocks[bpos] = block
		_load_queue.append(bpos)


func _unload_block(bpos: Vector3i) -> void:
	printerr("Unload block not implemented")
	block_unloaded.emit(bpos)
