@tool
@icon("res://addons/vertex_animation_plugin/icons/vertex_animation_player_icon.svg")
class_name VertexAnimationMultiMeshPlayer
extends Node

@export var multi_mesh_instance: MultiMeshInstance3D
@export var animations: Array[VertexAnimation]
@export var animation_FPS: float = 30.0


func play(animation_index: int, instance: int) -> void:
	var animation: VertexAnimation = animations[animation_index]
	var anim_data := Color(animation.start_frame, animation.frame_count, animation.speed, GlobalShaderTimer.time)
	multi_mesh_instance.multimesh.set_instance_custom_data(instance, anim_data)
	# Uncomment if you use interpolation, to prevent ghosting
	#multimesh.reset_instance_physics_interpolation(instance)


func get_animation_frame_time(animation: VertexAnimation) -> float:
	return 1.0 / (animation_FPS * animation.speed)


func get_animation_index(animation_name: String) -> int:
	for i: int in range(animations.size()):
		if animations[i].name == animation_name:
			return i
	return -1