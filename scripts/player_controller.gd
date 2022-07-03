class_name PlayerController
extends Node3D


const CAMERA_PITCH_MIN: float = deg2rad(-89.9)
const CAMERA_PITCH_MAX: float = deg2rad(89.9)

@export var camera_speed: float = 12
@export var camera_fast_speed: float = 24
@export var camera_distance: float = 0
@export var camera_distance_min: float = 0
@export var camera_distance_max: float = 10
@export var camera_distance_increment: float = 1
@export var allow_camera_zoom: bool = true
@export var camera_sensitivity: Vector2 = Vector2(0.2, 0.2)
@export_node_path(VoxelTerrain) var terrain_path: NodePath

@export var camera_angles: Vector3
@export_node_path(Camera3D) var override_camera_path: NodePath

var wish_vector: Vector3

var _mouse_looking := false
var _mouse_locked_position: Vector2
var _target_y := int(transform.origin.y)

var _terrain: VoxelTerrain
var _voxel_tool: VoxelTool

var _selected_objects: Array
var _selection_markers: Array
var _selected_position: Vector3

var _marker_scene := preload("res://scenes/marker.tscn")


func _ready() -> void:
	_terrain = get_node(terrain_path) as VoxelTerrain
	_voxel_tool = _terrain.get_voxel_tool() as VoxelTool


func _process(_delta: float) -> void:
	var wish_dir := Vector3()
	var camera_basis := get_current_camera().global_transform.basis
	var h_plane := Plane(Vector3.UP)
	
	wish_dir.x = Input.get_action_strength("move_right") \
			- Input.get_action_strength("move_left")
	wish_dir.z = Input.get_action_strength("move_down") \
			- Input.get_action_strength("move_up")
	
	wish_vector = Vector3()
	wish_vector += h_plane.project(camera_basis.x).normalized() * wish_dir.x
	wish_vector += h_plane.project(camera_basis.z).normalized() * wish_dir.z
	
	_update_camera()


func _physics_process(delta: float) -> void:
	transform.origin += wish_vector.normalized() * camera_speed * delta
	
	transform.origin.y = lerp(transform.origin.y, _target_y, 0.5)


func _input(event: InputEvent) -> void:
	# TODO: Separate different types of input handlers into their own scripts
	
	if Input.is_action_pressed("control"):
		if event.is_action_pressed("scroll_up"):
			camera_distance -= camera_distance_increment
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("scroll_down"):
			camera_distance += camera_distance_increment
			get_viewport().set_input_as_handled()
	else:
		if event.is_action_pressed("scroll_up"):
			_target_y += 1
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("scroll_down"):
			_target_y -= 1
			get_viewport().set_input_as_handled()
	
	if event.is_action_pressed("primary"):
		var mouse_pos := get_viewport().get_mouse_position()
		var origin := get_current_camera().project_ray_origin(mouse_pos)
		var direction := get_current_camera().project_ray_normal(mouse_pos)
		var max_distance := ($"VoxelViewer" as VoxelViewer).view_distance * 1.5
		var params := PhysicsRayQueryParameters3D.new()
		params.from = origin
		params.to = origin + direction * 100
		
		var ray_result := get_world_3d().direct_space_state.intersect_ray(params)
		
		if not ray_result.is_empty() and is_selectable(ray_result["collider"]):
			if not Input.is_action_pressed("shift"):
				clear_selection()
			
			select(ray_result["collider"])
			
			get_viewport().set_input_as_handled()
			return
		
		var voxel_result := _voxel_tool.raycast(transform.origin, direction, max_distance)
		
		if voxel_result and voxel_result.distance <= max_distance:
			_selected_position = voxel_result.position
			
			for object in _selected_objects:
				if object is Anthropoid:
					object.move_to(_selected_position + Vector3(0, 1, 0))
			
			get_viewport().set_input_as_handled()
			return
		
		clear_selection()
	
	if event.is_action_pressed("secondary"):
		_mouse_locked_position = get_viewport().get_mouse_position()
		_mouse_looking = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_viewport().set_input_as_handled()
	elif event.is_action_released("secondary"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		Input.warp_mouse(_mouse_locked_position)
		_mouse_looking = false
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_looking:
		camera_angles.x -= event.relative.y * camera_sensitivity.y * 1e-2
		camera_angles.y -= event.relative.x * camera_sensitivity.x * 1e-2


func physics_cast(max_distance: float = 100.0) -> Dictionary:
	## Wrapper around PhysicsDirectSpaceState3D.intersect_ray
	var result := {}
	var mouse_pos := get_viewport().get_mouse_position()
	var origin := get_current_camera().project_ray_origin(mouse_pos)
	var direction := get_current_camera().project_ray_normal(mouse_pos)
	var params := PhysicsRayQueryParameters3D.new()
	params.from = origin
	params.to = origin + direction * max_distance
	return get_world_3d().direct_space_state.intersect_ray(params)


func voxel_cast(max_distance: float = 100.0) -> VoxelRaycastResult:
	var mouse_pos := get_viewport().get_mouse_position()
	var origin := get_current_camera().project_ray_origin(mouse_pos)
	var direction := get_current_camera().project_ray_normal(mouse_pos)
	return _voxel_tool.raycast(origin, direction, max_distance)


func is_selectable(object) -> bool:
	if object is Anthropoid:
		return true
	
	return false


func select(object: Node) -> void:
	if object is Node:
		_selected_objects.append(object)
		
		var marker := _marker_scene.instantiate()
		object.add_child(marker)
		marker.transform.origin = Vector3(0, 1, 0)
		_selection_markers.append(marker)
		
		print("Selected object")
		print(object)


func clear_selection() -> void:
	_selected_objects.clear()
	
	for marker in _selection_markers:
		marker.queue_free()
	
	_selection_markers.clear()


func get_current_camera() -> Camera3D:
	if get_node_or_null(override_camera_path) != null:
		return get_node(override_camera_path)
	
	return _get_internal_camera()


func _get_internal_camera() -> Camera3D:
	return $SpringArm3D/Camera3D as Camera3D


func _update_camera() -> void:
	var camera := get_current_camera()
	
	# Rotate and constrain pitch
	
	camera_angles.x = clamp(camera_angles.x, CAMERA_PITCH_MIN, CAMERA_PITCH_MAX)
	camera_angles.y = wrapf(camera_angles.y, 0, TAU)
	#camera.transform.basis = Basis(camera_angles)
	
	# Control camera distance
	
	camera_distance = clamp(camera_distance,
			camera_distance_min, camera_distance_max)
	$SpringArm3D.transform.basis = Basis.from_euler(camera_angles)
	$SpringArm3D.spring_length = camera_distance
