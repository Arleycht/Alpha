class_name CharacterController3D
extends CharacterBody3D


signal jumped
signal landed

@export var max_speed := 3.0
@export var jump_height := 1.0
@export var ground_acceleration := 50.0
@export var air_acceleration := 20.0
@export var ground_friction := 0.2
@export var air_friction := 0.1
@export var gravity_strength := 9.8
@export var gravity_direction: Vector3 = Vector3.DOWN
@export_node_path(VoxelTerrain) var terrain_path: NodePath

var wish_vector := Vector3()
var navigator: Navigator

var _ground_frames := 0
var _jumping := false
var _jump_buffered := false

var _terrain: VoxelTerrain
var _voxel_tool: VoxelTool


func _ready() -> void:
	_terrain = get_node(terrain_path) as VoxelTerrain
	_voxel_tool = _terrain.get_voxel_tool() as VoxelTool
	navigator = Navigator.new(self, _voxel_tool)


func _physics_process(delta: float) -> void:
	wish_vector = Vector3()
	navigator.update()
	
	velocity += gravity_direction * gravity_strength * delta
	_update_movement(delta)
	move_and_slide()
	
	if is_on_floor():
		if _ground_frames == 0:
			emit_signal("landed")
		
		_jumping = false
		
		# Skip ground frame for friction calculation if the jump is buffered
		if _jump_buffered:
			jump()
		else:
			velocity -= velocity.project(gravity_direction)
			_ground_frames += 1
	else:
		_ground_frames = 0


func get_aabb() -> AABB:
	var aabb := AABB()
	
	for c in find_children("", "CollisionShape3D", true):
		if c is CollisionShape3D:
			aabb = aabb.merge(c.shape.get_debug_mesh().get_aabb())
	
	return aabb


func move_to(to: Vector3) -> void:
	navigator.move_to(position, to)


func jump() -> bool:
	if is_on_floor() and not _jumping:
		velocity += -gravity_direction * sqrt(2 * gravity_strength * jump_height)
		velocity += -gravity_direction * gravity_strength * get_physics_process_delta_time()
		_jumping = true
		_jump_buffered = false
		emit_signal("jumped")
		return true
	elif not _jump_buffered:
		_jump_buffered = true
		return true
	return false


func is_jumping() -> bool:
	return _jumping or _jump_buffered


func _update_movement(delta: float) -> void:
	var h_plane := Plane(up_direction)
	
	# Remove vertical component and transform wish vector
	wish_vector.y = 0
	var wish_dir := (transform.basis * wish_vector).normalized()
	var wish_strength := clamp(wish_vector.length(), 0, 1) as float
	
	var acceleration := air_acceleration
	var friction := air_friction
	
	# Only apply ground friction after the first frame of landing
	# Allows for a form of bunny hopping
	if _ground_frames > 0:
		acceleration = ground_acceleration
		friction = ground_friction
	
	acceleration *= delta
	
	# Get horizontal speeds before and after wish is applied
	var prev_speed := h_plane.project(velocity).length()
	var new_speed: float
	
	velocity += wish_dir * wish_strength * acceleration
	new_speed = h_plane.project(velocity).length()
	
	# Separate vertical and horizontal components of velocity
	var v := velocity.project(up_direction)
	var h := (velocity - v).normalized()
	
	# Reduce friction while wish is active so max speed is achieved
	# mostly accurately
#	friction *= 1 - wish_strength
	
	# Preserve externally added velocities and limit additional wish
	# velocity to horizontal component
	# Also apply friction when above the max speed to gradually bring it
	# back to max speed
	if new_speed > max_speed:
		new_speed = max(prev_speed * (1 - friction), max_speed)
		friction = 0
	
	velocity = v + h * new_speed * (1 - friction)
