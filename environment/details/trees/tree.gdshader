shader_type spatial;

render_mode cull_disabled, world_vertex_coords;

//Set to false to disable dynamic features, good for imposter rendering
#define IsDynamic true

#include "res://shared/shaders/wind_displacement.gdshaderinc"
#include "res://shared/shaders/utils.gdshaderinc"
#include "res://shared/shaders/triplanar_sampling.gdshaderinc"

varying vec3 global_position;
varying vec3 global_normal;
varying float camera_distance;
varying float hash;
varying float id;


uniform vec4 leaves_color1 : source_color;
uniform vec4 leaves_color2 : source_color;
uniform vec4 leaves_highlight : source_color;
uniform vec4 trunk_color : source_color;
uniform float leaves_highlight_strength : hint_range(0.0, 1.0, 0.1);
uniform float black_spots_strength : hint_range(0.0, 1.0, 0.1);
uniform float ground_factor : hint_range(1.0, 50.0, 0.1) = 20.0;

uniform sampler2D noise;
uniform sampler2D leaves_mask : repeat_disable;

uniform float wind_affect = 0.5;


float cheapHash(vec3 pos) {
	return sin(dot(pos, vec3(34,54,27)) + TIME * 1.0f);
}


void vertex() {
#if  IsDynamic
	camera_distance = distance(VERTEX, CAMERA_POSITION_WORLD);
	hash = cheapHash(VERTEX);
	//VERTEX += get_wind_displacement(VERTEX, wind_affect + 5.0 * dissolve) * COLOR.g * COLOR.g;
	id = sin(1.1123 * dot(NODE_POSITION_WORLD, vec3(43,54,12)));
#endif

	global_position = VERTEX;
	global_normal = VERTEX;
}

void fragment() {
	if(COLOR.r < 0.5 && (!FRONT_FACING)) discard;

	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	vec3 mask_color = vec3(1.0,1.0,1.0);
	vec3 noise_sample = vec3(1.0,1.0,1.0);
	vec3 ground_color = trunk_color.rgb;
	//if(camera_distance < 256.0) {
		mask_color = COLOR.r > 0.5 ? texture(leaves_mask, UV + vec2(hash) * 0.015f).rgb : vec3(1.0,1.0,1.0);

		noise_sample = texture(noise, UV).rgb;
	//}

	vec3 color = (COLOR.r > 0.5)
		?	mix(mix(leaves_color1.rgb, leaves_color2.rgb, id), leaves_highlight.rgb,
			min(mask_color.g, leaves_highlight_strength))
		: trunk_color.rgb;

	float blackSpots = 1.0 - black_spots_strength * (1.0 - COLOR.r) * (1.0 - smoothstep(0.1, 0.2, noise_sample.r));
	vec3 transformed_color = noiseColorTransformer(color, noise_sample) * blackSpots;


	ALBEDO = mix(transformed_color, ground_color, max(0.0, 1.0-ground_factor*COLOR.g));
}