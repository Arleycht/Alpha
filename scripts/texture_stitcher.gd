extends Node2D


func _ready() -> void:
	var texture_dir := Directory.new()
	
	if texture_dir.open("res://textures") != OK:
		print("This should be changed to a soft crash to let users know " + \
				"that there's a problem")
		OS.crash("Failed to open texture directory")
	
	var file_names := texture_dir.get_files()
	var textures := []
	
	for file_name in file_names:
		if file_name.ends_with(".import"):
			continue
		
		var file_path = "%s/%s" % [texture_dir.get_current_dir(), file_name]
		var t := load(file_path) as Texture2D
		
		if t != null:
			textures.append(t)
		else:
			print("Failed to load %s" % file_name)
	
	var atlas_size := nearest_po2(textures.size())
	
	print(atlas_size)
