shader_type spatial;

render_mode cull_disabled, world_vertex_coords;

#include "res://shared/shaders/wind_displacement.gdshaderinc"
#include "res://shared/shaders/triplanar_sampling.gdshaderinc"
#include "res://shared/shaders/utils.gdshaderinc"
#include "res://shared/shaders/dither.gdshaderinc"


uniform sampler2D noise;
uniform sampler2D albedo_texture;
uniform float scale = 1.0;
uniform float normalScale = 1.0;
uniform vec3 color : source_color;

varying vec3 global_position;
varying float grass_displacement;

global uniform vec3 player_position;


void vertex() {
	global_position = VERTEX;
	//grass_displacement = 1.0 - sampleGrassDisplacement(VERTEX).rgb;
	grass_displacement = 1.0 - clamp(1.0 - 0.2 * distance(global_position, player_position), 0.0, 1.0);
	
	float height_multiplier = 0.5 * grass_displacement;
	VERTEX += get_wind_displacement(VERTEX, 0.3) * COLOR.r * COLOR.r * COLOR.r * height_multiplier;

	vec4 local = inverse(MODEL_MATRIX) * vec4(VERTEX, 1.0);
	local.y *= height_multiplier;
	VERTEX = (MODEL_MATRIX * local).xyz;
	global_position = VERTEX;
}

void fragment() {
	//if(dither(SCREEN_UV * VIEWPORT_SIZE,
		//smoothstep(64, 80, distance(global_position, CAMERA_POSITION_WORLD))
		//))
		//discard;

	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;

	//vec3 sampled_noise = sampleFractalYPlanar(noise, global_position, scale, CAMERA_POSITION_WORLD, vec3(0.0)).rgb;
	vec3 sampled_noise = sample_y_planar(noise, global_position, scale).rgb;
	vec3 grass_color = color;

	vec3 col = mix(grass_color, color.rgb, min(1.0, COLOR.r * 1.5));
	ALBEDO = noiseColorTransformer(col, sampled_noise) * texture(albedo_texture, UV).rgb;
	SPECULAR = 0.8;
	ROUGHNESS = 0.9;
}