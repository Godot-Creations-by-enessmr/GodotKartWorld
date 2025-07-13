shader_type spatial;
render_mode world_vertex_coords;

#include "res://shared/shaders/triplanar_sampling.gdshaderinc"
#include "res://shared/shaders/utils.gdshaderinc"


uniform vec4 sand_color : source_color;
uniform vec4 wheel_sand_color : source_color;
uniform vec4 rock_color : source_color;
uniform vec4 grass_color : source_color;
uniform vec4 dirt_color : source_color;

//varying vec3 global_normal;
varying vec3 global_position;

uniform float detail_noise_scale = 0.002;
uniform float detail_noise_normal_strength = 0.5;
uniform sampler2D detail_noise;
uniform sampler2D terrain_material_map;

group_uniforms Internal;

uniform sampler2D tire_marks_texture;
uniform vec2 tire_marks_texture_resulution = vec2(512, 512);
uniform vec2 tire_marks_texture_size = vec2(512, 512);
uniform vec2 tire_marks_texture_offset = vec2(0, 0);

group_uniforms;

float sample_water_tire_marks(vec3 global_pos) {
	vec2 coord = global_pos.xz - tire_marks_texture_offset + 0.5 * tire_marks_texture_size;
	if (coord.x < 0.0 || coord.y < 0.0 || coord.x >= tire_marks_texture_size.x || coord.y >= tire_marks_texture_size.y)
		return 0.0;
	vec2 uv = coord / tire_marks_texture_size;
	return texture(tire_marks_texture, uv).r;
}

vec3 compute_tire_marks_normal(vec3 global_pos) {
	vec2 h = tire_marks_texture_size / tire_marks_texture_resulution;
	float f1 = -sample_water_tire_marks(global_pos);
	float f2 = -sample_water_tire_marks(global_pos + vec3(h.x, 0, 0));
	float f3 = -sample_water_tire_marks(global_pos + vec3(0, 0, h.y));

	vec3 tangent = normalize(vec3(1.0, 0.0, f2 - f1));
	vec3 binormal = normalize(vec3(0.0, 1.0, f3 - f1));
	return normalize(cross(binormal, tangent)) * 0.5 + 0.5;
}


void vertex() {
	global_position = VERTEX;
}

void fragment() {
	vec3 global_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 WORLD_UP = vec3(0,1,0);
	float WORLD_HEIGHT  = global_position.y;

	SPECULAR = 0.5;
	ROUGHNESS = 0.5;

	vec3 color = rock_color.rgb;

	vec4 terrain = texture(terrain_material_map, UV);


	vec3 tire_mark_normal = scale_normal_strength(compute_tire_marks_normal(global_position), 0.5);
	float tire_mark_strength = sample_water_tire_marks(global_position);

	if (dot(WORLD_UP, global_normal)  > 0.85f) {
		SPECULAR = 0.8;
		ROUGHNESS = 0.9;

		if(terrain.x > 0.5) {
			color = dirt_color.rgb;
		} else if(terrain.y > 0.5) {
			color = sand_color.rgb;
			SPECULAR = 0.7;
			ROUGHNESS = 0.7;

			NORMAL_MAP = tire_mark_normal;
			color = mix(color, wheel_sand_color.rgb, tire_mark_strength);

		} else {
			color = grass_color.rgb;
			NORMAL_MAP = tire_mark_normal;
			color = mix(color, dirt_color.rgb, clamp(tire_mark_strength, 0.0, 0.5));
		}
	}

	//vec4 sampleTriplanar(sampler2D f_sampler, vec3 f_global_position, vec3 f_global_normal, float f_scale) {

	vec3 sampled_noise = sampleTriplanar(detail_noise, global_position, global_normal, detail_noise_scale).rgb;
	ALBEDO = noiseColorTransformer(color, sampled_noise);
	//ALBEDO = terrain.rgb;

	global_normal = noiseNormalTransformer(global_normal, sampled_noise, detail_noise_normal_strength);
	NORMAL = normalize((VIEW_MATRIX * vec4(global_normal, 0.0)).xyz);
}