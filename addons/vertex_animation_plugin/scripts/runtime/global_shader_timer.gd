@tool
extends Node

var time: float = 0.0

func _process(delta: float) -> void:
	time += delta
	RenderingServer.global_shader_parameter_set("global_shader_time", time)