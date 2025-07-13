#[compute]
#version 450

#define CASCADE_COUNT 3

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(r32f, set = 0, binding = 0) uniform restrict readonly image2D current_image;
layout(r32f, set = 1, binding = 0) uniform restrict writeonly image2D output_image;
layout(r32f, set = 2, binding = 0) uniform restrict readonly image2D ripples_image;
layout(r32f, set = 3, binding = 0) uniform restrict readonly image2D waves_image;
layout(set = 4, binding = 0) uniform sampler2D fft_cascase_0_image;
layout(set = 4, binding = 1) uniform sampler2D fft_cascase_1_image;
layout(set = 4, binding = 2) uniform sampler2D fft_cascase_2_image;

//ratios: the physical size of the textures in relation to the foam texture

layout(push_constant, std430) uniform Params {
	vec2 texture_resolution;
	vec2 texture_delta; // offset between current and output texture
	vec2 texture_size;
	vec2 global_center;

	// vec2 current_ripples_offset;
	vec2 ripples_size_ratio;
	vec2 ripples_resolution;

	// vec2 current_waves_offset;
	vec2 waves_size_ratio;
	vec2 waves_resolution;

	vec2 fft_resolution;
	vec2 wind_uv_offset;

	vec3 cascade_uv_scales;
	float fft_uv_scale;
	
} params;

// -----------------------------------------------------------------------------

vec2 global_to_uv(vec2 global_pos, float cascade_scale) {
	return global_pos * params.fft_uv_scale / cascade_scale + params.wind_uv_offset * cascade_scale;
}

vec3 get_displacement(vec2 global_pos) {
	vec3 displacement = vec3(0.0);
	displacement += texture(fft_cascase_0_image, global_to_uv(global_pos, params.cascade_uv_scales.x)).rgb;
	displacement += texture(fft_cascase_1_image, global_to_uv(global_pos, params.cascade_uv_scales.y)).rgb;
	displacement += texture(fft_cascase_2_image, global_to_uv(global_pos, params.cascade_uv_scales.z)).rgb;
	return displacement;
}

// float get_jacobian(vec2 uv) { 
// 	float offset = 0.02; 
// 	vec3 displacement = get_displacement(uv); 
// 	vec3 right = (vec3(offset, get_displacement(uv + vec2(offset, 0.0)).y, 0.0)) - displacement; 
// 	vec3 left = (vec3(-offset, get_displacement(uv + vec2(-offset, 0.0)).y, 0.0)) - displacement; 
// 	vec3 bottom = (vec3(0.0, get_displacement(uv + vec2(0.0, offset)).y, offset)) - displacement; 
// 	vec3 top = (vec3(0.0, get_displacement(uv + vec2(0.0, -offset)).y, -offset)) - displacement; 
// 	vec3 top_right = cross(right, top); vec3 top_left = cross(top, left); 
// 	vec3 bottom_left = cross(left, bottom); vec3 bottom_right = cross(bottom, right); 
// 	// vec3 normal = normalize(top_right + top_left + bottom_left + bottom_right) * normal_factor; 
// 	float jxx = right.x / offset; 
// 	float jxy = right.y / offset; 
// 	float jyx = bottom.x / offset; 
// 	float jyy = bottom.y / offset; 
// 	float jacobian_determinant = (jxx * jyy) - (jxy * jyx); 
// 	return jacobian_determinant;//vec4(normal, jacobian_determinant); 
// }

float get_jacobian(vec2 uv) {
	float offset = 1.0; 
	float dC = get_displacement(uv).y;
	float dR = get_displacement(uv + vec2(offset, 0)).y;
	float dL = get_displacement(uv - vec2(offset, 0)).y;
	float dT = get_displacement(uv + vec2(0, offset)).y;
	float dB = get_displacement(uv - vec2(0, offset)).y;

	float ddx = (dR - dL) / (2.0 * offset);
	float ddy = (dT - dB) / (2.0 * offset);

	return (1.0 + ddx) * (1.0 + ddy) - ddx * ddy;
}

// -----------------------------------------------------------------------------


bool is_valid_pixel(ivec2 pixel, vec2 resolution) {
	return pixel.x >= 0 && pixel.y >= 0 && pixel.x < resolution.x && pixel.y < resolution.y;
}

void main() {
	ivec2 size = ivec2(params.texture_resolution.x - 1, params.texture_resolution.y - 1);

	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

	if ((uv.x > size.x) || (uv.y > size.y)) {
		return;
	}
	vec2 half_res = params.texture_resolution * 0.5;
    vec4 state = vec4(0.0);
	{
		ivec2 pixel = uv + ivec2(params.texture_delta);
		state.x = is_valid_pixel(pixel, params.texture_resolution) ? imageLoad(current_image, pixel).r : 0.0;
	}
	{
		// ivec2 pixel = ivec2((vec2(uv) - half_res) * params.ripples_size_ratio + params.ripples_resolution * 0.5);
		// state.y = is_valid_pixel(pixel, params.ripples_resolution) ? imageLoad(ripples_image, pixel).r : 0.0;
		state.y = 0.0;
	}
	{
		ivec2 pixel = ivec2((vec2(uv) - half_res) * params.waves_size_ratio + params.waves_resolution * 0.5);
		state.z = is_valid_pixel(pixel, params.waves_resolution) ? imageLoad(waves_image, pixel).r : 0.0;
	}
	{
		vec2 coord = (vec2(uv) - half_res) * params.texture_size / params.texture_resolution + params.global_center;
		float jacobian_determinant = get_jacobian(coord);


		state.w = clamp(-1.5 - 8.0 * (jacobian_determinant - 1.0), 0.0, 1.0);
		// state.w = get_displacement(coord).y;
	}
	
	float decay = 0.995;
    float new_v = max(decay * state.x, state.y + state.z + state.w);

	vec4 result = vec4(clamp(new_v, 0.0, 1.0));
	imageStore(output_image, uv, result);
}
