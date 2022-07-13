class_name DigTool
extends Control


const INTERACTION_TOOL := true

var _start: Vector3i
var _end: Vector3i


func use(player: Player, event: InputEvent) -> bool:
	if player == null:
		return false
	
	if event is InputEventMouseButton:
		var result := Util.voxel_cast_from_screen(player.world, player.get_camera())
		var pos: Vector3i = result['position']
		var voxel_name := player.world.get_voxel(pos)
		
		if voxel_name != "core:air":
			if event.is_action_pressed("primary"):
				_start = pos
			elif event.is_action_released("primary"):
				_end = pos
				
				var aabb := Util.get_aabb(_start, _end)
				var positions := []
				
				Util.for_each_cell(aabb, func(pos):
					positions.append(pos)
					print(pos)
				)
				
				print(positions)
				
				var task := DigTask.new(player.current_priority, positions)
				player.daemon.add_task(task)
			
			return true
	
	return false
