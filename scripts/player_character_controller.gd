class_name PlayerCharacterController
extends CharacterController3D


const CAMERA_PITCH_MIN: float = deg2rad(-89.9)
const CAMERA_PITCH_MAX: float = deg2rad(89.9)

@export var mouse_locked: bool = true
@export var movement_locked: bool = false

@export var camera_distance: float = 0
@export var camera_distance_min: float = 0
@export var camera_distance_max: float = 5
@export var camera_distance_increment: float = 1
@export var allow_camera_zoom: bool = true
@export var camera_sensitivity: Vector2 = Vector2(0.1, 0.1)

var camera_angles: Vector3
var override_camera: Camera3D


func _process(_delta: float) -> void:
	# Hold jump
	if Input.is_action_pressed("jump"):
		jump()
	
	var wish_dir := Vector3()
	var camera_basis := get_current_camera().global_transform.basis
	var h_plane := Plane(up_direction)
	
	wish_dir.x = Input.get_action_strength("move_right") \
			- Input.get_action_strength("move_left")
	wish_dir.z = Input.get_action_strength("move_down") \
			- Input.get_action_strength("move_up")
	
	wish_vector = Vector3()
	wish_vector += h_plane.project(camera_basis.x).normalized() * wish_dir.x
	wish_vector += h_plane.project(camera_basis.z).normalized() * wish_dir.z
	
	_update_camera()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		mouse_locked = not mouse_locked
	
	if event.is_action_pressed("scroll_up"):
		camera_distance -= camera_distance_increment
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("scroll_down"):
		camera_distance += camera_distance_increment
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_locked:
		camera_angles.x -= event.relative.y * camera_sensitivity.y * 1e-2
		camera_angles.y -= event.relative.x * camera_sensitivity.x * 1e-2


func get_current_camera() -> Camera3D:
	if override_camera != null:
		return override_camera
	
	return _get_internal_camera()


func _get_internal_camera() -> Camera3D:
	return $SpringArm3D/Camera3D as Camera3D


func _update_camera() -> void:
	var camera := _get_internal_camera()
	
	if mouse_locked:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if override_camera != null:
		return
	
	if camera == null:
		return
	
	# Rotate and constrain pitch
	
	camera_angles.x = clamp(camera_angles.x, CAMERA_PITCH_MIN, CAMERA_PITCH_MAX)
	camera_angles.y = wrapf(camera_angles.y, 0, TAU)
	#camera.transform.basis = Basis(camera_angles)
	
	# Control camera distance
	
	camera_distance = clamp(camera_distance,
			camera_distance_min, camera_distance_max)
	$SpringArm3D.transform.basis = Basis.from_euler(camera_angles)
	$SpringArm3D.spring_length = camera_distance
	
	# Rotate character
	
	var mesh_basis := Basis()
	
	mesh_basis = mesh_basis.rotated(up_direction, camera_angles.y)
	
	$Mesh.transform.basis = mesh_basis
