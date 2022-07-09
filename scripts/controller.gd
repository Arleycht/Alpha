extends Control


enum ControlMode {
	SELECT,
	DIG,
	BUILD,
}

enum SelectionMode {
	VOXELS,
	OBJECTS,
	CHARACTERS,
}

const TIME_SCALE_MAX := 3

var player: Player

var control_mode := ControlMode.SELECT
var selection_mode := SelectionMode.VOXELS
var selection: Array

var time_scale := 1

var _object_markers: Array
var _marker_scene := preload("res://scenes/marker.tscn")


func _ready() -> void:
	if get_parent() is Player:
		player = get_parent()
	else:
		printerr("HUD is not parented to a player")
	
	for button in get_tree().get_nodes_in_group("command_buttons"):
		if button is Button:
			(button as Button).pressed.connect(_on_button_pressed)


func _input(event: InputEvent) -> void:
	if player.world == null:
		return
	
	if event.is_action_pressed("primary"):
		if control_mode == ControlMode.SELECT:
			select()
	elif event.is_action_released("secondary"):
		if selection_mode == SelectionMode.CHARACTERS:
			var v_result := voxel_cast()
			
			if v_result != null:
				var pos := v_result.position + Vector3i(0, 1, 0)
				
				for c in selection:
					if c is Character:
						c.move_to(pos)
				
				get_viewport().set_input_as_handled()
	
	if event.is_action_pressed("space"):
		get_tree().paused = not get_tree().paused
		get_viewport().set_input_as_handled()


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
	return Common.voxel_cast(player.world, origin, direction * max_distance)


func is_selectable(object) -> bool:
	if selection.is_empty():
		if object is Vector3i:
			selection_mode = SelectionMode.VOXELS
		elif object is Character:
			selection_mode = SelectionMode.CHARACTERS
		else:
			return false
	
	if selection_mode == SelectionMode.CHARACTERS:
		if object is Character and object.is_physics_processing():
			return true
	elif selection_mode == SelectionMode.VOXELS:
		if object is Vector3i:
			return player.world.get_voxel(object) in [1]
	
	return false


func select() -> bool:
	var selected
	
	var p_result := physics_cast()
	if p_result != null and is_selectable(p_result.collider):
		selected = p_result.collider
	else:
		var v_result := voxel_cast()
		if v_result != null and is_selectable(v_result.position):
			selected = v_result.position
	
	if selected != null:
		if not Input.is_action_pressed("shift"):
			clear_selection()
		
		if not selected in selection:
			selection.append(selected)
			
			if selected is Character:
				_mark(selected)
		
		get_viewport().set_input_as_handled()
		return true
	else:
		clear_selection()
	
	return false


func clear_selection() -> void:
	selection.clear()
	_object_markers.map(func(x: Node): x.queue_free())
	_object_markers.clear()


func get_camera() -> Camera3D:
	return get_viewport().get_camera_3d()


func _mark(character: Character) -> void:
	var marker := _marker_scene.instantiate()
	var pin := PinJoint3D.new()
	
	marker.add_child(pin)
	character.add_child(marker)
	
	pin['nodes/node_a'] = character.get_path()
	pin['nodes/node_b'] = marker.get_path()
	
	marker.transform.origin = Vector3(0, 1, 0)
	
	_object_markers.append(marker)


func _on_button_pressed() -> void:
	print("Button pressed")
