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


uniform sampler2D noise;
uniform sampler2D leaves_texture : repeat_disable;
uniform sampler2D bark_texture ;
uniform sampler2D bark_texture_normal ;

uniform float wind_affect = 0.5;


float cheapHash(vec3 pos) {
	return sin(dot(pos, vec3(34,54,27)) + TIME * 1.0f);
}


void vertex() {
#if  IsDynamic
	camera_distance = distance(VERTEX, CAMERA_POSITION_WORLD);
	hash = cheapHash(VERTEX);
	vec3 LOCAL_POSITION = (VERTEX - NODE_POSITION_WORLD) * 0.1;
	VERTEX += get_wind_displacement(VERTEX, wind_affect) * LOCAL_POSITION.y * LOCAL_POSITION.y;
	id = sin(1.1123 * dot(NODE_POSITION_WORLD, vec3(43,54,12)));
#endif

	global_position = VERTEX;
	global_normal = VERTEX;
}

void fragment() {
	if(COLOR.r < 0.5 && (!FRONT_FACING)) discard;


	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	vec3 color = vec3(1.0,1.0,1.0);
	vec3 noise_sample = vec3(1.0,1.0,1.0);

	if(COLOR.r > 0.5) {
		vec4 leaf = texture(leaves_texture, UV + vec2(hash) * 0.015f);
		if(leaf.w < 0.5) discard;
		color = leaf.rgb;
	} else {
		color = texture(bark_texture, UV * 4.0).rgb;
		NORMAL_MAP = texture(bark_texture_normal, UV * 4.0).rgb;
	}

	ALBEDO = color;
}