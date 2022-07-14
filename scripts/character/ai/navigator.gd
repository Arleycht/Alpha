class_name Navigator
extends Resource


var unit: Unit
var world: World

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
		var last := (_path_index >= _path.size() - 1)
		
		if last:
			close_enough *= 0.1
		elif close_enough > 0.5:
			close_enough *= 0.4
		else:
			close_enough = 0.4
		
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
			if last:
				_path.clear()
			else:
				_path_index += 1
		
		if Time.get_ticks_msec() - _prev_check_msec > 5000:
			# Stuck, just cancel the path
			if (_prev_pos - unit.position).length_squared() < 2.25:
				_path.clear()
			
			_prev_check_msec = Time.get_ticks_msec()
			_prev_pos = unit.position


func move_to(from: Vector3, to: Vector3) -> void:
	if not unit.is_loaded():
		return
	
	var from_i := Util.align_vector(from)
	var to_i := Util.align_vector(to)
	
	print(" ----- Profiling results: -----")
	
	var w := Stopwatch.new()
	w.start("Pathfinding")
	
	_a_star(from_i, to_i)
	
	w.stop()
	w.print_times()


func move_to_adjacent(from: Vector3, to: Vector3) -> void:
	if not unit.is_loaded():
		return
	
	var positions := get_standable_neighbors(to)
	
	if positions.size() < 1:
		_path.clear()
		return
	
	to = positions[randi_range(0, positions.size() - 1)]
	
	var from_i := Util.align_vector(from)
	var to_i := Util.align_vector(to)
	_a_star(from_i, to_i)


func get_position() -> Vector3:
	if is_path_empty():
		return Vector3.ZERO
	
	return Vector3(_path[_path_index]) + Vector3(0.5, 0, 0.5)


func is_path_empty() -> bool:
	return _path.size() < 1 or _path_index > _path.size() - 1


func get_standable_neighbors(pos: Vector3i) -> Array:
	var neighbors := []
	
	for i in range(-1, 2):
		for j in range(-1, 2):
			for k in range(-1, 2):
				var n := pos + Vector3i(i, j, k)
				
				if world.has_floor(n):
					neighbors.append(n)
	
	return neighbors


func _is_traversable(from: Vector3i, to: Vector3i, clearance_fn: Callable) -> bool:
	var current := from
	var delta := sign(to - from) as Vector3i
	var dx = Vector3i(delta.x, 0, 0)
	var dy = Vector3i(0, delta.y, 0)
	var dz = Vector3i(0, 0, delta.z)
	
	while current != to:
		if current.y != to.y:
			if delta.y > 0:
				if world.is_collidable(current + dy):
					# There is a ceiling, we cannot go up
					return false
				else:
					# Clear to check only horizontals as long as we ascend
					current += dy
			else:
				if world.is_collidable(current + dx) or world.is_collidable(current + dz):
					# Prevent going diagonally down through a wall
					return false
				
				current += dy
		elif current.x != to.x and not world.is_collidable(current + dx):
			if current.z != to.z and world.is_collidable(current + dz):
				# Prevent corner cutting
				return false
			else:
				current += dx
		elif current.z != to.z and not world.is_collidable(current + dz):
			if current.x != to.x and world.is_collidable(current + dx):
				# Prevent corner cutting
				return false
			else:
				current += dz
		else:
			return false
	
	return true


func _cost(a: Vector3i, b: Vector3i) -> float:
	var h := Vector3i(b.x - a.x, 0, b.z - a.z).length_squared() as float
	var v := abs(b.y - a.y) as float
	
	if b.y > a.y:
		# Approximation of 2*sqrt(2) to disincentivize climbing
		v *= 2.8
	else:
		# Incentivize dropping down
		v *= 0
	
	return h + v


func _heuristic(a: Vector3i, b: Vector3i) -> float:
	if b.y < a.y:
		# Only reduce heuristic distance if goal is below us
		a.y = 0
		b.y = 0
	return (b - a).length_squared() as float * 0.5


func _get_neighbors(pos: Vector3i) -> Array:
	var neighbors := []
	
	for j in range(-1, 2):
		for i in range(-1, 2):
			for k in range(-1, 2):
				if i == 0 and j == 0 and k == 0:
					continue

				neighbors.append(pos + Vector3i(i, j, k))
	
	return neighbors


