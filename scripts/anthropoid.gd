class_name Anthropoid
extends CharacterBody3D


@export_node_path(VoxelTerrain) var terrain_path: NodePath
var terrain: VoxelTerrain
var voxel_tool: VoxelTool

@export var first_name: String = "Era"
@export var nickname: String = ""
@export var last_name: String = "Alpha"

@export var movement_speed := 2.0
@export var jump_height := 1.0
@export var gravity := 9.8

var wish_vector: Vector3

var _box_mover := VoxelBoxMover.new()
var _aabb := AABB(Vector3(-0.175, 0, -0.175), Vector3(0.175, 0.45, 0.175))

var _pathfinder := PathfindingManager.new()
var _move_towards_goal := true


func _ready() -> void:
	terrain = get_node(terrain_path) as VoxelTerrain
	voxel_tool = terrain.get_voxel_tool()
	
	_pathfinder.voxel_tool = voxel_tool


func _physics_process(delta: float) -> void:
	if _move_towards_goal:
		wish_vector = Vector3()
		
		if not _pathfinder.is_path_empty():
			var goal = Common.to_real_coords(_pathfinder.get_current_path()[0]) - Vector3(0, 0.5, 0)
			var diff := goal - transform.origin
			
			var h := Plane(Vector3.UP).project(diff)
			var v := Vector3.UP * diff.y
			
			wish_vector = h.normalized() * movement_speed + v
			#transform.origin = goal
			
			if diff.length() < 0.1:
				_pathfinder.increment_path()
		else:
			_move_towards_goal = false
	
	if is_on_wall() and wish_vector.y > 0.5:
		if jump():
			# Ensure correct jump height at minimum by skipping one frame of
			# gravity
			velocity.y += gravity * delta
	
	velocity.x = wish_vector.x
	velocity.z = wish_vector.z
	velocity.y -= gravity * delta
	
	move_and_slide()
	
#	var motion: Vector3 = velocity * delta
#	motion = _box_mover.get_motion(transform.origin, motion, _aabb, terrain)
#	global_translate(motion)
#	velocity = motion / delta


func move_to(to: Vector3) -> void:
	_pathfinder.set_path(transform.origin + Vector3(0, 0.5, 0), to)
	_move_towards_goal = true
	
	if not _pathfinder.is_path_empty():
		print(_pathfinder._current_path)


func jump() -> bool:
	if is_on_floor():
		velocity.y += sqrt(2 * gravity)
		return true
	return false


func get_full_name() -> String:
	if nickname == null or nickname.length() <= 0:
		return "%s %s" % [first_name, last_name]
	
	return "%s \"%s\" %s" % [first_name, nickname, last_name]
