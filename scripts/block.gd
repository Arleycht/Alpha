class_name Block
extends RefCounted


var buffer := VoxelBuffer.new()
var mesh: Mesh


func create(block_size: int) -> void:
	block_size += 2
	buffer.create(block_size, block_size, block_size)
