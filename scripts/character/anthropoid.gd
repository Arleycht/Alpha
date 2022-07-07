class_name Anthropoid
extends Character


@export var first_name: String = "Era"
@export var nickname: String = ""
@export var last_name: String = "Alpha"

@export_node_path(Daemon) var daemon_node: NodePath

var _daemon: Daemon


func _physics_process(delta: float) -> void:
	if _daemon == null:
		_daemon = get_node_or_null(daemon_node)
	else:
		# Perform AI processes
		pass
	
	super._physics_process(delta)


func get_full_name() -> String:
	if nickname == null or nickname.length() <= 0:
		return "%s %s" % [first_name, last_name]
	
	return "%s \"%s\" %s" % [first_name, nickname, last_name]
