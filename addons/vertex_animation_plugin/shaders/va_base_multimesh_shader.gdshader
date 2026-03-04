shader_type spatial;

#include "res://addons/vertex_animation_plugin/shaders/va_base_shader_include.gdshaderinc"
#include "res://addons/vertex_animation_plugin/shaders/va_shader_include.gdshaderinc"

void vertex() {
	vec2 texture_coords = get_vertex_frame_texture_coords(VERTEX_ID, INSTANCE_CUSTOM);
	VERTEX = get_animation_vertex_position(animation_texture, texture_coords);
	NORMAL = get_animation_vertex_position(animation_normal_texture, texture_coords);
}