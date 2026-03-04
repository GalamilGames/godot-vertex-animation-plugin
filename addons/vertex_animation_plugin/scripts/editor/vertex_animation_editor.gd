@tool
@icon("res://addons/vertex_animation_plugin/icons/vertex_animation_editor_icon.svg")
class_name VertexAnimationEditor
extends Node

@export_tool_button("Create") var create_button := _create

@export var _animation_player: AnimationPlayer:
	set(value): _animation_player = value; _update_animation_list()
@export var _animated_meshes: Array[MeshInstance3D]

@export var _animation_FPS := 30
## Generate mesh level of detail
@export var _generate_LOD := true

@export_group("Animation Selection")
@export var _select_all := true:
	set(value): _select_all = value; _update_animation_list(_select_all)
@export var _animations: Dictionary[String, bool]

@export_group("Create Mesh")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var _create_mesh = true
@export var _shader_mesh: Shader = preload("res://addons/vertex_animation_plugin/shaders/va_base_mesh_shader.gdshader")

@export_group("Create MultiMesh")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var _create_multimesh = false
@export var _shader_multimesh: Shader = preload("res://addons/vertex_animation_plugin/shaders/va_base_multimesh_shader.gdshader")

@export_group("Save Animation Textures To File")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var _save_texture_to_file = false
## Textures won't be included in the material, but saved to separate files.[br][br]
## [b]Note:[/b] saved textures may not work correctly, you need to change file import settings of the created textures:[br]
## Compress Mode: VRAM Uncompressed [br]Mipmaps Generate: Off [br]Detect 3D Compress to: Disabled
@export var _texture_file_name := "animation_texture"
@export_dir var _save_directory := "res://"

@export_group("Merge Material Textures")
## The merging feature supports textures: albedo, metallic, roughness, emission, normal, ambient occlusion.[br]
## [b]Note:[/b] If texture overlaps occur, it may be helpful to disable mipmap generation in the source texture import settings.[br]
## [b]Note:[/b] Due to the resizing process, the merged texture may differ from the original. This is especially noticeable if a low target resolution is selected.
## Some loss of detail or minor artifacts might occur.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var _merge_textures = false
@export var size_returned_texture: TextureMerger.TextureSize = TextureMerger.TextureSize._1024

var _merged_textures_types_names: Dictionary[TextureMerger.TextureType, String] = {
	TextureMerger.TextureType.TEXTURE_ALBEDO: "texture_albedo",
    TextureMerger.TextureType.TEXTURE_METALLIC: "texture_metallic",
	TextureMerger.TextureType.TEXTURE_ROUGHNESS: "texture_roughness",
	TextureMerger.TextureType.TEXTURE_EMISSION: "texture_emission",
	TextureMerger.TextureType.TEXTURE_NORMAL: "texture_normal",
	TextureMerger.TextureType.TEXTURE_AMBIENT_OCCLUSION: "texture_ambient_occlusion"
}

var _default_vsync_mode: DisplayServer.VSyncMode


func _create() -> void:
	_default_vsync_mode = DisplayServer.window_get_vsync_mode() # Turn off vsync to generate at maximum speed
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	print("Animation generation started")

	var vat_data := VertexAnimationGenerator.new(_animation_player, _animations, _animated_meshes, _animation_FPS, get_tree())
	await vat_data.generate_vat()

	var mesh_textures_data: Dictionary = await _create_mesh_with_textures()

	if _create_mesh:
		var material := _create_shader_material(_shader_mesh, vat_data, mesh_textures_data["textures"])
		_create_mesh_game_objects(vat_data.selected_animations_vat, mesh_textures_data["mesh"], material)

	if _create_multimesh:
		var material := _create_shader_material(_shader_multimesh, vat_data, mesh_textures_data["textures"])
		_create_multimesh_game_objects(vat_data.selected_animations_vat, mesh_textures_data["mesh"], material)

	if _save_texture_to_file:
		await _save_animation_textures(vat_data, mesh_textures_data["textures"])

	print("Animation generation completed")
	
	DisplayServer.window_set_vsync_mode(_default_vsync_mode)


#region GameObjects
func _create_mesh_game_objects(animations_vat: Array[VertexAnimation], new_mesh: Mesh, material: ShaderMaterial) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = _animated_meshes[0].name + "Mesh"
	mesh_instance.mesh = new_mesh
	mesh_instance.material_override = material
	get_tree().edited_scene_root.add_child(mesh_instance)
	mesh_instance.owner = get_tree().edited_scene_root

	var vertex_animation_player := VertexAnimationMeshPlayer.new()
	vertex_animation_player.name = "VertexAnimationMeshPlayer"
	vertex_animation_player.animation_FPS = _animation_FPS
	vertex_animation_player.animations = animations_vat
	vertex_animation_player.mesh_instance = mesh_instance
	mesh_instance.add_child(vertex_animation_player)
	vertex_animation_player.owner = get_tree().edited_scene_root


