extends Control


enum SelectionState {
	VOXELS,
	OBJECTS,
}

var terrain: VoxelTerrain
var voxel_tool: VoxelTool

var selection_state := SelectionState.VOXELS
var selection: Array

var _object_markers: Array
var _marker_scene := preload("res://scenes/marker.tscn")


func _ready() -> void:
	if get_parent() is Player:
		var player := get_parent() as Player
		player.terrain_loaded.connect(func(t, vt):
			terrain = t
			voxel_tool = vt
		)
	else:
		printerr("HUD is not parented to a player")


func _input(event: InputEvent) -> void:
	if terrain == null or voxel_tool == null:
		return
	
	if event.is_action_pressed("primary"):
		var p_result := physics_cast()
		
		if p_result != null and is_currently_selectable(p_result.collider):
			if not Input.is_action_pressed("shift"):
				clear_selection()
			
			select_object(p_result.collider)
			
			get_viewport().set_input_as_handled()
			return
		
		var v_result := voxel_cast()
		
		if v_result != null and is_currently_selectable(v_result.position):
			for object in selection:
				if object is Anthropoid:
					object.move_to(v_result.position + Vector3i(0, 1, 0))
			
			get_viewport().set_input_as_handled()
			return
		
		clear_selection()


func physics_cast(max_distance: float = 100.0) -> PhysicsRaycastResult:
	var camera := get_camera()
	var mouse_pos := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	return Common.physics_cast(camera, origin, direction * max_distance)


func voxel_cast(max_distance: float = 100.0) -> VoxelRaycastResult:
	var camera := get_camera()
	var mouse_pos := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	return Common.voxel_cast(voxel_tool, origin, direction * max_distance)


func is_currently_selectable(object) -> bool:
	if selection.is_empty():
		if object is Node:
			selection_state = SelectionState.OBJECTS
		elif object is Vector3i:
			selection_state = SelectionState.VOXELS
		else:
			return false
	
	if selection_state == SelectionState.OBJECTS:
		if object is Anthropoid:
			return true
	elif selection_state == SelectionState.VOXELS:
		var pos := object as Vector3i
		
		if pos != null:
			return voxel_tool.get_voxel(pos) in [1]
	
	return false


func select_object(object: Node) -> void:
	selection.append(object)
	
	var marker := _marker_scene.instantiate()
	var pin := PinJoint3D.new()
	
	pin['nodes/node_a'] = object.get_path()
	pin['nodes/node_b'] = marker.get_path()
	
	marker.add_child(pin)
	object.add_child(marker)
	
	marker.transform.origin = Vector3(0, 1, 0)
	
	_object_markers.append(marker)
	
	print("Selected object")
	print(object)


func clear_selection() -> void:
	selection.clear()
	_object_markers.map(func(x: Node): x.queue_free())
	_object_markers.clear()


func get_camera() -> Camera3D:
	return get_viewport().get_camera_3d()
