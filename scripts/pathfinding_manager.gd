class_name PathfindingManager


var voxel_tool: VoxelTool

var _thread := Thread.new()
var _data_ready := Semaphore.new()
var _stop_signal := Semaphore.new()
var _stop_response := Semaphore.new()
var _pathfind_data := {
	'from': Vector3i(),
	'to': Vector3i(),
	'ready': true,
	'clearance_fn': _is_valid_standing_position,
	'cost_fn': _cost,
	'heuristic_fn': _heuristic,
	'path': [],
}


func _init(vt: VoxelTool) -> void:
	voxel_tool = vt
	_thread.start(_pathfind_thread)


func set_path(from: Vector3, to: Vector3) -> void:
	var from_i := Common.to_voxel_coords(from)
	var to_i := Common.to_voxel_coords(to)
	var stale := false
	
	if is_path_empty() or from_i != _pathfind_data['path'][0] or to_i != _pathfind_data['path'][-1]:
		stop()
		_pathfind_data['from'] = from_i
		_pathfind_data['to'] = to_i
		_pathfind_data['ready'] = false
		_data_ready.post()


func is_ready() -> bool:
	return _pathfind_data['ready'] as bool


func stop() -> void:
	if is_ready():
		return
	
	var t := Thread.new()
	t.start(_stop_response.wait)
	_stop_signal.post()
	t.wait_to_finish()


func get_current() -> Vector3:
	return Common.to_real_coords(_pathfind_data['path'].back()) - Vector3(0, 0.5, 0)


func increment_path() -> void:
	# Probably not thread safe
	_pathfind_data['path'].pop_back()


func is_path_empty() -> bool:
	return _pathfind_data['path'].size() < 1


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


func _pathfind_thread() -> void:
	while true:
		_data_ready.wait()
		
		var from := _pathfind_data['from'] as Vector3i
		var to := _pathfind_data['to'] as Vector3i
		var clearance_fn := _pathfind_data['clearance_fn'] as Callable
		var cost_fn := _pathfind_data['cost_fn'] as Callable
		var heuristic_fn := _pathfind_data['heuristic_fn'] as Callable
		
		if not clearance_fn.call(from) or not clearance_fn.call(to):
			continue
		
		var open := [from]
		var map := {}
		var g_score := {}
		var f_score := {}
		
		g_score[from] = 0.0
		f_score[from] = heuristic_fn.call(from, to)
		
		while open.size() > 0:
			if _stop_signal.try_wait() == OK:
				_pathfind_data['path'] = []
				_pathfind_data['ready'] = true
				_stop_response.post()
				break
			
			var sorted_f_scores = f_score.keys().filter(func(x): return x in open)
			sorted_f_scores.sort_custom(func(a, b): return f_score[a] < f_score[b])
			
			var current = sorted_f_scores[0]
			
			if current == to:
				var path := [current]
				
				while current in map:
					current = map[current]
					path.append(current)
				
				_pathfind_data['path'] = path
				_pathfind_data['ready'] = true
				break
			
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
