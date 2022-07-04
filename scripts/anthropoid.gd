class_name Anthropoid
extends CharacterController3D


@export var first_name: String = "Era"
@export var nickname: String = ""
@export var last_name: String = "Alpha"


func get_full_name() -> String:
	if nickname == null or nickname.length() <= 0:
		return "%s %s" % [first_name, last_name]
	
	return "%s \"%s\" %s" % [first_name, nickname, last_name]
