class_name Player
extends Node3D


signal world_changed

var world: World:
	set(value):
		world = value
		world_changed.emit(value)
var daemon: Daemon


func _ready() -> void:
	if world == null:
		await world_changed
	
	daemon = Daemon.new()
	daemon.init(world)
	daemon.name = "PlayerDaemon"
	add_child(daemon)
