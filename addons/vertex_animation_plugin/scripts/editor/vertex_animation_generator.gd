@tool
class_name VertexAnimationGenerator
extends RefCounted

var animations_texture_image: Image
var animations_normal_texture_image: Image
var selected_animations_vat: Array[VertexAnimation]
var minimum_vertex_position := Vector3.ZERO
var mesh_max_size: float
var all_frames_count := 0

var _animation_player: AnimationPlayer
var _animations: Dictionary[String, bool]
var _animated_meshes: Array[MeshInstance3D]
var _animation_FPS: int
var _scene_tree: SceneTree

var _animations_vertex_positions: PackedVector3Array
var _animations_vertex_normals: PackedVector3Array

var _all_vertex_count := 0
var _vertex_count_in_column: int
var _vertex_columns_count: int


func _init(animation_player: AnimationPlayer, animations: Dictionary[String, bool], animated_meshes: Array[MeshInstance3D], animation_FPS: int, scene_tree: SceneTree) -> void:
	_animation_player = animation_player
	_animations = animations
	_animated_meshes = animated_meshes
	_animation_FPS = animation_FPS
	_scene_tree = scene_tree


func generate_vat() -> void:
	var animation_frame_time: float = 1.0 / _animation_FPS
	selected_animations_vat = _get_selected_animations_vat(_animations, _animation_player, animation_frame_time)
	all_frames_count = _get_all_frames_count(selected_animations_vat)
	await _set_animations_vertices_position_and_normals(animation_frame_time)

	_all_vertex_count = _get_all_vertex_count(_animated_meshes)
	_set_close_to_square_vertex_for_texture_size(all_frames_count, _all_vertex_count)
	_set_mesh_transform_data(_animations_vertex_positions)

	_create_animation_textures()
	_fill_animation_textures()


func _set_animations_vertices_position_and_normals(animation_frame_time: float) -> void:
	for animation: VertexAnimation in selected_animations_vat:
		_animation_player.play(animation.name)
		_animation_player.stop()
		for frame: int in range(animation.frame_count + 1):
			_animation_player.seek(animation_frame_time * frame, true, true)
			await _scene_tree.process_frame
			#await RenderingServer.frame_post_draw
			for animated_mesh: MeshInstance3D in _animated_meshes:
				var baked_mesh: ArrayMesh = animated_mesh.mesh if animated_mesh.skin == null else animated_mesh.bake_mesh_from_current_skeleton_pose()

				for surface_index in range(baked_mesh.get_surface_count()):
					var mesh_data := MeshDataTool.new()
					mesh_data.create_from_surface(baked_mesh, surface_index)

					for vertex_index: int in range(mesh_data.get_vertex_count()):
						if animated_mesh.skin == null: # If mesh is child BoneAttachmen3D
							_animations_vertex_positions.append(animated_mesh.global_transform * mesh_data.get_vertex(vertex_index))
							_animations_vertex_normals.append(animated_mesh.global_basis * mesh_data.get_vertex_normal(vertex_index))
						else:
							_animations_vertex_positions.append(mesh_data.get_vertex(vertex_index))
							_animations_vertex_normals.append(mesh_data.get_vertex_normal(vertex_index))


func _create_animation_textures() -> void:
	var texture_width: int = all_frames_count * _vertex_columns_count
	animations_texture_image = Image.create_empty(texture_width, _vertex_count_in_column, false, Image.Format.FORMAT_RGBF)
	animations_normal_texture_image = Image.create_empty(texture_width, _vertex_count_in_column, false, Image.Format.FORMAT_RGB8)


func _fill_animation_textures() -> void:
	for vertex_column: int in range(_vertex_columns_count):
		for frame: int in range(all_frames_count):
			var pixel_pos_x: int = vertex_column * all_frames_count + frame
			var vertex_column_offset: int = vertex_column * _vertex_count_in_column

			for vertex_index: int in range(_vertex_count_in_column):
				var vertex_offset_index: int = vertex_index + vertex_column_offset
				if vertex_offset_index >= _all_vertex_count:
					continue
					
				var vertex_color: Vector3 = _get_vertex_color(frame, vertex_offset_index, _animations_vertex_positions)
				animations_texture_image.set_pixel(pixel_pos_x, vertex_index, Color(vertex_color.x, vertex_color.y, vertex_color.z))

				vertex_color = _get_vertex_color(frame, vertex_offset_index, _animations_vertex_normals)
				animations_normal_texture_image.set_pixel(pixel_pos_x, vertex_index, Color(vertex_color.x, vertex_color.y, vertex_color.z))
				

