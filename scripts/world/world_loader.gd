class_name WorldLoader
extends Node


signal loaded

var library: VoxelBlockyLibrary
var materials: Array
var voxel_definitions: Dictionary
var atlas_map: Dictionary
var id_map: Dictionary
var name_map: Dictionary
var atlas_image: Image
var atlas_texture: ImageTexture


func load_definitions() -> void:
	# Clear/initialize variables
	
	library = VoxelBlockyLibrary.new()
	materials = []
	voxel_definitions = {}
	atlas_map = {}
	id_map = {}
	name_map = {}
	atlas_image = Image.new()
	
	# Load from config
	
	var modules := _load_modules()
	var module_names := modules.keys()
	module_names.sort_custom(func(a, b):
		return a['load_order'] < b['load_order']
	)
	
	# Generate atlas map
	
	for module_name in module_names:
		for i in modules[module_name]['definitions'].size():
			var module_path: String = modules[module_name]['path']
			var def: Dictionary = modules[module_name]['definitions'][i]
			var voxel_name := "%s:%s" % [module_name, def['name']]
			
			if voxel_name in voxel_definitions:
				printerr("Skipping duplicated voxel at \"%s\"" % voxel_name)
				continue
			else:
				def['name'] = voxel_name
				voxel_definitions[voxel_name] = def
				print("Loaded \"%s\"" % voxel_name)
			
			for side in def['textures']:
				var file_name: String = def['textures'][side]
				var path := "%s/textures/%s" % [module_path, file_name]
				var texture_id: String
				
				if File.file_exists(path):
					texture_id = "%s/%s" % [module_name, path]
				else:
					path = Constants.DEFAULT_TEXTURE_PATH
					texture_id = Constants.DEFAULT_TEXTURE_ID
					printerr("Failed to find \"%s\"" % path)
				
				def['textures'][side] = texture_id
				
				if texture_id not in atlas_map:
					var image := _load_image(path)
					atlas_map[texture_id] = {
						'image': image,
						'rect': Rect2i(0, 0, image.get_width(), image.get_height()),
					}
					print("Loaded \"%s\"" % path)
	
	# Stitch textures
	
	var size := _pack_atlas(atlas_map)
	atlas_image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	
	for texture_id in atlas_map:
		var img := atlas_map[texture_id]['image'] as Image
		var src_rect := Rect2i(Vector2(), img.get_size())
		var dst := atlas_map[texture_id]['rect'].position as Vector2i
		atlas_image.blit_rect(atlas_map[texture_id]['image'], src_rect, dst)
	
	atlas_texture = ImageTexture.create_from_image(atlas_image)
	atlas_image.save_png("res://.temp/test.png")
	
	# Create material
	
	var default_material := StandardMaterial3D.new()
	default_material.albedo_texture = atlas_texture
	default_material.vertex_color_use_as_albedo = true
	default_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	materials.append(default_material)
	
	# Load library
	
	library.voxel_count = 1
	library.bake_tangents = false
	library.create_voxel(0, "empty")
	id_map["core:air"] = 0
	name_map[0] = "core:air"
	
	for voxel_name in voxel_definitions:
		library.voxel_count += 1
		id_map[voxel_name] = library.voxel_count - 1
		name_map[library.voxel_count - 1] = voxel_name
		
		var def: Dictionary = voxel_definitions[voxel_name]
		var voxel := library.create_voxel(library.voxel_count - 1, def['name'])
		var mesh := _build_cube_mesh(def['textures'])
		
		voxel.geometry_type = VoxelBlockyModel.GEOMETRY_CUSTOM_MESH
		voxel.custom_mesh = mesh
		voxel.set_material_override(0, default_material)
	
	library.bake()
	loaded.emit()


func _load_modules() -> Dictionary:
	var modules := {}
	
	var module_paths := [Constants.CORE_MODULE_PATH]
	var dir := Directory.new()
	
	if dir.open(Constants.MODULES_PATH) == OK:
		for module_name in dir.get_directories():
			module_paths.append(dir.get_current_dir() + "/" + module_name)
	
	for module_path in module_paths:
		var module_name := str(module_path).split('/')[-1]
		var load_order := 0
		var config := ConfigFile.new()
		var definitions := []
		
		if dir.open(module_path) != OK:
			printerr("Failed to load module at \"%s\"" % module_path)
			continue
		
		if config.load(dir.get_current_dir() + "/module.cfg") == OK:
			module_name = config.get_value("load", "name", module_name) as String
			load_order = config.get_value("load", "load_order", 1) as int
		
		dir.change_dir("definitions")
		
		for def_name in dir.get_files():
			if def_name.to_lower().ends_with(".json"):
				var def_path := dir.get_current_dir() + "/%s" % def_name
				var def := _load_definition_file(def_path)
				
				if not def.is_empty():
					definitions.append(def)
		
		modules[module_name] = {
			'path': module_path,
			'load_order': load_order,
			'config': config,
			'definitions': definitions,
		}
	
	return modules


