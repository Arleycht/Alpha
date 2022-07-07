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
	var voxel_names := {}
	var voxels := [
		{
			'name': "empty",
			'geometry_type': VoxelBlockyModel.GEOMETRY_NONE,
		}
	]
	var atlas_map := {}
	var default_mesh = load(DEFAULT_MESH_PATH)
	
	# TODO:
	# All this code will be scrapped to instead perform the following:
	#
	# Textures will all be stitched to an atlas and an atlas_map will contain
	# mappings from texture paths to metadata concerning their position and size
	# in the atlas so that UVs can be mapped to the texture atlas
	
	for module_name in modules.keys():
		for i in modules[module_name]['definitions'].size():
			var def: Dictionary = modules[module_name]['definitions'][i]
			var texture_paths: Dictionary = def['textures']
			
			for file_name in texture_paths.values():
				var texture_id := "%s/%s" % [module_name, file_name]
				var path := _get_texture_path(module_name, file_name)
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
		var src_rect := Rect2(Vector2(), img.get_size())
		var dst := atlas_map[texture_id]['rect'].position as Vector2i
		atlas_image.blit_rect(atlas_map[texture_id]['image'], src_rect, dst)
	
	var atlas_texture := ImageTexture.new()
	atlas_texture.create_from_image(atlas_image)
	
	library.bake()


func _load_modules() -> Dictionary:
	var modules := {}
	
	var dir := Directory.new()
	dir.change_dir("res://modules/")
	
	for module_name in dir.get_directories():
		var sub_dir := Directory.new()
		var definitions := []
		
		sub_dir.change_dir(dir.get_current_dir())
		sub_dir.change_dir(module_name + "/definitions")
		
		for def_name in sub_dir.get_files():
			if def_name.to_lower().ends_with(".json"):
				var def_path := sub_dir.get_current_dir() + "/%s" % def_name
				var def := _load_definition_file(def_path)
				
				if not def.is_empty():
					definitions.append(def)
		
		modules[module_name] = {
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
	return "res://modules/%s/textures/%s" % [module_name, file_name]


func _load_image(path: String) -> Image:
	if path == null or not File.file_exists(path):
		path = DEFAULT_TEXTURE_PATH
	
	var img := Image.new()
	var texture := ImageTexture.new()
	img.load(path)
	img.convert(Image.FORMAT_RGBA8)
	
	return img


func _pack_atlas(atlas_map: Dictionary) -> Vector2i:
	var min_pos := Vector2i()
	var max_pos := Vector2i()
	
	# TODO: Use a more optimal rectangle packing strategy
	# Maps to a straight line, suboptimal if rectangles differ in size
	var x := 0
	for k in atlas_map:
		var data: Dictionary = atlas_map[k]
		var rect := data['rect'] as Rect2i
		rect.position.x = x
		x += rect.size.x
		
		atlas_map[k]['rect'] = rect
		min_pos.x = min(min_pos.x, rect.position.x)
		min_pos.y = min(min_pos.y, rect.position.y)
		max_pos.x = max(max_pos.x, rect.position.x + rect.size.x)
		max_pos.y = max(max_pos.y, rect.position.y + rect.size.y)
	
	return max_pos - min_pos


func _build_cube_mesh(p: float = 0.0, q: float = 1.0 / 6.0) -> ArrayMesh:
	var tool := MeshDataTool.new()
	var mesh := ArrayMesh.new()
	
	tool.commit_to_surface(mesh)
	return mesh
