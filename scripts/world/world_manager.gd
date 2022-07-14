extends Node


signal world_loaded

var world: World
var loader: WorldLoader

var _environment_scene = preload("res://scenes/default_environment.tscn")
## Some kind of change resulted in preloading the player not working
## Possibly the same bug as described in one of:
## https://github.com/godotengine/godot/issues/61043
## https://github.com/godotengine/godot/issues/58551 (most likely)
## If so, then another utility singleton to contain World/WorldLoader may
## resolve this issue until it is fixed
var _player_scene = load("res://scenes/player.tscn")


func _ready() -> void:
	call_deferred("load_world")
	
	get_tree().auto_accept_quit = false


func _notification(what: int):
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			print("Exiting")
			get_tree().quit()


func load_world() -> void:
	loader = WorldLoader.new()
	loader.load_definitions()
	
	world = World.new()
	world.loader = loader
	world.name = "World"
	world.add_child(_environment_scene.instantiate())
	
	get_tree().get_root().get_child(-1).queue_free()
	get_tree().get_root().add_child(world)
	get_tree().current_scene = world
	
	world_loaded.emit(world)
	
	var p := spawn_player()
	p.set_camera_position(Vector3(2.5, 1, 1) * Constants.BLOCK_SIZE)


func spawn_player() -> Player:
	var player: Player = _player_scene.instantiate()
	player.world = world
	world.add_child(player)
	return player
