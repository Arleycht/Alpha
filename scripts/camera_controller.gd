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

var wish_vector: Vector3
var camera_angles: Vector3
var target_y: int

var _mouse_look_position: Vector2
var _mouse_looking := false
var _mouse_locked_position: Vector2


func _ready() -> void:
	camera_angles = global_transform.basis.get_euler()
	target_y = int(global_transform.origin.y)


func _process(_delta: float) -> void:
	var wish_dir := Vector3()
	var h_plane := Plane(Vector3.UP)
	
	wish_dir.x = Input.get_action_strength("move_right") \
			- Input.get_action_strength("move_left")
	wish_dir.z = Input.get_action_strength("move_down") \
			- Input.get_action_strength("move_up")
	
	wish_vector = Vector3()
	wish_vector += h_plane.project(global_transform.basis.x).normalized() * wish_dir.x
	wish_vector += h_plane.project(global_transform.basis.z).normalized() * wish_dir.z
	
	_update_camera()


func _physics_process(delta: float) -> void:
	get_parent().position += wish_vector.normalized() * camera_speed * delta
	get_parent().position.y = lerp(get_parent().position.y, target_y, 0.5)


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
			target_y += 1
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("scroll_down"):
			target_y -= 1
			get_viewport().set_input_as_handled()
	
	if event is InputEventMouseButton:
		if event.is_action_pressed("secondary"):
			_mouse_look_position = event.position
		elif event.is_action_released("secondary"):
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
			if _mouse_looking:
				Input.warp_mouse(_mouse_look_position)
				get_viewport().set_input_as_handled()
			
			_mouse_looking = false
	
	if event is InputEventMouseMotion and Input.is_action_pressed("secondary"):
		if _mouse_looking:
			camera_angles.x -= event.relative.y * camera_sensitivity.y * 1e-2
			camera_angles.y -= event.relative.x * camera_sensitivity.x * 1e-2
			get_viewport().set_input_as_handled()
		else:
			var diff := (event.position - _mouse_look_position) as Vector2
			
			if diff.length_squared() > 25:
				camera_angles.x -= diff.y * camera_sensitivity.y * 1e-2
				camera_angles.y -= diff.x * camera_sensitivity.x * 1e-2
				
				_mouse_looking = true
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				get_viewport().set_input_as_handled()


func _update_camera() -> void:
	camera_angles.x = clamp(camera_angles.x, CAMERA_PITCH_MIN, CAMERA_PITCH_MAX)
	camera_angles.y = wrapf(camera_angles.y, 0, TAU)
	global_transform.basis = Basis.from_euler(camera_angles)