func _get_open_set(from: Vector3i, to: Vector3i) -> Array:
	var explored := {from: true}
	var queue := [from]
	var found := false
	
	var w := Stopwatch.new()
	var w2 := Stopwatch.new()
	
	w.start("Flood fill")
	
	while queue.size() > 0:
		var neighbors := _get_neighbors(queue.pop_back())
		
		if to in neighbors:
			explored[to] = true
			found = true
			break
		else:
			w2.start()
			neighbors = neighbors.filter(func(x): return not x in explored and world.has_floor(x))
			neighbors.map(func(x):
				queue.append(x)
				explored[x] = true
			)
			w2.stop()
	
	var open_set := []
	
	if found:
		open_set = explored.keys()
		open_set.sort_custom(func(a, b):
			return _heuristic(a, to) < _heuristic(b, to)
		)
	
	w2.print_average()
	
	w.stop()
	w.print_times()
	
	return open_set


func _is_accessible(from: Vector3i, to: Vector3i) -> bool:
	print("Islands: %d" % world.islands.size())
	
	# DEBUG CODE
	
#	var _l = [
#		"core:red", "core:light", "core:purple", "core:green", "core:orange",
#	]
#	seed(Time.get_ticks_usec())
#	var _i = randi_range(0, _l.size() - 1)
#	for island in world.islands:
#		for pos in island:
#			world.set_voxel(pos + Vector3i.DOWN, _l[_i])
#		_i = wrapi(_i + 1, 0, _l.size())
	
	# END DEBUG CODE
	
	var from_island
	var to_island
	
#	for island in world.islands:
#		if from in island:
#			from_island = island
#
#		if to in island:
#			to_island = island
#
#		if from_island != null and to_island != null:
#			break
	
	var from_bpos := Util.get_block_pos(from)
	var to_bpos := Util.get_block_pos(to)

	for i in world.island_map[from_bpos]:
		if from in i:
			from_island = i
			break

	for i in world.island_map[to_bpos]:
		if to in i:
			to_island = i
			break
	
	if from_island == null or to_island == null:
		print("Can't find islands for given positions")
		return false
	elif from_island == to_island:
		print("Same island")
		return true
	
	# Early detection
#	for connected_group in world.connected_islands:
#		if from_island in connected_group and to_island in connected_group:
#			return true
#		elif from_island in connected_group or to_island in connected_group:
#			return false
	
	var explored := {from_island: true}
	var queue := [from_island]
	
	while queue.size() > 0:
		var current = queue.pop_back()
		var neighbors = []
		
		for n in _get_neighbors(Util.get_block_pos(current.keys()[0])):
			if n in world.island_map:
				neighbors.append_array(world.island_map[n])
		
		for island in neighbors:
			if not island in explored and world.is_island_connected(current, island):
				if island == to_island:
					return true
				
				queue.append(island)
				explored[island] = true
	
	print("Inaccessible")
	
	return false


func _a_star(from: Vector3i, to: Vector3i,
		clearance_fn: Callable = world.has_floor, cost_fn: Callable = _cost,
		heuristic_fn: Callable = _heuristic, adjacent: bool = false) -> void:
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
	
	if not clearance_fn.call(to) or not unit.world.is_position_loaded(to):
		return
	
	if not _is_accessible(from, to):
		return
	
	var w := Stopwatch.new()
	w.start("Island pathfinding")
	
	var open := [from]
	var map := {}
	var g_score := {}
	var f_score := {}
	
	w.stop()
	w.print_times()
	
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
		
		var neighbors = _get_neighbors(current)
		neighbors = neighbors.filter(func(x):
			return world.is_position_loaded(x) and _is_traversable(current, x, clearance_fn)
		)
		neighbors.shuffle()
		
		for n in neighbors:
			if not clearance_fn.call(n):
				continue
			
			var new_g_score = g_score[current] + cost_fn.call(current, n)
			
			if new_g_score < g_score.get(n, INF):
				map[n] = current
				g_score[n] = new_g_score
				f_score[n] = new_g_score + heuristic_fn.call(n, to)
				
				if n not in open:
					open.append(n)
