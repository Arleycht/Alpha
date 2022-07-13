class_name Daemon
extends Node


var world: World

var _units = []
var _task_queue = []


func _physics_process(delta: float) -> void:
	for task in _task_queue:
		if is_task(task):
			if task.is_done():
				task.queue_free()
			else:
				task.update_task(self, delta)


func add_task(task: Variant) -> bool:
	if not is_task(task):
		return false
	
	_task_queue.append(task)
	_task_queue.sort_custom(func(a, b):
		return a.priority > b.priority
	)
	
	return true


func spawn_unit() -> Unit:
	var a: Unit = load("res://scenes/unit.tscn").instantiate()
	a.daemon = self
	a.died.connect(_on_unit_died)
	
	world.add_child(a)
	_units.append(a)
	
	return a


func _on_unit_died(unit: Unit) -> void:
	_units.filter(func(x): return is_instance_valid(x))
	
	print("%s has died" % unit.get_full_name())


static func is_task(task: Variant) -> bool:
	if 'AI_TASK' in task and task.has_method("work"):
		return true
	
	return false
