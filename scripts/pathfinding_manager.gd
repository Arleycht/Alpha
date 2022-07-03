extends AStar3D
class_name PathfindingManager


var voxel_tool: VoxelTool

var _current_goal: Vector3i
var _current_path: Array


func set_path(from: Vector3, to: Vector3) -> void:
	var from_i := Common.to_voxel_coords(from)
	var to_i := Common.to_voxel_coords(to)
	if to_i != _current_goal:
		_current_goal = to_i
		_current_path = _pathfind(from_i, to_i)


func get_current_path() -> Array:
	return _current_path


func increment_path() -> void:
	_current_path.pop_front()


func is_path_empty() -> bool:
	return _current_path == null or _current_path.size() < 1


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
	return abs(b.x - a.x) + abs(b.y - a.y) + abs(b.z - a.z)


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
		heuristic_fn: Callable = _heuristic,
		max_path_length: int = 4096) -> Array:
	## Returns an array of valid path positions that connect two positions or
	## an empty array if no valid path exists.
	##
	## Clearance function should accept two arguments in the form of:
	## VoxelTool, Vector3i
	## and return true if the given position can be cleared by whatever that is
	## finding the path.
	
	if not clearance_fn.call(from) or not clearance_fn.call(to):
		print("From/to invalid")
		return []
	
	var open := [from]
	var map := {}
	var g_score := {}
	var f_score := {}
	
	g_score[from] = 0.0
	f_score[from] = heuristic_fn.call(from, to)
	
	while open.size() > 0:
		var sorted_f_scores = f_score.keys().filter(func(x): return x in open)
		sorted_f_scores.sort_custom(func(a, b): return f_score[a] < f_score[b])
		
		var current = sorted_f_scores[0]
		
		if current == to:
			var path := [current]
			
			while current in map:
				current = map[current]
				path.append(current)
			
			path.reverse()
			return path
		
		open.erase(current)
		
		var neighbors = _get_neighbors(current)
		neighbors.shuffle()
		
		for n in neighbors:
			if not clearance_fn.call(n) or not _is_traversal_clear(current, n):
				continue
			
			var new_g_score = g_score[current] + _cost(current, n)
			
			if n not in g_score or new_g_score < g_score[n]:
				map[n] = current
				g_score[n] = new_g_score
				f_score[n] = new_g_score + heuristic_fn.call(n, to)
				
				if n not in open:
					open.append(n)
	
	return []
