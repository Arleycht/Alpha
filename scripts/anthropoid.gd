class_name Anthropoid
extends CharacterController3D


@export var anthropoid_name: String


var _box_mover := VoxelBoxMover.new()
var _aabb := AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))
var _terrain: VoxelTerrain


func _ready() -> void:
	_terrain = get_node(terrain_path) as VoxelTerrain


func _physics_process(delta: float) -> void:
	var motion := velocity * delta
	motion = _box_mover.get_motion(transform.origin, motion, _aabb, _terrain)

	global_translate(motion)

	velocity = motion / delta
