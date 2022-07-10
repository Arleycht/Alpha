class_name Daemon
extends Node3D


var world: World

var _anthropoids = []
var _task_queue = []


func init(w: World) -> void:
	world = w


func spawn_anthropoid() -> Anthropoid:
	var a: Anthropoid = load("res://scenes/anthropoid.tscn").instantiate()
	a.init(self)
	a.died.connect(_on_anthropoid_died)
	
	world.add_child(a)
	_anthropoids.append(a)
	
	return a


func add_task() -> void:
	printerr("Not implemented")
	return


func _on_anthropoid_died(anthropoid: Anthropoid) -> void:
	print("%s has died" % anthropoid.get_full_name())
	
	_anthropoids.erase(anthropoid)
