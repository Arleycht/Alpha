class_name Player
extends Node3D


signal terrain_loaded

@export_node_path(VoxelTerrain) var terrain_path: NodePath

var terrain: VoxelTerrain
var voxel_tool: VoxelTool


func _ready() -> void:
	terrain = get_node(terrain_path) as VoxelTerrain
	
	if terrain != null:
		voxel_tool = terrain.get_voxel_tool()
		
		emit_signal("terrain_loaded", terrain, voxel_tool)
	else:
		printerr("Failed to load terrain")
