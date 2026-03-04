group_uniforms animation;
uniform sampler2D animation_texture;
uniform sampler2D animation_normal_texture;

uniform int all_frames_count;
uniform vec3 vertex_offset = vec3(0.0, 0.0, 0.0);
uniform float max_mesh_size = 2.0;
uniform float animation_FPS = 30.0;

global uniform float global_shader_time;

vec2 get_vertex_frame_texture_coords(int vertex_id, vec4 animation_data) {
	float start_frame = animation_data.x;
	float frame_count = animation_data.y;
	float speed = animation_data.z;
	float start_global_time_offset = animation_data.w;
	vec2 texture_size = vec2(textureSize(animation_texture, 0));

	float time = (global_shader_time - start_global_time_offset) * speed;
	float current_frame = mod(time * animation_FPS, frame_count) + start_frame;

	int frame_index_shift_on_cut_texture_x = (vertex_id / int(texture_size.y)) * all_frames_count;
	float frame_index_on_cut_texture_x = current_frame + float(frame_index_shift_on_cut_texture_x);
	int vertex_index_on_cut_texture_y = vertex_id % int(texture_size.y);

	vec2 pixel_size = vec2(1.0 / texture_size.x, 1.0 / texture_size.y);
	float coord_x = float(frame_index_on_cut_texture_x) * pixel_size.x + pixel_size.x / 2.0;
	float coord_y = float(vertex_index_on_cut_texture_y) * pixel_size.y + pixel_size.y / 2.0;
	return vec2(coord_x, coord_y);
}

vec3 get_animation_vertex_position(sampler2D animation_tex, vec2 texture_coords) {
	vec3 vertex_position = texture(animation_tex, texture_coords).xyz;
	return vertex_position.xyz * max_mesh_size - vertex_offset;
}