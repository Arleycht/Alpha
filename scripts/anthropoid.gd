class_name Anthropoid
extends CharacterController3D


@export var first_name: String = "Era"
@export var nickname: String = ""
@export var last_name: String = "Alpha"

var _box_mover := VoxelBoxMover.new()
var _aabb := AABB(Vector3(-0.175, 0, -0.175), Vector3(0.175, 0.45, 0.175))

var _move_towards_goal := true


func _physics_process(delta: float) -> void:
	if _move_towards_goal:
		wish_vector = Vector3()
		
		if _pathfinder.is_ready():
			if not _pathfinder.is_path_empty():
				var goal = _pathfinder.get_current()
				var diff := goal - transform.origin
				
				var h := Plane(Vector3.UP).project(diff)
				
				var x = diff.length()
				wish_vector = h.normalized() * clampf(x, 0, 1)
				
				if diff.length() < 0.25:
					_pathfinder.increment_path()
				
				if is_on_wall() and goal.y >= transform.origin.y + jump_height:
					jump()
			else:
				_move_towards_goal = false
	
	super._physics_process(delta)
	
#	var motion: Vector3 = velocity * delta
#	motion = _box_mover.get_motion(transform.origin, motion, _aabb, terrain)
#	global_translate(motion)
#	velocity = motion / delta


func move_to(to: Vector3) -> void:
	_pathfinder.set_path(transform.origin + Vector3(0, 0.5, 0), to)
	_move_towards_goal = true
	
#	if not _pathfinder.is_path_empty():
#		var diff = _pathfinder.get_current() - transform.origin
#		if diff.length() < 0.5:
#			_pathfinder.increment_path()


func get_full_name() -> String:
	if nickname == null or nickname.length() <= 0:
		return "%s %s" % [first_name, last_name]
	
	return "%s \"%s\" %s" % [first_name, nickname, last_name]
