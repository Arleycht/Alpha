class_name World
extends Node3D


signal block_loaded
signal block_unloaded
signal mesh_changed
signal voxel_updated

var loader: WorldLoader

var _stream: VoxelStreamSQLite

var terrain: VoxelTerrain
var tool: VoxelToolTerrain

var island_map := {}
var islands := []

var _loaded_blocks := {}
var _last_save_ticks := Time.get_ticks_msec()


func _ready() -> void:
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
	mesher.library = loader.library
	
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
		tool.set_voxel(pos, loader.id_map[voxel_name])
		return true
	
	return false


func get_voxel(pos: Vector3) -> String:
	return loader.name_map[tool.get_voxel(Util.align_vector(pos))]


func get_definition(voxel_name: String) -> Dictionary:
	return loader.voxel_definitions.get(voxel_name, {})


func has_floor(pos: Vector3) -> bool:
	if Util.get_block_pos(pos) not in _loaded_blocks:
		return false
	return not is_collidable(pos) and is_collidable(pos + Vector3(0, -1, 0))


## Returns true if the voxel at the position has collision
func is_collidable(pos: Vector3) -> bool:
	var voxel_name := get_voxel(pos)
	
	if voxel_name == "core:air":
		return false
	
	if voxel_name not in loader.voxel_definitions:
		return false
	
	if 'can_collide' in loader.voxel_definitions[voxel_name]:
		return loader.voxel_definitions[voxel_name]['can_collide'] as bool
	
	return true


## Returns true if the voxel at the position can be passed, possibly with
## interaction (i.e. doors)
func is_passable(pos: Vector3) -> bool:
	var def := get_definition(get_voxel(pos))
	
	if 'interactions' in def and 'door' in def['interactions']:
		return true
	
	return false


func is_out_of_bounds(pos: Vector3) -> bool:
	return not terrain.bounds.has_point(pos)


func is_obstructed(pos: Vector3) -> bool:
	if is_collidable(pos):
		return true
	else:
		var aabb := AABB(pos, Vector3.ONE)
		
		for character in find_children("*", "Character", true, false):
			if aabb.intersects(character.get_aabb()):
				return true
	
	return false


func is_position_loaded(pos: Vector3) -> bool:
	var bpos: Vector3i = Util.get_block_pos(pos)
	
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


func get_standable_in_block(bpos: Vector3i) -> Array:
	var positions := []
	
	Util.for_each_cell_in_block(bpos, func(x):
		if not is_collidable(x) and is_collidable(x + Vector3i(0, 1, 0)):
			positions.append(x)
	)
	
	return positions


func get_all_neighbors_in_block(bpos: Vector3i, pos: Vector3i) -> Array:
	var explored := {pos: true}
	var queue := [pos]
	
	while queue.size() > 0:
		var neighbors := Util.get_neighbors(queue.pop_back()).filter(func(x):
			return not x in explored and has_floor(x)
		)
		neighbors.map(func(x):
			if Util.get_block_pos(x) == bpos:
				queue.append(x)
				explored[x] = true
		)
	
	return explored.keys()


func is_neighbor(u: Vector3i, v: Vector3i) -> bool:
	var diff := Vector3(u - v).abs()
	var distance: int = max(diff.x, diff.y, diff.z)
	return distance == 1


func is_island_connected(a: Dictionary, b: Dictionary) -> bool:
	var explored := {}
	
	for u in a['cells'].keys():
		if not u in explored:
			explored[u] = true
			
			for n in Util.get_neighbors(u):
				if n in b['cells']:
					return true
				else:
					explored[n] = true
	
	return false


func is_edge_of_block(pos: Vector3i) -> bool:
	pos = pos.abs() % Constants.BLOCK_SIZE
	
	return pos.x == 0 or pos.x == Constants.BLOCK_SIZE - 1 \
			or pos.y == 0 or pos.y == Constants.BLOCK_SIZE - 1 \
			or pos.z == 0 or pos.z == Constants.BLOCK_SIZE - 1


func get_islands(bpos: Vector3i) -> Array:
	var explored := {}
	var block_islands := []
	
	Util.for_each_cell_in_block(bpos, func(u):
		# Only consider valid positions
		if u not in explored and has_floor(u):
			# Try to add u to an existing island
			for island in block_islands:
				if island['cells'].keys().any(func(v): return is_neighbor(u, v)):
					explored[u] = true
					island['cells'][u] = true
					return false
			
			# Create a new island if none contain u
			var cells := {}
			get_all_neighbors_in_block(bpos, u).map(func(x):
				cells[x] = true
				explored[x] = true
			)
			block_islands.append({
				'position': bpos,
				'cells': cells,
			})
		
		return false
	)
	
	return block_islands


func _deferred_mesh_update(bpos: Vector3i, loaded: bool) -> void:
	if bpos in _loaded_blocks:
		_loaded_blocks[bpos] = loaded


func _on_block_loaded(bpos: Vector3i) -> void:
	Util.for_each_cell_in_block(bpos, func(pos: Vector3i):
		if get_voxel(pos) == "core:dirt" and get_voxel(pos + Vector3i(0, 1, 0)) == "core:air":
			set_voxel(pos, "core:grass")
		elif get_voxel(pos) == "core:grass" and get_voxel(pos + Vector3i(0, 1, 0)) != "core:air":
			set_voxel(pos, "core:dirt")
		
		await get_tree().create_timer(0.1).timeout
	)
	
	if bpos not in _loaded_blocks:
		_loaded_blocks[bpos] = false
	
	var block_islands := get_islands(bpos)
	
	if block_islands.size() > 0:
		island_map[bpos] = block_islands
		islands.append_array(block_islands)

		print("Pathfinding islands: %d" % islands.size())


func _on_block_unloaded(bpos: Vector3i) -> void:
	_loaded_blocks.erase(bpos)
	
	if bpos in island_map:
		for island in island_map[bpos]:
			islands.erase(island)
	
	island_map.erase(bpos)


func _on_mesh_block_loaded(bpos: Vector3i) -> void:
	call_deferred("_deferred_mesh_update", bpos, true)


func _on_mesh_block_unloaded(bpos: Vector3i) -> void:
	call_deferred("_deferred_mesh_update", bpos, false)
