class_name BuildTask
extends Resource


const AI_TASK := true
const STAND_ADJACENT := true

var world: World
var priority: int = 0
var assigned_units := []

var _progress := 0.0
var _target: Vector3i
var _voxel_name: String


func _init(w: World, task_priority: int, target: Vector3i, voxel_name: String):
	super()
	
	world = w
	priority = task_priority
	_target = target
	_voxel_name = voxel_name


func is_unit_assignable(_unit: Unit) -> bool:
	return assigned_units.size() < 1


func is_done() -> bool:
	return _progress >= 1 or world.get_voxel(_target) == _voxel_name


func get_goal() -> Vector3i:
	return _target


func is_at_task(unit: Unit) -> bool:
	var diff := (unit.position - Vector3(_target) - Vector3(0.5, 0.5, 0.5)).abs()
	var distance: float = max(diff.x, diff.y, diff.z)
	print(distance)
	return distance <= 1.5 and distance > 0.9


func work(unit: Unit):
	if is_done():
		return
	
	if world.is_collidable(unit.position):
		return
	
	if is_at_task(unit):
		if not unit.world.is_obstructed(_target):
			_progress += unit.get_physics_process_delta_time()
			
			if is_done():
				world.set_voxel(_target, _voxel_name)
		else:
			print("Obstructed!")
			
			for u in assigned_units.duplicate():
				u.assigned_tasks.erase(self)
				assigned_units.erase(u)
