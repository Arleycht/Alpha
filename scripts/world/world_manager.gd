extends Node


signal world_loaded

var world: World

var _environment_scene = preload("res://scenes/default_environment.tscn")
var _player_scene = preload("res://scenes/player.tscn")


func _ready() -> void:
	call_deferred("load_world")


func load_world() -> void:
	world = World.new()
	world.name = "World"
	world.add_child(_environment_scene.instantiate())
	
	get_tree().get_root().get_child(-1).queue_free()
	get_tree().get_root().add_child(world)
	get_tree().current_scene = world
	
	world_loaded.emit(world)
	
	spawn_player()


func spawn_player() -> Player:
	var player: Player = _player_scene.instantiate()
	player.world = world
	world.add_child(player)
	return player
