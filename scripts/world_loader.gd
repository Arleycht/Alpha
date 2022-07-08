class_name WorldLoader
extends Object


const DEFAULT_TEXTURE_PATH := "res://modules/core/textures/null.png"
const DEFAULT_MESH_PATH := "res://meshes/default_cube.obj"

var library: VoxelBlockyLibrary
var materials: Array


func _init() -> void:
	_load()


func _load() -> void:
	# Load from config
	
	library = VoxelBlockyLibrary.new()
	
	var modules := _load_modules()
	var module_names := modules.keys()
	module_names.sort_custom(func(a, b):
		return a['load_order'] < b['load_order']
	)
	
	var voxel_definitions := {}
	var voxels := [
		{
			'name': "empty",
			'geometry_type': VoxelBlockyModel.GEOMETRY_NONE,
		}
	]
	var atlas_map := {}
	var default_mesh = load(DEFAULT_MESH_PATH)
	
	# Generate atlas map
	
	for module_name in module_names:
		for i in modules[module_name]['definitions'].size():
			var def: Dictionary = modules[module_name]['definitions'][i]
			var voxel_id := "%s:%s" % [module_name, def['name'] as String]
			var texture_paths: Dictionary = def['textures']
			
			if voxel_id in voxel_definitions:
				printerr("Skipping duplicated voxel at \"%s\"" % voxel_id)
				continue
			else:
				voxel_definitions[voxel_id] = def
			
			for file_name in texture_paths.values():
				var path := _get_texture_path(module_name, file_name)
				var texture_id := "%s/%s" % [module_name, path.get_file()]
				var image := _load_image(path)
				atlas_map[texture_id] = {
					'image': image,
					'rect': Rect2i(0, 0, image.get_width(), image.get_height()),
				}
	
	# Stitch textures
	
	var size := _pack_atlas(atlas_map)
	var atlas_image := Image.new()
	atlas_image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	
	for texture_id in atlas_map:
		var img := atlas_map[texture_id]['image'] as Image
		var src_rect := Rect2i(Vector2(), img.get_size())
		var dst := atlas_map[texture_id]['rect'].position as Vector2i
		atlas_image.blit_rect(atlas_map[texture_id]['image'], src_rect, dst)
	
	var atlas_texture := ImageTexture.new()
	atlas_texture.create_from_image(atlas_image)
	
	# Generate meshes
	
	
	
	library.bake()


func _pack_atlas(atlas_map: Dictionary) -> Vector2i:
	var images := atlas_map.values()
	var size := Vector2i()
	var max_rect := Rect2i()
	
	# Sort by height
	images.sort_custom(func(a, b):
		return a['rect'].size.y > b['rect'].size.y
	)
	
	for data in images:
		var rect: Rect2i = data['rect']
		size.x += rect.size.x
		size.y = max(size.y, rect.size.y)
		
		if rect.size.x > max_rect.size.x or rect.size.y > max_rect.size.y:
			max_rect = rect
	
	# Arbitrarily choose a maximum width to pack into
	# Optimally should be close to a square, hence half the total combined width
	var max_width: int = max(size.x / 2, max_rect.size.x)
	var pos := Vector2i()
	
	size.x = 0
	size.y = 0
	
	for data in images:
		var rect: Rect2i = data['rect']
		
		size.y = max(size.y, rect.size.y)
		
		if pos.x + rect.size.x > max_width:
			pos.x = 0
			pos.y = size.y
		
		rect.position = pos
		pos.x += rect.size.x
		size.x = max(size.x, rect.position.x + rect.size.x)
		size.y = max(size.y, rect.position.y + rect.size.y)
		
		data['rect'] = rect
	
	return size


func _load_modules() -> Dictionary:
	var modules := {}
	
	var dir := Directory.new()
	dir.change_dir("res://modules/")
	
	for module_name in dir.get_directories():
		var sub_dir := Directory.new()
		var load_order := 0
		var config := ConfigFile.new()
		var definitions := []
		
		sub_dir.change_dir(dir.get_current_dir())
		sub_dir.change_dir(module_name)
		
		if sub_dir.file_exists("module"):
			config.load(sub_dir.get_current_dir() + "/module")
			load_order = config.get_section_key("load", "load_order", 1) as int
		
		sub_dir.change_dir("definitions")
		
		for def_name in sub_dir.get_files():
			if def_name.to_lower().ends_with(".json"):
				var def_path := sub_dir.get_current_dir() + "/%s" % def_name
				var def := _load_definition_file(def_path)
				
				if not def.is_empty():
					definitions.append(def)
		
		modules[module_name] = {
			"load_order": load_order,
			'config': config,
			'definitions': definitions,
		}
	
	return modules


func _load_definition_file(file_path: String) -> Dictionary:
	var file := File.new()
	var file_data: String
	var json := JSON.new()
	
	file.open(file_path, File.READ)
	file_data = file.get_as_text()
	file.close()
	
	json.parse(file_data)
	
	var data: Variant = json.get_data()
	
	if data is Dictionary:
		return data as Dictionary
	
	return {}


func _get_texture_path(module_name: String, file_name: String) -> String:
	var path := "res://modules/%s/textures/%s" % [module_name, file_name]
	
	if File.file_exists(path):
		return path
	
	return DEFAULT_TEXTURE_PATH


func _load_image(path: String) -> Image:
	if path == null or not File.file_exists(path):
		path = DEFAULT_TEXTURE_PATH
	
	var img := Image.new()
	var texture := ImageTexture.new()
	img.load(path)
	img.convert(Image.FORMAT_RGBA8)
	
	return img


func _build_cube_mesh(p: float = 0.0, q: float = 1.0 / 6.0) -> ArrayMesh:
	var tool := MeshDataTool.new()
	var mesh := ArrayMesh.new()
	
	var array := []
	array.resize(Mesh.ARRAY_MAX)
	
	array[Mesh.ARRAY_VERTEX] = []
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
	
	tool.commit_to_surface(mesh)
	return mesh
