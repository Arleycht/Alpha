class_name Navigator
extends Resource


var character: CharacterController3D
var voxel_tool: VoxelTool

var _path: Array
var _path_index: int
var _prev_check_msec: int
var _prev_pos: Vector3


func _init(character: CharacterController3D, voxel_tool: VoxelTool) -> void:
	self.character = character
	self.voxel_tool = voxel_tool


func update() -> void:
	if not is_path_empty():
		var target := get_position()
		var close_enough := maxf(character.get_aabb().size.x, character.get_aabb().size.z)
		
		if close_enough > 0.5:
			close_enough *= 0.25
		else:
			close_enough = 0.5
		
		# Move character
		
		var diff := target - character.position
		var h_diff := Plane.PLANE_XZ.project(diff)
		var direction := h_diff.limit_length()
		character.wish_vector = direction
		
		if diff.y > character.jump_height * 0.75:
			if h_diff.length_squared() < 2 and not character.is_jumping():
				character.jump()
		elif diff.y < -0.75:
			# Make proportional to the drop height?
			const speed_limit := 2.5
			var speed := Plane.PLANE_XZ.project(character.velocity).length()
			
			if speed > speed_limit:
				character.wish_vector *= 1 - clampf(speed / speed_limit, 0, 1)
			else:
				character.wish_vector *= speed_limit / character.max_speed
		
		# Increment path position
		
		if h_diff.length_squared() < pow(close_enough, 2) and abs(diff.y) < 0.5:
			increment_position()
		
		if Time.get_ticks_msec() - _prev_check_msec > 5000:
			if (_prev_pos - character.position).length_squared() < 2.25:
				_path.clear()
			
			_prev_check_msec = Time.get_ticks_msec()
			_prev_pos = character.position


func move_to(from: Vector3, to: Vector3) -> void:
	var from_i := Common.to_voxel_coords(from)
	var to_i := Common.to_voxel_coords(to)
	_pathfind(from_i, to_i)


func get_position() -> Vector3:
	if is_path_empty():
		return Vector3.ZERO
	
	return Common.to_real_coords(_path[_path_index]) - Vector3(0, 0.5, 0)


func increment_position() -> void:
	_path_index += 1


func set_path_index(i: int) -> void:
	_path_index = i


func get_path_index() -> int:
	return _path_index


func get_path_length() -> int:
	return _path.size()


func is_path_empty() -> bool:
	return _path.size() < 1 or _path_index > _path.size() - 1


func _is_valid_floor(pos: Vector3i) -> bool:
	var voxel_id := voxel_tool.get_voxel(pos)
	# TODO: Get these from configuration, i.e. voxels tagged with something
	# that says they are a valid floor voxel
	return voxel_id in [1]


func _is_valid_air(pos: Vector3i) -> bool:
	var voxel_id := voxel_tool.get_voxel(pos)
	# TODO: Get these from configuration
	return voxel_id in [0]


func _is_valid_standing_position(pos: Vector3i) -> bool:
	return _is_valid_floor(pos - Vector3i(0, 1, 0)) and _is_valid_air(pos)


func _cost(a: Vector3i, b: Vector3i) -> float:
	var h := Vector3i(b.x - a.x, 0, b.z - a.z).length_squared() as float
	var v := abs(b.y - a.y) as float
	
	if b.y > a.y:
		# Approximation of 2*sqrt(2) to disincentivize climbing
		v *= 2.8
	else:
		# Incentivize dropping down
		v = 0
	
	return h + v


func _heuristic(a: Vector3i, b: Vector3i) -> float:
	a.y = 0
	b.y = 0
	return (b - a).length_squared() as float * 0.5


func _is_traversal_clear(from: Vector3i, to: Vector3i) -> bool:
	var current := from
	var delta := sign(to - from) as Vector3i
	var dx = Vector3i(delta.x, 0, 0)
	var dy = Vector3i(0, delta.y, 0)
	var dz = Vector3i(0, 0, delta.z)
	
	var i = 0
	
	while current != to:
		if current.x != to.x and _is_valid_standing_position(current + dx):
			current += dx
		elif current.z != to.z and _is_valid_standing_position(current + dz):
			current += dz
		elif current.y != to.y:
			if delta.y > 0 and !_is_valid_air(current + dy):
				return false
			else:
				current += dy
		else:
			return false
	
	return true


func _get_neighbors(pos: Vector3i) -> Array:
	var neighbors := []
	
	for i in range(-1, 2):
		for j in range(-1, 2):
			for k in range(-1, 2):
				if i == 0 and j == 0 and k == 0:
					continue
				
				neighbors.append(pos + Vector3i(i, j, k))
	
	return neighbors


func _pathfind(from: Vector3i, to: Vector3i,
		clearance_fn: Callable = _is_valid_standing_position,
		cost_fn: Callable = _cost, heuristic_fn: Callable = _heuristic,
		max_path_length: int = 1024) -> void:
	if not clearance_fn.call(from):
		var found := false
		for i in range(-1, 2):
			for j in range(-1, 2):
				if clearance_fn.call(from + Vector3i(i, 0, j)):
					from += Vector3i(i, 0, j)
					found = true
					break
			
			if found:
				break
		
		if not found:
			return
	
	if not clearance_fn.call(to):
		return
	
	var open := [from]
	var map := {}
	var length := {}
	var g_score := {}
	var f_score := {}
	
	length[from] = 0
	g_score[from] = 0.0
	f_score[from] = heuristic_fn.call(from, to)
	
	var count := 0
	
	while open.size() > 0:
		var sorted_f_scores = f_score.keys().filter(func(x): return x in open)
		sorted_f_scores.sort_custom(func(a, b): return f_score[a] < f_score[b])
		
		var current = sorted_f_scores[0]
		
		if current == to:
			_path = [current]
			
			while current in map:
				current = map[current]
				_path.append(current)
			
			_path.reverse()
			_path_index = 0
			_prev_check_msec = Time.get_ticks_msec()
			
			return
		
		open.erase(current)
		
		if length[current] >= max_path_length:
			continue
		
		var neighbors = _get_neighbors(current)
		neighbors.shuffle()
		
		count += 1
		
		for n in neighbors:
			if not voxel_tool.is_area_editable(AABB(n, Vector3.ONE)):
				continue
			
			if not clearance_fn.call(n) or not _is_traversal_clear(current, n):
				continue
			
			var new_g_score = g_score[current] + _cost(current, n)
			
			if n not in g_score or new_g_score < g_score[n]:
				map[n] = current
				length[n] = length[current] + 1
				g_score[n] = new_g_score
				f_score[n] = new_g_score + heuristic_fn.call(n, to)
				
				if n not in open:
					open.append(n)
