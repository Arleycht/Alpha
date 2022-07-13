class_name DigTask
extends Resource


const AI_TASK := true

var priority: int = 0

var _positions := []


func _init(task_priority: int, voxels_to_dig: Array):
	super()
	
	priority = task_priority
	_positions = voxels_to_dig


func is_done() -> bool:
	return _positions.size() <= 0


func update_task(daemon: Daemon, delta: float) -> void:
	pass


func work(daemon: Daemon, unit: Unit) -> void:
	var i = randi_range(0, _positions.size() - 1)
	var pos = _positions.pop_at(i) as Vector3i
	daemon.world.set_voxel(pos, "core:air")
