class_name BuildTool
extends Control


const INTERACTION_TOOL := true

var _start: Vector3i
var _end: Vector3i


func use(player: Player, event: InputEvent) -> bool:
	if player == null:
		return false
	
	if event is InputEventMouseButton:
		var result := Util.voxel_cast_from_screen(player.world, player.get_camera())
		var prev_pos: Vector3i = result['previous_position']
		var pos: Vector3i = result['position']
		var voxel_name := player.world.get_voxel(pos)
		
		if voxel_name != "core:air":
			var dir := player.get_camera_position() - Vector3(pos)
			if event.is_action_pressed("primary"):
				_start = prev_pos
			elif event.is_action_released("primary"):
				_end = prev_pos
				
				var aabb := Util.get_aabb(_start, _end)
				
				player.world.tool.value = player.world._loader.id_map["core:dirt"]
				player.world.tool.do_box(aabb.position, aabb.end)
			
			return true
	
	return false
