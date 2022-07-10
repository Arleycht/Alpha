class_name Anthropoid
extends Character


signal died

@export var first_name: String = "Anthropoid"
@export var nickname: String = ""
@export var last_name: String = "Alpha"

var daemon: Daemon
var navigator := Navigator.new()


func _physics_process(delta: float) -> void:
	if daemon == null:
		return
	
	if daemon.world.is_out_of_bounds(position):
		died.emit(self)
		queue_free.call_deferred()
	
	# Perform AI processes
	wish_vector = Vector3()
	navigator.update()
	
	super._physics_process(delta)


func init(d: Daemon) -> void:
	daemon = d
	navigator.world = daemon.world
	navigator.character = self


func move_to(to: Vector3) -> void:
	navigator.move_to(position, to)


func get_full_name() -> String:
	if nickname == null or nickname.length() <= 0:
		return "%s %s" % [first_name, last_name]
	
	return "%s \"%s\" %s" % [first_name, nickname, last_name]