func _create_multimesh_game_objects(animations_vat: Array[VertexAnimation], new_mesh: Mesh, material: ShaderMaterial) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = new_mesh
	multimesh.instance_count = 1
	multimesh.set_instance_transform(0, Transform3D.IDENTITY)
	multimesh.set_instance_custom_data(0, Color(0.0, 1.0, 0.0, 0.0))

	var multi_mesh_instance := MultiMeshInstance3D.new()
	multi_mesh_instance.name = _animated_meshes[0].name + "MultiMesh"
	multi_mesh_instance.multimesh = multimesh
	multi_mesh_instance.material_override = material
	get_tree().edited_scene_root.add_child(multi_mesh_instance)
	multi_mesh_instance.owner = get_tree().edited_scene_root

	var vertex_animation_player := VertexAnimationMultiMeshPlayer.new()
	vertex_animation_player.name = "VertexAnimationMultiMeshPlayer"
	vertex_animation_player.animation_FPS = _animation_FPS
	vertex_animation_player.animations = animations_vat
	vertex_animation_player.multi_mesh_instance = multi_mesh_instance
	multi_mesh_instance.add_child(vertex_animation_player)
	vertex_animation_player.owner = get_tree().edited_scene_root


func _create_mesh_with_textures() -> Dictionary:
	var return_mesh: Mesh
	var return_textures: Dictionary[String, Texture2D]
	var merged_texture_data: TextureMerger.MergedTextureData

	if _merge_textures:
		var texture_merger := TextureMerger.new()
		texture_merger.merged_textures_types_names = _merged_textures_types_names
		texture_merger.size_merged_texture = size_returned_texture
		merged_texture_data = texture_merger.create_merge_textures_from_meshes(_animated_meshes)
		for texture_name: String in merged_texture_data.merged_textures_images.keys():
			if merged_texture_data.merged_textures_images[texture_name]:
				var texture := ImageTexture.create_from_image(merged_texture_data.merged_textures_images[texture_name])
				return_textures.set(texture_name, texture)
	else:
		var active_material: Material = _animated_meshes[0].get_active_material(0)
		for texture_type: TextureMerger.TextureType in _merged_textures_types_names.keys():
			var texture: Texture2D = TextureMerger.get_texture_from_material(active_material, texture_type, _merged_textures_types_names[texture_type])
			if texture:
				return_textures.set(_merged_textures_types_names[texture_type], texture)

	if _animated_meshes.size() < 2 and _animated_meshes[0].mesh.get_surface_count() < 2: # 1 mesh, no merge need
		return_mesh = _animated_meshes[0].mesh
	elif _merge_textures:
		return_mesh = MeshMerger.merge_meshes_update_uvs(_animated_meshes, merged_texture_data.textures_uv_positions, merged_texture_data.textures_uv_scale)
	else:
		return_mesh = MeshMerger.merge_meshes(_animated_meshes)

	if _generate_LOD:
		return_mesh = MeshMerger.generate_lods(return_mesh)

	var mesh_textures_data: Dictionary
	mesh_textures_data.set("mesh", return_mesh)
	mesh_textures_data.set("textures", return_textures)
	return mesh_textures_data


func _create_shader_material(shader: Shader, vat_data: VertexAnimationGenerator, visual_textures: Dictionary[String, Texture2D]) -> ShaderMaterial:
	var animation_texture := ImageTexture.create_from_image(vat_data.animations_texture_image)
	var animation_normal_texture := ImageTexture.create_from_image(vat_data.animations_normal_texture_image)
	
	var material := ShaderMaterial.new()
	material.shader = shader

	for texture_name: String in visual_textures.keys():
		material.set_shader_parameter(texture_name, visual_textures[texture_name])

	material.set_shader_parameter("animation_texture", animation_texture)
	material.set_shader_parameter("animation_normal_texture", animation_normal_texture)
	material.set_shader_parameter("all_frames_count", vat_data.all_frames_count)
	material.set_shader_parameter("vertex_offset", vat_data.minimum_vertex_position)
	material.set_shader_parameter("max_mesh_size", vat_data.mesh_max_size)
	material.set_shader_parameter("animation_FPS", _animation_FPS)
	return material


func _save_animation_textures(vat_data: VertexAnimationGenerator, visual_textures: Dictionary[String, Texture2D]) -> void:
	var save_path := _save_directory + "/" + _texture_file_name
	var save_path_animation_texture: String = save_path + "_va.exr"
	var save_path_animation_normal_texture: String = save_path + "_normal_va.png"
	var save_paths_textures: PackedStringArray = [save_path_animation_texture, save_path_animation_normal_texture]

	vat_data.animations_texture_image.save_exr(save_path_animation_texture)
	vat_data.animations_normal_texture_image.save_png(save_path_animation_normal_texture)

	for texture_name: String in visual_textures.keys():
		var save_path_visual_texture := save_path + "_" + texture_name + "_va.png"
		save_paths_textures.append(save_path_visual_texture)
		visual_textures[texture_name].image.save_png(save_path_visual_texture)

	await update_resource_filesystem(save_paths_textures)


func update_resource_filesystem(save_paths: PackedStringArray) -> void:
	await get_tree().process_frame
	for file: String in save_paths:
		EditorInterface.get_resource_filesystem().update_file(file)
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	await get_tree().process_frame
	EditorInterface.get_resource_filesystem().reimport_files(save_paths)
#endregion

#region Editor
func _update_animation_list(select := true) -> void:
	_animations.clear()
	for animation in _animation_player.get_animation_list():
		_animations.set(animation, select)
	notify_property_list_changed()


func _create_popup_window() -> Window:
	var label := Label.new()
	label.text = "Generating animation textures"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)

	var popup_window := Window.new()
	popup_window.size = Vector2i(300, 50)
	#popup_window.exclusive = true
	popup_window.borderless = true
	popup_window.unfocusable = true
	popup_window.add_child(label)

	EditorInterface.popup_dialog_centered(popup_window)
	
	return popup_window
#endregion