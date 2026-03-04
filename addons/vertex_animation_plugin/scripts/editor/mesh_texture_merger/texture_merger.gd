@tool
class_name TextureMerger
extends RefCounted

enum TextureSize {
	_128 = 128,
	_256 = 256,
	_512 = 512,
	_1024 = 1024,
	_2048 = 2048,
	_4096 = 4096,
	_8192 = 8192
}

enum TextureType {
	TEXTURE_ALBEDO = 0,
	TEXTURE_METALLIC = 1,
	TEXTURE_ROUGHNESS = 2,
	TEXTURE_EMISSION = 3,
	TEXTURE_NORMAL = 4,
	TEXTURE_AMBIENT_OCCLUSION = 8
}


## Dictionary of shader texture uniform names to be identified and merged.
## Default values ​​follow the BaseMaterial3D naming convention and can be used in inheriting materials.
var merged_textures_types_names: Dictionary[TextureType, String] = {
	TextureType.TEXTURE_ALBEDO: "texture_albedo",
    TextureType.TEXTURE_METALLIC: "texture_metallic",
	TextureType.TEXTURE_ROUGHNESS: "texture_roughness",
	TextureType.TEXTURE_EMISSION: "texture_emission",
	TextureType.TEXTURE_NORMAL: "texture_normal",
	TextureType.TEXTURE_AMBIENT_OCCLUSION: "texture_ambient_occlusion"
}
var size_merged_texture := TextureSize._1024


## Creates merged textures for the provided [param meshes] based on the mapping 
## defined in the [member merged_textures_types_names] dictionary.
## The final UV layout and atlas positioning are determined by the reference [param uv_texture_type]
func create_merge_textures_from_meshes(meshes: Array[MeshInstance3D], uv_texture_type := TextureType.TEXTURE_ALBEDO) -> MergedTextureData:
	var unique_textures_materials: Array[Material] = _get_materials_unique_textures(meshes, uv_texture_type)
	if unique_textures_materials.size() < 2:
		printerr("Meshes contain " + str(unique_textures_materials.size()) + " unique  " + str(uv_texture_type) + ", no merging required")
		return null

	var textures_index_size_1D: int = _get_textures_index_size_1D(unique_textures_materials.size())
	var single_texture_pixel_size: int = size_merged_texture / textures_index_size_1D
	var uv_coord_shift: float = float(single_texture_pixel_size) / float(size_merged_texture)

	var merged_texture_data := MergedTextureData.new()
	merged_texture_data.textures_uv_scale = Vector2(uv_coord_shift, uv_coord_shift)
	var main_uv_textures: Array[Texture2D] = _get_or_create_textures_from_materials(unique_textures_materials, uv_texture_type)
	merged_texture_data.textures_uv_positions = _get_textures_uv_coords(main_uv_textures, textures_index_size_1D, uv_coord_shift)

	for texture_type: TextureType in merged_textures_types_names.keys():
		var merged_texture: Image = _try_merge_textures_from_material(unique_textures_materials, texture_type, textures_index_size_1D, single_texture_pixel_size)
		merged_texture_data.merged_textures_images.set(merged_textures_types_names[texture_type], merged_texture)
	return merged_texture_data


func _try_merge_textures_from_material(materials: Array[Material], texture_type: TextureType, textures_index_size_1D: int, single_texture_pixel_size: int) -> Image:
	if _get_textures_count_in_materials(materials, texture_type) == 0:
		return null
	var merged_textures: Array[Texture2D] = _get_or_create_textures_from_materials(materials, texture_type)
	var texture_image_format: Image.Format = _get_textures_image_format(merged_textures, texture_type)
	var merged_texture_image: Image = _merge_textures_images(merged_textures, textures_index_size_1D, single_texture_pixel_size, texture_image_format)
	return merged_texture_image


func _get_textures_count_in_materials(materials: Array[Material], texture_type: TextureType) -> int:
	var texture_name: String = merged_textures_types_names[texture_type]
	var textures_count := 0
	for material: Material in materials:
		if get_texture_from_material(material, texture_type, texture_name):
			textures_count += 1
	return textures_count


func _get_or_create_textures_from_materials(materials: Array[Material], texture_type: TextureType) -> Array[Texture2D]:
	var texture_name: String = merged_textures_types_names[texture_type]
	var return_textures: Array[Texture2D]
	for material: Material in materials:
		var texture: Texture2D = get_texture_from_material(material, texture_type, texture_name)
		if texture:
			return_textures.append(texture)
		else:
			return_textures.append(_create_texture_neutral_color(texture_type))
			print("Material " + material.resource_name + " does't contain an " + str(texture_name) + " - created neutral")
	return return_textures

	
