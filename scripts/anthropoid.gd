class_name Anthropoid
extends CharacterBody3D

var box_mover := VoxelBoxMover.new()
var aabb := AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))
var terrain := $"/root/Node3D/VoxelTerrain" as VoxelTerrain


func _ready() -> void:
	print(terrain)


func _physics_process(delta: float) -> void:
	pass
