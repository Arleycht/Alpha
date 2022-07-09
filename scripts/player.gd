class_name Player
extends Node3D


var world: World


func _process(_delta: float) -> void:
	if world == null:
		var p = get_parent()
		
		while p != null:
			if p is World:
				world = p
				break
			
			p = get_parent()
		
		return
