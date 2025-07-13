#ifndef WATER_TEXTURES
#define WATER_TEXTURES

group_uniforms WaterTextures;

//ripples
uniform sampler2D ripples_texture;
uniform vec2 ripples_texture_resolution = vec2(512, 512);
uniform vec2 ripples_texture_size = vec2(32, 32);
uniform vec2 ripples_texture_offset = vec2(0, 0);

//waves
uniform sampler2D waves_texture ;
uniform vec2 waves_texture_resulution = vec2(512, 512);
uniform vec2 waves_texture_size = vec2(512, 512);
uniform vec2 waves_texture_offset = vec2(0, 0);

//island
uniform sampler2D island_texture : hint_default_white, repeat_disable;
uniform vec2 island_texture_size = vec2(960, 960);

uniform sampler2D foam_mask_texture;
uniform vec2 foam_mask_texture_resulution = vec2(512, 512);
uniform vec2 foam_mask_texture_size = vec2(512, 512);
uniform vec2 foam_mask_texture_offset = vec2(0, 0);

group_uniforms;


float sample_water_ripples(vec3 global_pos) {
	vec2 uv = (global_pos.xz - ripples_texture_offset) / ripples_texture_size + 0.5;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x >= 1.0 || uv.y >= 1.0)
		return 0.0;
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
	vec2 uv = (global_pos.xz - waves_texture_offset) / waves_texture_size + 0.5;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x >= 1.0 || uv.y >= 1.0)
		return 0.0;
	return texture(waves_texture, uv).r;
}

float get_island_height_multiplier(vec3 global_pos) {
	vec2 uv = global_pos.xz / island_texture_size;
	return texture(island_texture, uv + 0.5).r;
}

float sample_foam_mask(vec3 global_pos) {
	vec2 uv = (global_pos.xz - foam_mask_texture_offset) / foam_mask_texture_size + 0.5;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x >= 1.0 || uv.y >= 1.0)
		return 0.0;
	return texture(foam_mask_texture, uv).r;
}



#endif