class_name PlayerController
extends CharacterBody3D


enum MovementType {
	DEFAULT,
	SOURCE,
}

const CAMERA_PITCH_MIN: float = deg2rad(-89.9)
const CAMERA_PITCH_MAX: float = deg2rad(89.9)

@export var movement_type = MovementType.DEFAULT
@export var max_speed: float = 10
@export var jump_power: float = 5
@export var ground_acceleration: float = 50
@export var air_acceleration: float = 20
@export var ground_friction: float = 10
@export var air_friction: float = 0
@export var gravity: Vector3 = Vector3(0, -9.8, 0)

@export var up_vector: Vector3 = Vector3(0, 1, 0)
@export var mouse_locked: bool = true
@export var movement_locked: bool = false

@export var camera_distance: float = 0
@export var camera_distance_min: float = 0
@export var camera_distance_max: float = 5
@export var camera_distance_increment: float = 1
@export var allow_camera_zoom: bool = true
@export var camera_sensitivity: Vector2 = Vector2(0.2, 0.2)

var _jumping := false
var _landing_frames := 0

var camera_angles: Vector3
var override_camera: Camera3D

@onready
var _spring_arm := $SpringArm3D as SpringArm3D


func _process(delta: float) -> void:
	# Escape
	
	if Input.is_action_just_pressed("escape"):
		mouse_locked = not mouse_locked
	
	_update_camera()
	_update_movement(delta)


func _physics_process(delta: float) -> void:
	var snap := -up_vector if not _jumping else Vector3()
	
	velocity += gravity * delta
	
	move_and_slide()
	
	# Fix a weird bug where the velocity while moving on the ground
	# incorporates a gravity component?
	# I think this is an engine issue, and I don't feel like reprogramming the
	# move_and_slide function
	if is_on_floor():
		velocity -= velocity.project(gravity.normalized())
		_jumping = false
		
		if Input.is_action_pressed("jump"):
			jump()
		else:
			_landing_frames += 1
	else:
		_landing_frames = 0


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_action_pressed("scroll_up"):
			camera_distance -= camera_distance_increment
#			get_tree().set_input_as_handled()
		elif event.is_action_pressed("scroll_down"):
			camera_distance += camera_distance_increment
#			get_tree().set_input_as_handled()
	
	if event is InputEventKey:
		if event.is_action_pressed("jump"):
			jump()
#			get_tree().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_locked:
		camera_angles.x -= event.relative.y * camera_sensitivity.y * 1e-2
		camera_angles.y -= event.relative.x * camera_sensitivity.x * 1e-2


func get_current_camera() -> Camera3D:
	if override_camera != null:
		return override_camera
	
	return _get_internal_camera()


func get_position() -> Vector3:
	return transform.origin


func jump() -> void:
	if is_on_floor() and not _jumping:
		velocity += up_vector * jump_power
		_jumping = true


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
	
	mesh_basis = mesh_basis.rotated(up_vector, camera_angles.y)
	
	$Mesh.transform.basis = mesh_basis


func _update_movement(delta: float) -> void:
	var wish_dir := Vector3()
	
	wish_dir.x = Input.get_action_strength("move_right") \
			- Input.get_action_strength("move_left")
	wish_dir.z = Input.get_action_strength("move_down") \
			- Input.get_action_strength("move_up")
	
	# Transform, remove vertical component, and normalize wish vector
	
	wish_dir = get_current_camera().global_transform.basis * wish_dir
	wish_dir = (wish_dir - wish_dir.project(up_vector)).normalized()
	
	var acceleration := air_acceleration
	var friction := air_friction
	
	if is_on_floor() and _landing_frames > 5:
		acceleration = ground_acceleration
		friction = ground_friction
	
	acceleration *= delta
	friction *= delta
	
	if movement_type == MovementType.SOURCE:
		var projected_speed := velocity.dot(wish_dir)
		
		if projected_speed + acceleration > max_speed:
			acceleration = max_speed - projected_speed
		
		velocity = velocity * (1 - friction) + wish_dir * acceleration
	else:
		# Get horizontal speeds before and after wish is applied
		var prev_speed := (velocity - velocity.project(up_vector)).length()
		var new_speed: float
		
		velocity += wish_dir * acceleration
		new_speed = (velocity - velocity.project(up_vector)).length()
		
		# Separate vertical and horizontal components of velocity
		var v := velocity.project(up_vector)
		var h := (velocity - v).normalized()
		
		# Preserve externally added velocities and limit additional wish
		# velocity to horizontal component
		# Also apply friction when above the max speed to gradually bring it
		# back to max speed
		if new_speed > max_speed:
			new_speed = max(prev_speed * (1 - friction), max_speed)
			friction = 0
		
		# Also ignore friction while wish is active so max speed is achieved
		# mostly accurately
		if wish_dir != Vector3():
			friction = 0
		
		velocity = v + h * new_speed * (1 - friction)
