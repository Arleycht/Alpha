class_name DigTask
extends Resource


const AI_TASK := true
const STAND_ADJACENT := true

var world: World
var priority: int = 0
var assigned_units := []

var _progress := 0.0
var _target: Vector3i


func _init(w: World, task_priority: int, target: Vector3i):
	super()
	
	world = w
	priority = task_priority
	_target = target


func is_unit_assignable(_unit: Unit) -> bool:
	return assigned_units.size() < 1


func is_done() -> bool:
	return _progress >= 1 or world.get_voxel(_target) == "core:air"


func get_goal() -> Vector3i:
	return _target


func is_at_task(unit: Unit) -> bool:
	var diff := (unit.position - Vector3(_target) - Vector3(0.5, 0.5, 0.5)).abs()
	var distance: float = max(diff.x, diff.y, diff.z)
	return distance <= 1.5 and distance > 0.9


func work(unit: Unit):
	if is_done():
		return
	
	if is_at_task(unit):
		_progress += unit.get_physics_process_delta_time()
		
		if is_done():
			world.set_voxel(_target, "core:air")
