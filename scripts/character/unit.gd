class_name Unit
extends Character


signal died

@export var first_name: String = "Unit"
@export var nickname: String = ""
@export var last_name: String = "Alpha"

var daemon: Daemon
var world: World
var navigator := Navigator.new()

var assigned_tasks := []


func _ready() -> void:
	navigator.unit = self
	navigator.world = world


func _physics_process(delta: float) -> void:
	if not is_loaded():
		return
	
	if daemon.world.is_out_of_bounds(position):
		died.emit(self)
		queue_free.call_deferred()
	
	# Perform AI processes
	
	# Tasks
	
	if assigned_tasks.size() > 0:
		# Sort ascending order
		assigned_tasks.sort_custom(func(a, b): return a.priority < b.priority)
		
		var current_task = assigned_tasks[-1]
		
		if not current_task.is_at_task(self):
			print("Not at task!")
			
			# Task is unworkable, try to path to it
			if navigator.is_path_empty():
				if 'STAND_ADJACENT' in current_task:
					navigator.move_to_adjacent(position, current_task.get_goal())
				else:
					navigator.move_to(position, current_task.get_goal())
				
				if navigator.is_path_empty():
					print("Couldn't find path, putting task on cooldown!")
					
					# If the path is still empty, the task is not navigable
					# Put task on cooldown and unassign self
					current_task.assigned_units.erase(self)
					assigned_tasks.erase(current_task)
					daemon.cooldown(current_task)
				else:
					print("Found path to task")
		else:
			print("Working...")
			current_task.work(self)
		
		if current_task.is_done():
			assigned_tasks.pop_back()
	else:
		daemon.assign_task(self)
	
	# Pathfind to a goal
	
	wish_vector = Vector3()
	navigator.update()
	
	super._physics_process(delta)


func is_task_assignable(task: Variant) -> bool:
	return true


func move_to(to: Vector3) -> void:
	navigator.move_to(position, to)


func is_loaded() -> bool:
	return daemon != null and daemon.world != null


func get_full_name() -> String:
	if nickname == null or nickname.length() <= 0:
		return "%s %s" % [first_name, last_name]
	
	return "%s \"%s\" %s" % [first_name, nickname, last_name]
