class_name CharacterController3D
extends CharacterBody3D


@export var max_speed: float = 4
@export var jump_power: float = 5
@export var ground_acceleration: float = 50
@export var air_acceleration: float = 10
@export var ground_friction: float = 10
@export var air_friction: float = 0
@export var gravity: Vector3 = Vector3(0, -9.8, 0)
@export_node_path(VoxelTerrain) var terrain_path: NodePath

var wish_vector := Vector3():
	get:
		return wish_vector
	set(value):
		wish_vector = value

# Jump with buffered input
var _jump_buffer_frames := 0
var _ground_frames := 0


func _physics_process(delta: float) -> void:
	velocity += gravity * delta
	_update_movement(delta)
	
	move_and_slide()
	
	# Fix a weird bug where the velocity while moving on the ground
	# incorporates a gravity component?
	# I think this is an engine issue, and I don't feel like reprogramming the
	# move_and_slide function
	if is_on_floor():
		# Jump immediately if buffered
		if _jump_buffer_frames > 1:
			velocity -= velocity.project(gravity.normalized())
			
			_ground_frames += 1
		else:
			jump()
	else:
		_ground_frames = 0
	
	_jump_buffer_frames += 1


func jump() -> void:
	if is_on_floor():
		velocity += up_direction * jump_power
		_ground_frames = 0


func _update_movement(delta: float) -> void:
	# Remove vertical component and normalize wish vector
	var h_plane := Plane(up_direction)
	var wish_dir := h_plane.project(wish_vector).normalized()
	
	var acceleration := air_acceleration
	var friction := air_friction
	
	# Only apply ground friction after the first frame of landing
	if is_on_floor() and _ground_frames > 0:
		acceleration = ground_acceleration
		friction = ground_friction
	
	acceleration *= delta
	friction *= delta
	
	# Get horizontal speeds before and after wish is applied
	var prev_speed := h_plane.project(velocity).length()
	var new_speed: float
	
	velocity += wish_dir * acceleration
	new_speed = h_plane.project(velocity).length()
	
	# Separate vertical and horizontal components of velocity
	var v := velocity.project(up_direction)
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
