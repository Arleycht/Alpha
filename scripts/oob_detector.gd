extends Node


signal out_of_bounds(player)

var _players: Array


func _ready():
	var nodes := get_node("/root/").get_child(0).get_children()
	
	for node in nodes:
		if node is PlayerController and not _players.has(node):
			_players.append(node)


func _physics_process(_delta: float):
	for node in _players:
		var player := node as PlayerController
	
		if player == null:
			continue
		
		var position := player.get_position()
		
		if position.y < -100:
			if get_signal_connection_list("out_of_bounds").size() < 1:
				_on_oob_default(player)
			
			emit_signal("out_of_bounds", player)

func _on_oob_default(player: PlayerController):
	player.transform.origin = Vector3(0, 5, 0)
	player.velocity = Vector3()
