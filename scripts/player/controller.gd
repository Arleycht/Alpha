extends Control


signal selection_changed

enum ControlMode {
	SELECT,
	DIG,
	BUILD,
}

enum SelectionMode {
	POSITIONS,
	OBJECTS,
	CHARACTERS,
}

const TIME_SCALE_MAX := 3

var player: Player

var control_mode := ControlMode.SELECT
var selection_mode := SelectionMode.POSITIONS
var selection: Array

var time_scale := 1

var _object_markers: Array
var _marker_scene := preload("res://scenes/marker.tscn")


func _ready() -> void:
	if get_parent() is Player:
		player = get_parent()
	else:
		printerr("HUD is not parented to a player")
	
	for button in _get_mode_buttons():
		button.pressed.connect(_on_button_pressed.bind(button))
	
	selection_changed.connect(_on_selection_changed)


func _input(event: InputEvent) -> void:
	if player.world == null:
		return
	
	if event.is_action_pressed("primary"):
		if Input.is_action_pressed("control"):
			var p_result := Util.physics_cast(get_camera())
			var a := player.daemon.spawn_anthropoid()
			
			a.position = p_result.position + Vector3(0, 0.5, 0)
			
			get_viewport().set_input_as_handled()
		else:
			select()
	elif event.is_action_released("secondary"):
		if selection_mode == SelectionMode.CHARACTERS:
			var v_result := Util.voxel_cast(get_camera(), player.world)
			
			if v_result != null:
				var pos := v_result.position + Vector3i(0, 1, 0)
				
				for c in selection:
					if c is Character:
						c.move_to(pos)
				
				get_viewport().set_input_as_handled()
	elif event.is_action_pressed("space"):
		get_tree().paused = not get_tree().paused
		get_viewport().set_input_as_handled()


func is_selectable(object) -> bool:
	if selection.is_empty():
		if object is Vector3i:
			selection_mode = SelectionMode.POSITIONS
		elif object is Character:
			selection_mode = SelectionMode.CHARACTERS
		else:
			return false
	
	if selection_mode == SelectionMode.CHARACTERS:
		if object is Character and object.is_physics_processing():
			return true
	elif selection_mode == SelectionMode.POSITIONS:
		if object is Vector3i:
			return player.world.get_voxel(object) in [1]
	
	return false


func select() -> bool:
	var new_selection
	
	var p_result := Util.physics_cast(get_camera())
	if p_result != null and is_selectable(p_result.collider):
		new_selection = p_result.collider
	else:
		var v_result := Util.voxel_cast(get_camera(), player.world)
		if v_result != null and is_selectable(v_result.position):
			new_selection = v_result.position
	
	if new_selection != null:
		if not Input.is_action_pressed("shift"):
			clear_selection()
		
		if not new_selection in selection:
			selection.append(new_selection)
			
			if new_selection is Character:
				_mark(new_selection)
		
		selection_changed.emit()
		get_viewport().set_input_as_handled()
		return true
	else:
		clear_selection()
	
	return false


func clear_selection() -> void:
	selection.clear()
	_object_markers.map(func(x: Node): x.queue_free())
	_object_markers.clear()
	selection_changed.emit()


func get_camera() -> Camera3D:
	return get_viewport().get_camera_3d()


func _mark(character: Character) -> void:
	var marker := _marker_scene.instantiate()
	
	character.add_child(marker)
	marker.transform.origin = Vector3(0, 1, 0)
	
	_object_markers.append(marker)


func _get_mode_buttons() -> Array:
	return get_tree().get_nodes_in_group("mode_buttons")


func _on_selection_changed() -> void:
	print("Selection changed")
	
	match control_mode:
		ControlMode.DIG:
			# Schedule dig tasks in daemon
			if selection_mode != SelectionMode.POSITIONS:
				return
			
			if selection.size() >= 2:
				var aabb := Util.get_aabb(selection[0], selection[1])
				player.world.tool.do_box(aabb.position, aabb.end)
				
				print("Dig")
		ControlMode.BUILD:
			# Schedule build tasks in daemon
			pass


func _on_button_pressed(button: Button) -> void:
	var selected_mode := ControlMode.SELECT
	var selected := false
	
	match str(button.name).to_lower():
		"dig":
			selected_mode = ControlMode.DIG
		"build":
			selected_mode = ControlMode.BUILD
	
	if control_mode == selected_mode:
		control_mode = ControlMode.SELECT
	else:
		control_mode = selected_mode
		selected = true
	
	for b in _get_mode_buttons():
		b.button_pressed = false
	
	if selected:
		button.button_pressed = true