# For the albedo texture, we choose whether to use the RGBA8 format, other types use RGB8
func _get_textures_image_format(textures: Array[Texture2D], texture_type: TextureType) -> Image.Format:
	if texture_type == TextureType.TEXTURE_ALBEDO:
		for texture: Texture2D in textures:
			if texture.get_image().detect_alpha() != Image.ALPHA_NONE:
				return Image.FORMAT_RGBA8
	return Image.FORMAT_RGB8


func _create_texture_neutral_color(texture_type: TextureType) -> Texture2D:
	var neutral_texture_color := Color(0.0, 0.0, 0.0) # metallic, roughness, ao, emission
	if texture_type == TextureType.TEXTURE_NORMAL:
		neutral_texture_color = Color(0.5, 0.5, 1.0)

	var image := Image.create(10, 10, false, Image.FORMAT_RGB8)
	image.fill(neutral_texture_color)
	return ImageTexture.create_from_image(image) as Texture2D


func _get_materials_unique_textures(meshes: Array[MeshInstance3D], texture_type: TextureType) -> Array[Material]:
	var texture_name: String = merged_textures_types_names[texture_type]
	var unique_textures: Dictionary[Texture2D, Material]

	for mesh_instance: MeshInstance3D in meshes:
		var current_mesh: Mesh = mesh_instance.mesh
		for surface_index in range(current_mesh.get_surface_count()):
			var material: Material = mesh_instance.get_active_material(surface_index)
			var unique_texture: Texture2D = get_texture_from_material(material, texture_type, texture_name)
			if unique_texture != null:
				if not unique_textures.has(unique_texture):
					unique_textures.set(unique_texture, material)
			else:
				printerr(mesh_instance.name + " material " + material.resource_name + " does't contain field: " + texture_name)
	return unique_textures.values()


static func get_texture_from_material(material: Material, texture_type: TextureType, texture_name: String) -> Texture2D:
	if material is BaseMaterial3D:
		return material.get_texture(texture_type)
	return material.get_shader_parameter(texture_name) as Texture2D


func _get_textures_uv_coords(textures: Array[Texture2D], textures_size_1D: int, uv_coord_shift: float) -> Dictionary[Texture2D, Vector2]:
	var textures_uv_coords: Dictionary[Texture2D, Vector2]
	var texture_index := 0
	var uv_coord := Vector2.ZERO

	for y: int in range(textures_size_1D):
		uv_coord.x = 0.0
		for x: int in range(textures_size_1D):
			if texture_index >= textures.size():
				return textures_uv_coords
			var texture: Texture2D = textures[texture_index]
			textures_uv_coords.set(texture, uv_coord)
			texture_index += 1
			uv_coord.x += uv_coord_shift
		uv_coord.y += uv_coord_shift
	
	return textures_uv_coords


func _merge_textures_images(textures: Array[Texture2D], textures_size_1D: int, single_texture_size: int, texture_image_format: Image.Format) -> Image:
	var merge_image := Image.create_empty(size_merged_texture, size_merged_texture, false, texture_image_format)
	var texture_index := 0
	var pixel_offset := Vector2i.ZERO

	for y: int in range(textures_size_1D):
		pixel_offset.x = 0.0
		for x: int in range(textures_size_1D):
			if texture_index >= textures.size():
				return merge_image
			var texture: Texture2D = textures[texture_index]
			var image: Image = _adjust_image(texture.get_image(), single_texture_size, texture_image_format)
			merge_image.blit_rect(image, Rect2(0, 0, image.get_width(), image.get_height()), pixel_offset)
			texture_index += 1
			pixel_offset.x += single_texture_size
		pixel_offset.y += single_texture_size

	return merge_image


func _adjust_image(image: Image, max_size: int, format: Image.Format) -> Image:
	if image.is_compressed():
		image.decompress()
	if image.has_mipmaps():
		image.clear_mipmaps()
	if image.get_width() != max_size or image.get_height() != max_size:
		image.resize(max_size, max_size, Image.INTERPOLATE_BILINEAR)
	if image.get_format() != format:
		image.convert(format)
	return image


func _get_textures_index_size_1D(textures_size: int) -> int:
	var textures_size_1D: int = textures_size / 2 + textures_size % 2
	if textures_size_1D == 1:
		textures_size_1D = 2
	return textures_size_1D


class MergedTextureData:
	var merged_textures_images: Dictionary[String, Image]
	var textures_uv_positions: Dictionary[Texture2D, Vector2]
	var textures_uv_scale: Vector2