func _load_image(path: String) -> Image:
	var img := Image.new()
	
	if path.begins_with("res://"):
		var t: Variant = load(path)
		
		if t is Texture2D:
			img = t.get_image()
		else:
			img.load(Constants.DEFAULT_TEXTURE_PATH)
	else:
		img.load(path)
	
	img.convert(Image.FORMAT_RGBA8)
	
	return img


func _pack_atlas(atlas_map: Dictionary, padding: int = 2) -> Vector2i:
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
	
	size.x += images.size() * padding * 2
	
	var max_width: int = max(size.x >> 1, max_rect.size.x)
	var pos := Vector2i.ONE * padding
	
	size.x = 0
	size.y = 0
	
	for data in images:
		var rect: Rect2i = data['rect']
		
		size.y = max(size.y, rect.size.y)
		
		if pos.x + rect.size.x + padding > max_width:
			pos.x = padding
			pos.y = size.y + padding
		
		rect.position = pos
		pos.x += rect.size.x + padding
		size.x = max(size.x, rect.position.x + rect.size.x)
		size.y = max(size.y, rect.position.y + rect.size.y)
		
		data['rect'] = rect
	
	return size + Vector2i.ONE * padding


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


func _map_uv(rect: Rect2i, atlas_size: Vector2):
	var s := (rect.size as Vector2) / atlas_size
	var a := (rect.position as Vector2) / atlas_size
	var b := a + Vector2(s.x, 0)
	var c := a + Vector2(0, s.y)
	var d := a + s
	return [d, a, b, d, c, a]


func _build_cube_mesh(textures: Dictionary) -> ArrayMesh:
	var vertices := [
		Vector3(0, 0, 0),
		Vector3(1, 0, 0),
		Vector3(1, 0, 1),
		Vector3(0, 0, 1),
		Vector3(0, 1, 0),
		Vector3(1, 1, 0),
		Vector3(1, 1, 1),
		Vector3(0, 1, 1),
	]
	
	var normals := [
		Vector3(1, 0, 0),
		Vector3(0, 0, 1),
		Vector3(-1, 0, 0),
		Vector3(0, 0, -1),
		Vector3(0, 1, 0),
		Vector3(0, -1, 0),
	]
	
	var indices := [
		0, 5, 4, 0, 1, 5,
		1, 6, 5, 1, 2, 6,
		2, 7, 6, 2, 3, 7,
		3, 4, 7, 3, 0, 4,
		4, 6, 7, 4, 5, 6,
		3, 1, 0, 3, 2, 1,
	]
	
	var mesh := ArrayMesh.new()
	var array := []
	array.resize(Mesh.ARRAY_MAX)
	
	array[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	array[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	array[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	array[Mesh.ARRAY_INDEX] = PackedInt32Array()
	
	for side in 6:
		for tri in 2:
			var v := PackedVector3Array()
			var j = (side * 6) + (tri * 3)
			
			for i in 3:
				v.append(vertices[indices[j + i]])
			
			var n := PackedVector3Array()
			n.resize(3)
			n.fill(normals[side])
			
			array[Mesh.ARRAY_VERTEX].append_array(v)
			array[Mesh.ARRAY_NORMAL].append_array(n)
			array[Mesh.ARRAY_INDEX].append_array([j, j + 1, j + 2])
	
	# Map UVs to texture atlas
	
	var atlas_size := atlas_texture.get_size()
	
	if 'all' in textures:
		var texture_id: String = textures['all']
		var rect: Rect2i = atlas_map[texture_id]['rect']
		var face_uv := _map_uv(rect, atlas_size)
		
		for i in 6:
			array[Mesh.ARRAY_TEX_UV].append_array(face_uv)
	else:
		var uvs: PackedVector2Array = array[Mesh.ARRAY_TEX_UV]
		uvs.resize(36)
		
		for side in textures:
			var texture_id: String = textures[side]
			var rect: Rect2i = atlas_map[texture_id]['rect']
			var face_uv := _map_uv(rect, atlas_size)
			var face := 0
			
			match side:
				"south":
					face = 0
				"west":
					face = 1
				"north":
					face = 2
				"east":
					face = 3
				"top":
					face = 4
				"bottom":
					face = 5
			
			for i in 6:
				uvs[(face * 6) + i] = face_uv[i]
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
	mesh.regen_normal_maps()
	return mesh
