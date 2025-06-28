#ifndef WATER_TEXTURES
#define WATER_TEXTURES

group_uniforms WaterTextures;

//ripples
uniform sampler2D ripples_texture;
uniform vec2 ripples_texture_resolution = vec2(512, 512);
uniform vec2 ripples_texture_size = vec2(32, 32);
uniform vec2 ripples_texture_offset = vec2(0, 0);

//waves
uniform sampler2D waves_texture;
uniform vec2 waves_texture_resulution = vec2(512, 512);
uniform vec2 waves_texture_size = vec2(512, 512);
uniform vec2 waves_texture_offset = vec2(0, 0);

group_uniforms;


float sample_water_ripples(vec3 global_pos) {
	vec2 coord = global_pos.xz - ripples_texture_offset + 0.5 * ripples_texture_size;
	if (coord.x < 0.0 || coord.y < 0.0 || coord.x >= ripples_texture_size.x || coord.y >= ripples_texture_size.y) 
		return 0.0;
	vec2 uv = coord / ripples_texture_size;
	return texture(ripples_texture, uv).r;
}

vec3 compute_ripples_normal(vec3 global_pos) {
	vec2 h = ripples_texture_size / ripples_texture_resolution;
	float f1 = sample_water_ripples(global_pos);
	float f2 = sample_water_ripples(global_pos + vec3(h.x, 0, 0));
	float f3 = sample_water_ripples(global_pos + vec3(0, 0, h.y));

	vec3 tangent = normalize(vec3(1.0, 0.0, f2 - f1));
	vec3 binormal = normalize(vec3(0.0, 1.0, f3 - f1));
	return normalize(cross(binormal, tangent)) * 0.5 + 0.5;
}

float sample_water_waves_height(vec3 global_pos) {
	vec2 coord = global_pos.xz - waves_texture_offset + 0.5 * waves_texture_size;
	if (coord.x < 0.0 || coord.y < 0.0 || coord.x >= waves_texture_size.x || coord.y >= waves_texture_size.y) 
		return 0.0;
	vec2 uv = coord / waves_texture_size;
	return texture(waves_texture, uv).r * 5.0;
}

#endif