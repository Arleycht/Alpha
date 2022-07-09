class_name World
extends Node3D


signal block_loaded
signal block_unloaded
signal mesh_changed


var _loader: WorldLoader
var _stream: VoxelStreamSQLite

var terrain: VoxelTerrain
var tool: VoxelToolTerrain

var _loaded_blocks := {}


func _ready() -> void:
	_loader = WorldLoader.new()
	_stream = VoxelStreamSQLite.new()
	
	# Test generator
	var generator := VoxelGeneratorNoise2D.new()
	generator.noise = FastNoiseLite.new()
	generator.channel = VoxelBuffer.CHANNEL_TYPE
	generator.height_start = -25
	generator.height_range = 50
	
	# Test mesher
	var mesher := VoxelMesherBlocky.new()
	mesher.library = _loader.library
	
	terrain = VoxelTerrain.new()
	tool = terrain.get_voxel_tool()
	
	terrain.mesher = mesher
	terrain.generator = generator
	terrain.max_view_distance = 192
	
	terrain.name = "VoxelTerrain"
	add_child(terrain)
	move_child(terrain, 0)
	
	terrain.block_loaded.connect(_on_block_loaded)
	terrain.block_unloaded.connect(_on_block_unloaded)
	terrain.mesh_block_loaded.connect(_on_mesh_block_loaded)
	terrain.mesh_block_unloaded.connect(_on_mesh_block_unloaded)


func _physics_process(delta: float) -> void:
	var env := $WorldEnvironment as EnvironmentManager
	env.time += delta / 60.0


func set_voxel(pos: Vector3i, id: int) -> bool:
	if tool.is_area_editable(AABB(pos, Vector3.ONE)):
		tool.set_voxel(pos, id)
		return true
	
	return false


func get_voxel(pos: Vector3i) -> int:
	return tool.get_voxel(pos)


func is_aabb_uniform(aabb: AABB, id: int) -> bool:
	if not terrain.bounds.encloses(aabb):
		return id == 0
	
	for i in aabb.size.x:
		for j in aabb.size.y:
			for k in aabb.size.z:
				var delta := Vector3(i, j, k)
				if tool.get_voxel(aabb.position + delta) != id:
					return false
	
	return true


func is_position_loaded(pos: Vector3) -> bool:
	var bpos := Globals.align_vector(pos)
	
	if bpos in _loaded_blocks:
		if _loaded_blocks[bpos]:
			# Block has been meshed
			return true
		
		# Empty locations are technically always loaded
		var aabb := AABB(bpos * Globals.BLOCK_SIZE, Vector3.ONE * Globals.BLOCK_SIZE)
		return is_aabb_uniform(aabb, 0)
	
	return false


func get_block_size() -> int:
	return terrain.get_data_block_size()


func _deferred_mesh_update(bpos: Vector3i, loaded: bool) -> void:
	if bpos in _loaded_blocks:
		_loaded_blocks[bpos] = loaded


func _on_block_loaded(bpos: Vector3i) -> void:
	if bpos not in _loaded_blocks:
		_loaded_blocks[bpos] = false


func _on_block_unloaded(bpos: Vector3i) -> void:
	_loaded_blocks.erase(bpos)


func _on_mesh_block_loaded(bpos: Vector3i) -> void:
	call_deferred("_deferred_mesh_update", bpos, true)


func _on_mesh_block_unloaded(bpos: Vector3i) -> void:
	call_deferred("_deferred_mesh_update", bpos, false)
