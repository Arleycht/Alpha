class_name Daemon
extends Node


var world: World

var _anthropoids = []
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
	
	print("eeeeeeeeee")
	for t in _task_queue:
		print(t.priority)
	
	return true


func spawn_anthropoid() -> Anthropoid:
	var a: Anthropoid = load("res://scenes/anthropoid.tscn").instantiate()
	a.daemon = self
	a.died.connect(_on_anthropoid_died)
	
	world.add_child(a)
	_anthropoids.append(a)
	
	return a


func _on_anthropoid_died(anthropoid: Anthropoid) -> void:
	_anthropoids.filter(func(x): return is_instance_valid(x))
	
	print("%s has died" % anthropoid.get_full_name())


static func is_task(task: Variant) -> bool:
	if 'AI_TASK' in task and task.has_method("work"):
		return true
	
	return false
