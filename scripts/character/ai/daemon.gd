class_name Daemon
extends Node


const COOLDOWN_TIME_MSEC := 3000

var world: World

var units := []
var task_queue := []
var cooldowns := {}


func _physics_process(delta: float) -> void:
	units = units.filter(func(x): return is_instance_valid(x))
	task_queue = task_queue.filter(func(x):
		return Daemon.is_task(x) and not x.is_done()
	)
	
	for k in cooldowns.keys():
		if Time.get_ticks_msec() - cooldowns[k] > COOLDOWN_TIME_MSEC:
			cooldowns.erase(k)
	
	for task in task_queue:
		for unit in task.assigned_units:
			if not task in unit.assigned_tasks:
				task.assigned_units.erase(unit)


## Adds a task to the task queue
func add_task(task: Variant) -> bool:
	if not is_task(task):
		return false
	
	task_queue.append(task)
	task_queue.sort_custom(func(a, b):
		return a.priority > b.priority
	)
	
	return true


func assign_task(unit: Unit, filter_fn: Callable = func(_x): return true) -> void:
	var tasks := task_queue.filter(filter_fn)
	
	# Sort by distance from unit.
	# TODO: Perform smarter task prioritization
	tasks.sort_custom(func(a, b):
		var d1 = (unit.position - Vector3(a.get_goal())).length()
		var d2 = (unit.position - Vector3(b.get_goal())).length()
		return d1 < d2
	)
	
	for task in tasks:
		if task in cooldowns:
			continue
		
		if task.is_unit_assignable(unit) and unit.is_task_assignable(task):
			unit.assigned_tasks.append(task)
			task.assigned_units.append(unit)
			return


func cooldown(task: Variant) -> void:
	cooldowns[task] = Time.get_ticks_msec()


func spawn_unit() -> Unit:
	var a: Unit = load("res://scenes/unit.tscn").instantiate()
	a.daemon = self
	a.world = world
	a.died.connect(_on_unit_died)
	
	world.add_child(a)
	units.append(a)
	
	return a


func _on_unit_died(unit: Unit) -> void:
	print("%s has died" % unit.get_full_name())
	units.erase(unit)


static func is_task(task: Variant) -> bool:
	if 'AI_TASK' in task and task.has_method("work"):
		return true
	
	return false
