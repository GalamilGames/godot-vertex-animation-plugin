shader_type spatial;

#include "res://addons/vertex_animation_plugin/shaders/va_base_shader_include.gdshaderinc"
#include "res://addons/vertex_animation_plugin/shaders/va_shader_include.gdshaderinc"

instance uniform vec4 current_animation_data = vec4(0.0, 1.0, 0.0, 0.0); // (start_frame, frame_count, speed, start_time_offset)

void vertex() {
	vec2 texture_coords = get_vertex_frame_texture_coords(VERTEX_ID, current_animation_data);
	VERTEX = get_animation_vertex_position(animation_texture, texture_coords);
	NORMAL = get_animation_vertex_position(animation_normal_texture, texture_coords);
}