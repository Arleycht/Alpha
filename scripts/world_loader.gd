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
	
	var modules := _load_modules()
	var voxel_names := {}
	var voxels := [
		{
			'name': "empty",
			'geometry_type': VoxelBlockyModel.GEOMETRY_NONE,
		}
	]
	var atlas_textures := []
	var default_mesh = load(DEFAULT_MESH_PATH)
	
	# TODO:
	# All this code will be scrapped to instead perform the following:
	#
	# Textures will all be stitched to an atlas and an atlas_map will contain
	# mappings from texture paths to metadata concerning their position and size
	# in the atlas so that UVs can be mapped to the texture atlas
	
	for module in modules.keys():
		for i in modules[module]['definitions'].size():
			var def: Dictionary = modules[module]['definitions'][i]
			var name: String = def['name']
			var geometry_type: int = VoxelBlockyModel.GEOMETRY_NONE
			var texture: Texture2D
			var transparent := false
			var transparency_index := 0
			var mesh: Mesh
			
			if name in voxel_names:
				printerr("Duplicated voxel name: %s" % name)
				continue
			
			var texture_def := def.get("textures", {}) as Dictionary
			
			if texture_def.is_empty():
				var t := _load_texture(DEFAULT_TEXTURE_PATH)
				atlas_textures.append({
					'texture': t,
					'size': t.get_width(),
				})
			elif 'all' in texture_def:
				var p := "res://modules/%s/textures/%s" % [module, texture_def['all']]
				var t := _load_texture(p)
				t.get_image().save_png("res://.temp/test.png")
				
				# Append to atlas_textures with metadata describing texture
				# size so that UVs can be calculated in stitching step
				pass
			else:
				for side in texture_def:
					print(side)
			
#			if File.file_exists(texture_path):
#				var image_texture := ImageTexture.new()
#				var image := Image.new()
#				image.convert(image.FORMAT_RGBA8)
#				image.load(texture_path)
#				image_texture.create_from_image(image)
#				texture = image_texture
#				print("Loaded texture at \"%s\"" % texture_path)
#			else:
#				printerr("Could not find texture at \"%s\"" % texture_path)
			
			match (def.get("geometry_type", "cube") as String).to_lower():
				"none":
					geometry_type = VoxelBlockyModel.GEOMETRY_NONE
					mesh = null
				"cube":
					geometry_type = VoxelBlockyModel.GEOMETRY_CUBE
					mesh = _build_cube_mesh()
				"mesh":
					geometry_type = VoxelBlockyModel.GEOMETRY_CUSTOM_MESH
			
			var mesh_path = def.get("mesh", null)
			
			if mesh_path != null and File.file_exists(mesh_path):
				mesh = load(mesh_path) as Mesh
				print("Loaded mesh at \"%s\"" % mesh_path)
			elif mesh_path != null:
				printerr("Could not find mesh at \"%s\"" % mesh_path)
			
			if def.has("transparent"):
				transparent = def.get("transparent", false) as bool
			
			if def.has("transparency_index"):
				transparency_index = def.get("transparency_index", 0) as int
			
			var data := {
				'name': name,
				'geometry_type': geometry_type,
				'texture_index': texture,
				'transparent': transparent,
				'transparency_index': transparency_index,
				'mesh': mesh,
			}
			
			voxel_names[name] = data
			voxels.append(data)
			atlas_textures.append(texture)
	
	# Stitch textures
	
	var atlas_image := Image.new()
	var atlas := ImageTexture.new()
	var atlas_resolution := 64
	var atlas_size := atlas_textures.size()
	
	atlas_image.create(atlas_resolution * atlas_size * 6, atlas_resolution,
			false, Image.FORMAT_RGBA8)
	
	for i in atlas_textures.size():
		var texture = atlas_textures[i] as Texture2D
		var src_image := texture.get_image()
		src_image.convert(Image.FORMAT_RGBA8)
		src_image.resize(atlas_resolution, atlas_resolution)
		var src := Rect2(Vector2(), Vector2.ONE * atlas_resolution)
		var dest := Vector2(i * atlas_resolution, 0)
		atlas_image.blit_rect(src_image, src, dest)
	
	atlas_image.save_png("res://test.png")
	atlas.create_from_image(atlas_image)
	
	# Create voxels in library
	
	library = VoxelBlockyLibrary.new()
	materials = []
	
	library.voxel_count = voxels.size()
	library.atlas_size = atlas_size
	
	var default_material := StandardMaterial3D.new()
	default_material.vertex_color_use_as_albedo = true
	default_material.albedo_texture = atlas
	materials.append(default_material)
	
	for id in voxels.size():
		var data := voxels[id]
		var voxel := library.create_voxel(id, data['name'])
		voxel.geometry_type = VoxelBlockyModel.GEOMETRY_NONE
	
		if 'mesh' in data:
			voxel.geometry_type = VoxelBlockyModel.GEOMETRY_CUSTOM_MESH
			voxel.custom_mesh = data['mesh']
	
		if 'transparent' in data:
			voxel.transparent = data['transparent']
	
		if 'transparency_index' in data:
			voxel.transparency_index = data['transparency_index']
	
		voxel.set_material_override(0, materials[0])
	
		print("Created voxel \"%s\"" % data['name'])
	
	# Bake mesh data
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


func _load_texture(path: String) -> Texture2D:
	if path == null or not File.file_exists(path):
		path = DEFAULT_TEXTURE_PATH
	
	var img := Image.new()
	var texture := ImageTexture.new()
	img.load(path)
	img.convert(Image.FORMAT_RGBA8)
	
	var s := max(img.get_width(), img.get_height()) as int
	img.resize(s, s)
	
	texture.create_from_image(img)
	return texture


func _build_cube_mesh(p: float = 0.0, q: float = 1.0 / 6.0) -> ArrayMesh:
	var tool := MeshDataTool.new()
	var mesh := ArrayMesh.new()
	
	tool.commit_to_surface(mesh)
	return mesh
