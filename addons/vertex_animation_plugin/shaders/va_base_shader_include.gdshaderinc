uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);

uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_strength : hint_range(-10.0, 10.0) = 1.0;

uniform sampler2D texture_roughness : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float roughness_strength : hint_range(0.0, 1.0) = 1.0; 
uniform vec4 roughness_channel = vec4(0.0, 1.0, 0.0, 0.0);

uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float metallic_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 metallic_channel = vec4(0.0, 0.0, 1.0, 0.0);

uniform sampler2D texture_ambient_occlusion : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 ambient_occlusion_channel = vec4(1.0, 0.0, 0.0, 0.0);

uniform sampler2D texture_emission : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec4 emission_color : source_color;
uniform float emission_strength : hint_range(0.0, 100.0) = 1.0;

uniform float specular_strength : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	ALBEDO = albedo_color.rgb * texture(texture_albedo, UV).rgb;
	
	NORMAL_MAP = texture(texture_normal, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	
	float roughness_tex = dot(texture(texture_roughness, UV), roughness_channel);
	ROUGHNESS = roughness_tex * roughness_strength;
	
	float metallic_tex = dot(texture(texture_metallic, UV), metallic_channel);
	METALLIC = metallic_tex * metallic_strength;
	
	AO = dot(texture(texture_ambient_occlusion, UV), ambient_occlusion_channel);
	
	EMISSION = (emission_color.rgb * texture(texture_emission, UV).rgb) * emission_strength;
	
	SPECULAR = specular_strength;
}