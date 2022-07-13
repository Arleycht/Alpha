class_name Player
extends Control

signal selection_changed
signal tool_changed
signal world_changed

var world: World
var daemon: Daemon

var current_tool: Variant
var selection: Array[Node] = []

var _object_markers: Array
var _marker_scene := preload("res://scenes/marker.tscn")


func _ready() -> void:
	daemon = Daemon.new()
	daemon.world = world
	daemon.name = "PlayerDaemon"
	add_child(daemon)
	
	for button in _get_mode_buttons():
		button.pressed.connect(_on_button_pressed.bind(button))
	
	tool_changed.connect(_update_buttons)


func _input(event: InputEvent) -> void:
	# Escape button interactions
	
	if event.is_action_pressed("escape"):
		if current_tool != null:
			clear_tool()
		else:
			print("TODO: Pause menu")
	
	if world == null:
		return
	
	# Blacklist all mouse player world interactions when in HUD
	if 'position' in event:
		for control in get_node("HUD").get_children():
			var rect := Rect2(control.position, control.size)
			if rect.has_point(event.position):
				return
	
	if current_tool != null:
		var success := false
		
		if current_tool.use(self, event):
			success = true
		
		if success:
			get_viewport().set_input_as_handled()
			return
	
	if event.is_action_pressed("primary"):
		if not Input.is_action_pressed("control"):
			selection.clear()
		
		var r := Util.physics_cast_from_screen(get_camera())
		
		if r.collider != null:
			if r.collider is Anthropoid:
				selection.append(r.collider)
				_mark(r.collider)
				get_viewport().set_input_as_handled()
			elif Input.is_action_pressed("control"):
				var anthropoid := daemon.spawn_anthropoid()
				anthropoid.global_transform.origin = r.position
				get_viewport().set_input_as_handled()
	elif event.is_action_released("secondary"):
		var result := Util.voxel_cast_from_screen(world, get_camera())
		var pos: Vector3i = result['position']
		var voxel_name := world.get_voxel(pos)
		
		if voxel_name != "core:air":
			pos += Vector3i(0, 1, 0)
			
			for c in selection:
				if c is Anthropoid:
					c.move_to(pos)
			
			get_viewport().set_input_as_handled()


func is_tool(tool: Variant) -> bool:
	if tool != null and 'INTERACTION_TOOL' in tool:
		return true
	
	return false


func clear_tool() -> void:
	current_tool = null
	tool_changed.emit()


func clear_selection() -> void:
	selection.clear()
	_object_markers.map(func(x: Node): x.queue_free())
	_object_markers.clear()
	selection_changed.emit()


func get_camera() -> Camera3D:
	return $"Camera3D"


func get_camera_position() -> Vector3:
	return $"Camera3D".global_transform.origin as Vector3


func _mark(character: Character) -> void:
	var marker := _marker_scene.instantiate()
	character.add_child(marker)
	_object_markers.append(marker)


func _get_mode_buttons() -> Array:
	return get_tree().get_nodes_in_group("mode_buttons")


func _try_get_tool(button: Button) -> Variant:
	for child in button.get_children():
		if is_tool(child):
			return child
	
	return null


func _update_buttons():
	for button in _get_mode_buttons():
		if button is BaseButton:
			if current_tool in button.get_children():
				button.button_pressed = true
			else:
				button.button_pressed = false


func _on_button_pressed(button: Button) -> void:
	var tool: Variant = _try_get_tool(button)
	
	if tool != null:
		if tool == current_tool:
			current_tool = null
		else:
			current_tool = tool
		
		tool_changed.emit(tool)
