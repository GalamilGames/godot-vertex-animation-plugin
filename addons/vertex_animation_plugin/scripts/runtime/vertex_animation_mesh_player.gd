@tool
@icon("res://addons/vertex_animation_plugin/icons/vertex_animation_player_icon.svg")
class_name VertexAnimationMeshPlayer
extends Node

const INSTANCE_SHADER_PARAMETER := "current_animation_data"

@export var mesh_instance: MeshInstance3D
@export var animations: Array[VertexAnimation]
@export var animation_FPS: float = 30.0


func play(animation_index: int) -> void:
	var animation: VertexAnimation = animations[animation_index]
	var anim_data := Vector4(animation.start_frame, animation.frame_count, animation.speed, GlobalShaderTimer.time)
	mesh_instance.mesh.set_instance_shader_parameter(INSTANCE_SHADER_PARAMETER, anim_data)


func get_animation_frame_time(animation: VertexAnimation) -> float:
	return 1.0 / (animation_FPS * animation.speed)


func get_animation_index(animation_name: String) -> int:
	for i: int in range(animations.size()):
		if animations[i].name == animation_name:
			return i
	return -1