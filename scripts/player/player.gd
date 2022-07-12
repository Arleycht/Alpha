class_name Player
extends Control

signal selection_changed
signal world_changed

var world: World
var daemon: Daemon

var current_tool: Variant
var selection: Array[Node] = []

var _object_markers: Array
var _marker_scene := preload("res://scenes/marker.tscn")


func _ready() -> void:
	daemon = Daemon.new()
	daemon.init(world)
	daemon.name = "PlayerDaemon"
	add_child(daemon)
	
	for button in _get_mode_buttons():
		button.pressed.connect(_on_button_pressed.bind(button))


func _input(event: InputEvent) -> void:
	if world == null:
		return
	
	if event.is_action_pressed("primary"):
		if current_tool != null and current_tool.use(self):
			get_viewport().set_input_as_handled()
		else:
			if not Input.is_action_pressed("control"):
				selection.clear()
			
			var r := Util.physics_cast(get_camera())
			
			if r != null:
				if r.collider is Anthropoid:
					selection.append(r.collider)
					_mark(r.collider)
				else:
					var anthropoid := daemon.spawn_anthropoid()
					anthropoid.global_transform.origin = r.position
				
				get_viewport().set_input_as_handled()
	elif event.is_action_released("secondary"):
		var v_result := Util.voxel_cast(get_camera(), world)
		
		if v_result != null:
			var pos := v_result.position + Vector3i(0, 1, 0)
			
			for c in selection:
				if c is Anthropoid:
					c.move_to(pos)
			
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("space"):
		get_tree().paused = not get_tree().paused
		get_viewport().set_input_as_handled()


func clear_selection() -> void:
	selection.clear()
	_object_markers.map(func(x: Node): x.queue_free())
	_object_markers.clear()
	selection_changed.emit()


func get_camera() -> Camera3D:
	return $"Camera3D"


func get_camera_position() -> Vector3:
	return $"Camera3D".global_transform.position as Vector3


func _mark(character: Character) -> void:
	var marker := _marker_scene.instantiate()
	
	character.add_child(marker)
	
	_object_markers.append(marker)


func _get_mode_buttons() -> Array:
	return get_tree().get_nodes_in_group("mode_buttons")


func _on_button_pressed(button: Button) -> void:
	var tool: Variant
	var selected := false
	
	match str(button.name).to_lower():
		"dig":
			tool = DigTool.new()
		"build":
			tool = null
	
	if tool != null and current_tool != tool:
		selected = true
	
	for b in _get_mode_buttons():
		b.button_pressed = false
	
	button.button_pressed = selected
