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
var _last_save_ticks := Time.get_ticks_msec()


func _ready() -> void:
	_loader = WorldLoader.new()
	
	await _loader.loaded
	
	_stream = VoxelStreamSQLite.new()
	_stream.database_path = OS.get_user_data_dir() + "/test.db"
	
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
	
	var max_height := 100
	var min_height := -100
	var world_size := 5
	var pos := Vector3(0, min_height, 0)
	var size := Vector3(1, 0, 1) * world_size * Constants.BLOCK_SIZE
	size.y = abs(max_height - min_height)
	
	terrain.stream = _stream
	terrain.mesher = mesher
	terrain.generator = generator
	terrain.max_view_distance = 256
	terrain.bounds = AABB(pos, size)
	
	terrain.name = "VoxelTerrain"
	add_child(terrain)
	move_child(terrain, 0)
	
	terrain.block_loaded.connect(_on_block_loaded)
	terrain.block_unloaded.connect(_on_block_unloaded)
	terrain.mesh_block_loaded.connect(_on_mesh_block_loaded)
	terrain.mesh_block_unloaded.connect(_on_mesh_block_unloaded)


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		terrain.save_modified_blocks()


func _physics_process(delta: float) -> void:
	var env := $WorldEnvironment as EnvironmentManager
	env.time += delta / 60.0
	
	if Time.get_ticks_msec() - _last_save_ticks > 5 * 60 * 1000:
		terrain.save_modified_blocks()
		_last_save_ticks = Time.get_ticks_msec()


func set_voxel(pos: Vector3i, voxel_name: String) -> bool:
	if tool.is_area_editable(AABB(pos, Vector3.ONE)):
		tool.set_voxel(pos, _loader.id_map[voxel_name])
		return true
	
	return false


func get_voxel(pos: Vector3i) -> String:
	return _loader.name_map[tool.get_voxel(pos)]


func is_out_of_bounds(pos: Vector3) -> bool:
	return not terrain.bounds.has_point(pos)


func is_position_loaded(pos: Vector3) -> bool:
	var bpos: Vector3i = Util.align_vector(pos) / Constants.BLOCK_SIZE
	
	if bpos in _loaded_blocks:
		if _loaded_blocks[bpos]:
			# Block has been meshed
			return true
		
		# Empty locations are technically always loaded
		
		var empty := true
		
		Util.for_each_cell_in_block(bpos, func(pos: Vector3i):
			if tool.get_voxel(pos) != 0:
				empty = false
				return true
		)
		
		return empty
	
	return false


func get_block_size() -> int:
	return terrain.get_data_block_size()


func _deferred_mesh_update(bpos: Vector3i, loaded: bool) -> void:
	if bpos in _loaded_blocks:
		_loaded_blocks[bpos] = loaded


func _on_block_loaded(bpos: Vector3i) -> void:
	Util.for_each_cell_in_block(bpos, func(pos: Vector3i):
		if get_voxel(pos) == "core:dirt" and get_voxel(pos + Vector3i(0, 1, 0)) == "core:air":
			set_voxel(pos, "core:grass")
		elif get_voxel(pos) == "core:grass" and get_voxel(pos + Vector3i(0, 1, 0)) != "core:air":
			set_voxel(pos, "core:dirt")
	)
	
	if bpos not in _loaded_blocks:
		_loaded_blocks[bpos] = false


func _on_block_unloaded(bpos: Vector3i) -> void:
	_loaded_blocks.erase(bpos)


func _on_mesh_block_loaded(bpos: Vector3i) -> void:
	call_deferred("_deferred_mesh_update", bpos, true)


func _on_mesh_block_unloaded(bpos: Vector3i) -> void:
	call_deferred("_deferred_mesh_update", bpos, false)
