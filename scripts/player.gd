class_name Player
extends Node3D


var world: World


@warning_ignore(shadowed_variable)
func set_world(world: World):
	self.world = world
