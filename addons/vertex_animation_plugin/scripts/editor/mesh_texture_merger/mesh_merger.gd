@tool
class_name MeshMerger
extends RefCounted

static func merge_meshes(meshes: Array[MeshInstance3D]) -> ArrayMesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	for mesh_instance: MeshInstance3D in meshes:
		var current_mesh: Mesh = mesh_instance.mesh
		# Shifted elements such as objects in hands, vertices must have a shift transform
		var mesh_transform: Transform3D = mesh_instance.global_transform if mesh_instance.skin == null else mesh_instance.transform
		for surface_index in range(current_mesh.get_surface_count()):
			surface_tool.append_from(current_mesh, surface_index, mesh_transform)

	var new_mesh: ArrayMesh = surface_tool.commit()
	return new_mesh


static func merge_meshes_update_uvs(meshes: Array[MeshInstance3D], textures_uv_coords: Dictionary[Texture2D, Vector2], textures_uv_scale: Vector2) -> ArrayMesh:
	var merged_vertices: PackedVector3Array = []
	var merged_normals: PackedVector3Array = []
	var merged_uvs: PackedVector2Array = []
	var merged_uvs2: PackedVector2Array = []
	var merged_indices: PackedInt32Array = []
	var vertex_offset := 0

	for mesh_instance: MeshInstance3D in meshes:
		var current_mesh: Mesh = mesh_instance.mesh
		var current_transform: Transform3D = mesh_instance.global_transform if mesh_instance.skin == null else mesh_instance.transform

		for surface_index in range(current_mesh.get_surface_count()):
			var material: Material = mesh_instance.get_active_material(surface_index)
			var albedo_texture: Texture2D = material.albedo_texture
			var offset_uv: Vector2 = textures_uv_coords[albedo_texture] if textures_uv_coords.has(albedo_texture) else Vector2.ZERO
	
			var arrays := current_mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var uvs2: PackedVector2Array = PackedVector2Array() if not arrays[Mesh.ARRAY_TEX_UV2] else arrays[Mesh.ARRAY_TEX_UV2]

			for i in range(vertices.size()):
				var modified_normal := current_transform.basis * normals[i] if i < normals.size() else Vector3.ZERO
				var modified_uv := uvs[i] * textures_uv_scale + offset_uv if i < uvs.size() else Vector2.ZERO
				var modified_uv2 := uvs2[i] * textures_uv_scale + offset_uv if i < uvs2.size() else Vector2.ZERO
				merged_vertices.append(current_transform * vertices[i])
				merged_normals.append(modified_normal)
				merged_uvs.append(modified_uv)
				merged_uvs2.append(modified_uv2)

			if not indices.is_empty():
				for index in indices:
					merged_indices.append(index + vertex_offset)
			else:
				for i in range(vertices.size()):
					merged_indices.append(i + vertex_offset)

			vertex_offset += vertices.size()

	var new_mesh_arrays = []
	new_mesh_arrays.resize(Mesh.ARRAY_MAX)
	new_mesh_arrays[Mesh.ARRAY_VERTEX] = merged_vertices
	new_mesh_arrays[Mesh.ARRAY_NORMAL] = merged_normals
	new_mesh_arrays[Mesh.ARRAY_TEX_UV] = merged_uvs
	new_mesh_arrays[Mesh.ARRAY_TEX_UV2] = merged_uvs2
	new_mesh_arrays[Mesh.ARRAY_INDEX] = merged_indices
	
	var new_mesh := ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_mesh_arrays)
	return new_mesh


static func generate_lods(mesh: Mesh, normal_merge_angle: float = 25, normal_split_angle: float = 60) -> ArrayMesh:
	var mesh_importer := ImporterMesh.new()
	for i: int in range(mesh.get_surface_count()):
		var surface_arrays = mesh.surface_get_arrays(i)
		if surface_arrays.is_empty():
			continue
		mesh_importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
		mesh_importer.generate_lods(normal_merge_angle, normal_split_angle, Array())
	return mesh_importer.get_mesh()
