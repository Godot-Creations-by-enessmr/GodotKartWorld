shader_type spatial;

//render_mode world_vertex_coords;

#include "utils.gdshaderinc"
#include "triplanar_sampling.gdshaderinc"

uniform float specular : hint_range(0, 1) = 0.5f;
uniform float roughness : hint_range(0, 1) = 0.5f;
uniform float metalic : hint_range(0, 1) = 0.0f;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec2 uv_tiling = vec2(1.0);
uniform sampler2D albedo_texture;

uniform sampler2D noise;
uniform float noiseScale = 0.25;
uniform float normalScale = 0.15;

uniform bool use_global_position = true;

varying vec3 global_position;

void vertex() {
	global_position = VERTEX;
	if(use_global_position) {
		vec4 pos_h = (MODEL_MATRIX * vec4(global_position, 1.0));
		global_position = pos_h.xyz / pos_h.w;
	}
}

void fragment() {
	vec3 global_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);

	SPECULAR = specular;
	ROUGHNESS = roughness;
	METALLIC = metalic;
	vec3 sampled_noise = sampleTriplanar(noise, global_position, global_normal, noiseScale).rgb;

	global_normal = noiseNormalTransformer(global_normal, sampled_noise, normalScale);
	ALBEDO = noiseColorTransformer(albedo.rgb * texture(albedo_texture, UV * uv_tiling).rgb, sampled_noise);
	NORMAL = normalize((VIEW_MATRIX * vec4(global_normal, 0.0)).xyz);
}