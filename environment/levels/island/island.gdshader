shader_type spatial;
render_mode world_vertex_coords;

#include "res://shared/shaders/triplanar_sampling.gdshaderinc"
#include "res://shared/shaders/utils.gdshaderinc"


uniform vec4 sand_color : source_color;
uniform vec4 rock_color : source_color;
uniform vec4 grass_color : source_color;
uniform vec4 dirt_color : source_color;

//varying vec3 global_normal;
varying vec3 global_position;

uniform float detail_noise_scale = 0.002;
uniform sampler2D detail_noise;
uniform sampler2D terrain_material_map;

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

	if (dot(WORLD_UP, global_normal)  > 0.85f) {
		SPECULAR = 0.8;
		ROUGHNESS = 0.9;

		if(terrain.x > 0.1) {
			color = dirt_color.rgb;
		} else if(terrain.y > 0.1) {
			color = sand_color.rgb;
			SPECULAR = 0.4;
			ROUGHNESS = 0.3;
		} else {
			color = grass_color.rgb;
		}


	}

	//vec4 sampleTriplanar(sampler2D f_sampler, vec3 f_global_position, vec3 f_global_normal, float f_scale) {

	vec3 sampled_noise = sampleTriplanar(detail_noise, global_position, global_normal, detail_noise_scale).rgb;
	ALBEDO = noiseColorTransformer(color, sampled_noise);

	global_normal = noiseNormalTransformer(global_normal, sampled_noise, 1.0);
	NORMAL = normalize((VIEW_MATRIX * vec4(global_normal, 0.0)).xyz);
}