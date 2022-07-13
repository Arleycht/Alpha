class_name Navigator
extends Resource


var unit: Unit

var _path: Array
var _path_index: int
var _prev_check_msec: int
var _prev_pos: Vector3


func update() -> void:
	if not unit.is_loaded():
		return
	
	if not is_path_empty():
		var target := get_position()
		var close_enough := maxf(unit.get_aabb().size.x, unit.get_aabb().size.z)
		var last := (_path_index == _path.size() - 1)
		
		if last:
			close_enough *= 0.1
		elif close_enough > 0.5:
			close_enough *= 0.5
		else:
			close_enough = 0.5
		
		# TODO: Check if the current waypoint is part of a horizontal corner
		# that is blocked on one side, and adjust the waypoint to make the
		# path and movement smoother
		
		# Move unit
		
		var diff := target - unit.position
		var h_diff := Plane.PLANE_XZ.project(diff)
		unit.wish_vector = h_diff.normalized() * clampf(h_diff.length(), 0.1, 1)
		
		if diff.y > unit.jump_height * 0.75:
			if h_diff.length_squared() < 2 and not unit.is_jumping():
				unit.jump()
		elif diff.y < -0.75 or last:
			# Precision movement mode for descending and last waypoint
			const speed_limit := 2.5
			var speed := Plane.PLANE_XZ.project(unit.velocity).length()
			
			if speed > speed_limit:
				unit.wish_vector *= -1
		
		# Increment path position
		
		if h_diff.length_squared() < pow(close_enough, 2) and abs(diff.y) < 0.5:
			increment_position()
		
		if Time.get_ticks_msec() - _prev_check_msec > 5000:
			if (_prev_pos - unit.position).length_squared() < 2.25:
				_path.clear()
			
			_prev_check_msec = Time.get_ticks_msec()
			_prev_pos = unit.position


func move_to(from: Vector3, to: Vector3) -> void:
	if not unit.is_loaded():
		return
	
	var from_i := Util.align_vector(from)
	var to_i := Util.align_vector(to)
	_pathfind(from_i, to_i)


func get_position() -> Vector3:
	if is_path_empty():
		return Vector3.ZERO
	
	return Vector3(_path[_path_index]) + Vector3(0.5, 0, 0.5)


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
	var voxel_id: String = unit.get_world().get_voxel(pos)
	# TODO: Get these from configuration, i.e. voxels tagged with something
	# that says they are a valid floor voxel
	return voxel_id not in ["core:air"]


func _is_valid_air(pos: Vector3i) -> bool:
	var voxel_id: String = unit.get_world().get_voxel(pos)
	# TODO: Get these from configuration
	return voxel_id in ["core:air"]


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


func _is_traversal_clear(from: Vector3i, to: Vector3i, clearance_fn: Callable) -> bool:
	var current := from
	var delta := sign(to - from) as Vector3i
	var dx = Vector3i(delta.x, 0, 0)
	var dy = Vector3i(0, delta.y, 0)
	var dz = Vector3i(0, 0, delta.z)
	
	while current != to:
		if current.x != to.x and clearance_fn.call(current + dx):
			current += dx
		elif current.z != to.z and clearance_fn.call(current + dz):
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
	# If the character is standing over an invalid position, but is actually
	# standing on the edge of a valid position, try to find the valid position
	# and use it as the origin instead
	if not clearance_fn.call(from):
		var found := false
		var w := ceil(unit.get_aabb().get_longest_axis_size()) as int
		for i in range(-w, w + 1):
			for j in range(-w, w + 1):
				if clearance_fn.call(from + Vector3i(i, 0, j)):
					from += Vector3i(i, 0, j)
					found = true
					break
			
			if found:
				break
		
		if not found:
			return
	
	if not clearance_fn.call(to) or not unit.get_world().is_position_loaded(to):
		return
	
	var open := [from]
	var map := {}
	var length := {}
	var g_score := {}
	var f_score := {}
	
	length[from] = 0
	g_score[from] = 0.0
	f_score[from] = heuristic_fn.call(from, to)
	
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
		
		for n in neighbors:
			if not unit.get_world().is_position_loaded(n):
				continue
			
			if not clearance_fn.call(n) or not _is_traversal_clear(current, n, clearance_fn):
				continue
			
			var new_g_score = g_score[current] + cost_fn.call(current, n)
			
			if n not in g_score or new_g_score < g_score[n]:
				map[n] = current
				length[n] = length[current] + 1
				g_score[n] = new_g_score
				f_score[n] = new_g_score + heuristic_fn.call(n, to)
				
				if n not in open:
					open.append(n)
