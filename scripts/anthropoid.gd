class_name Anthropoid
extends CharacterController3D


var _box_mover := VoxelBoxMover.new()
var _aabb := AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))
var _terrain: VoxelTerrain


func _ready() -> void:
	_terrain = get_node(terrain_path) as VoxelTerrain
