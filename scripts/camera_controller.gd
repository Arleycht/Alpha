class_name CameraController
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
var _target_y := int(position.y)


func _process(_delta: float) -> void:
	var wish_dir := Vector3()
	var camera_basis := get_camera().global_transform.basis
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
	position += wish_vector.normalized() * camera_speed * delta
	position.y = lerp(position.y, _target_y, 0.5)


func _input(event: InputEvent) -> void:
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
	
	if event is InputEventMouseMotion and _mouse_looking:
		camera_angles.x -= event.relative.y * camera_sensitivity.y * 1e-2
		camera_angles.y -= event.relative.x * camera_sensitivity.x * 1e-2
		get_viewport().set_input_as_handled()


func get_camera() -> Camera3D:
	return $SpringArm3D/Camera3D as Camera3D


func _update_camera() -> void:
	var camera := get_camera()
	
	# Rotate and constrain pitch
	
	camera_angles.x = clamp(camera_angles.x, CAMERA_PITCH_MIN, CAMERA_PITCH_MAX)
	camera_angles.y = wrapf(camera_angles.y, 0, TAU)
	
	# Control camera distance
	
	camera_distance = clamp(camera_distance,
			camera_distance_min, camera_distance_max)
	$SpringArm3D.transform.basis = Basis.from_euler(camera_angles)
	$SpringArm3D.spring_length = camera_distance