func _get_vertex_color(index_x: int, index_y: int, vertex_array: PackedVector3Array) -> Vector3:
	var index_1d = index_x * _all_vertex_count + index_y
	var vertex_color: Vector3 = (vertex_array[index_1d] + minimum_vertex_position) / mesh_max_size
	if !_is_vector3_in_range(vertex_color, Vector2(0.0, 1.0)):
		vertex_color = _vector3_round_epsilon(vertex_color)
		if !_is_vector3_in_range(vertex_color, Vector2(0.0, 1.0)):
			printerr("Vertex color" + str(vertex_color) + " is out of scope pixel color between 0..1")
	return vertex_color


func _get_all_vertex_count(animated_meshes: Array[MeshInstance3D]) -> int:
	var all_vertex_count := 0
	for animated_mesh: MeshInstance3D in animated_meshes:
		var baked_mesh: ArrayMesh = animated_mesh.mesh
		for surface_index in range(baked_mesh.get_surface_count()):
			var mesh_data := MeshDataTool.new()
			mesh_data.create_from_surface(baked_mesh, surface_index)
			all_vertex_count += mesh_data.get_vertex_count()
	return all_vertex_count


func _set_close_to_square_vertex_for_texture_size(all_frames_count: int, all_vertex_count: int) -> void:
	# Divide the vertices and arrange them in columns (texture width) to get a texture size close to a square
	_vertex_count_in_column = int(sqrt(all_frames_count * all_vertex_count))
	_vertex_columns_count = all_vertex_count / _vertex_count_in_column
	if all_vertex_count % _vertex_count_in_column > 0:
		_vertex_columns_count += 1

	
func _set_mesh_transform_data(animations_vertex_positions: PackedVector3Array) -> void:
	var minimum_position := Vector3.ZERO
	var maximum_position := Vector3.ZERO

	for vertex: Vector3 in animations_vertex_positions:
		minimum_position = _min_vector3_value(minimum_position, vertex)
		maximum_position = _max_vector3_value(maximum_position, vertex)

	# Determine the minimum position to move the vertices to positive space
	# Addind Vector3.One to prevent negative vertex normal, if the minimum position is not negative but very close to zero
	# All this is needed to save vertex position as a pixel which takes values ​​from 0 to 1
	minimum_vertex_position = ceil(abs(minimum_position) + Vector3.ONE)
	var add_positions: Vector3 = minimum_vertex_position + ceil(abs(maximum_position))
	mesh_max_size = max(add_positions.x, add_positions.y, add_positions.z)


func _get_selected_animations_vat(animations: Dictionary[String, bool], animation_player: AnimationPlayer, animation_frame_time: float) -> Array[VertexAnimation]:
	var selected_animations: Array[VertexAnimation]
	var frame_offset := 0

	for animation_name in animations.keys():
		if not animations[animation_name]:
			continue
		var frames_count := ceili(animation_player.get_animation(animation_name).length / animation_frame_time)
		var animation := VertexAnimation.new()
		animation.init(animation_name, frame_offset, frames_count)
		selected_animations.append(animation)
		frame_offset += frames_count + 1
	
	return selected_animations


func _get_all_frames_count(animations_vat: Array[VertexAnimation]) -> int:
	var all_frames_count := 0
	for animation: VertexAnimation in animations_vat:
		all_frames_count += animation.frame_count + 1
	return all_frames_count
	

#region VectorUtils
func _max_vector3_value(vect_1: Vector3, vect_2: Vector3) -> Vector3:
	var return_vector: Vector3
	return_vector.x = maxf(vect_1.x, vect_2.x)
	return_vector.y = maxf(vect_1.y, vect_2.y)
	return_vector.z = maxf(vect_1.z, vect_2.z)
	return return_vector


func _min_vector3_value(vect_1: Vector3, vect_2: Vector3) -> Vector3:
	var return_vector: Vector3
	return_vector.x = minf(vect_1.x, vect_2.x)
	return_vector.y = minf(vect_1.y, vect_2.y)
	return_vector.z = minf(vect_1.z, vect_2.z)
	return return_vector


func _is_vector3_in_range(vector: Vector3, range: Vector2) -> bool:
	if vector.x < range.x or vector.x > range.y or vector.y < range.x or vector.y > range.y or vector.z < range.x or vector.z > range.y:
		return false
	return true


func _vector3_round_epsilon(vertex_color: Vector3, epsilon := 0.00001) -> Vector3:
	return vertex_color.snapped(Vector3(epsilon, epsilon, epsilon))
#endregion