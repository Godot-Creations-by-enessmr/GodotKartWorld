#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(r32f, set = 0, binding = 0) uniform restrict readonly image2D current_image;
layout(r32f, set = 1, binding = 0) uniform restrict readonly image2D previous_image;
layout(r32f, set = 2, binding = 0) uniform restrict writeonly image2D output_image;

layout(push_constant, std430) uniform Params {
	vec4 add_wave_point;
	vec2 texture_resolution;
	vec2 current_offset;
	vec2 previous_offset;
	vec2 output_offset;
	float damp;
	float c2;
	float padding[2];
} params;

float sample_previous_texture(ivec2 uv) {
	if(uv.x < 0 || uv.y < 0 || uv.x >= params.texture_resolution.x || uv.y >= params.texture_resolution.y) {
		return 0.0;
	}
	return imageLoad(previous_image, uv).r;
}

float sample_current_texture(ivec2 uv) {
	if(uv.x < 0 || uv.y < 0 || uv.x >= params.texture_resolution.x || uv.y >= params.texture_resolution.y) {
		return 0.0;
	}
	return imageLoad(current_image, uv).r;
}

void main() {
	ivec2 size = ivec2(params.texture_resolution.x - 1, params.texture_resolution.y - 1);

	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

	if ((uv.x > size.x) || (uv.y > size.y)) {
		return;
	}

	ivec2 d_1 = ivec2(params.output_offset - params.current_offset);
	ivec2 d_2 = ivec2(params.output_offset - params.previous_offset);

	float current_v = sample_current_texture(uv + d_1);
	float up_v = sample_current_texture(uv + d_1 - ivec2(0, 1));
	float down_v = sample_current_texture(uv + d_1 + ivec2(0, 1));
	float left_v = sample_current_texture(uv + d_1 - ivec2(1, 0));
	float right_v = sample_current_texture(uv + d_1 + ivec2(1, 0));
	float previous_v = sample_previous_texture(uv + d_2);

	float c2 = params.c2;
	float lap = up_v + down_v + left_v + right_v - 4.0*current_v;
	float new_v = 2.0*current_v - previous_v + c2 * lap;
	new_v = new_v - (params.damp * new_v * 0.001);

	vec2 center = params.add_wave_point.xy;
	float radius = params.add_wave_point.w;
	float dist   = length( (vec2(uv) - center) );
	if (dist < radius) {
		float falloff = 1.0 - (dist / radius);
		new_v = max(new_v, params.add_wave_point.z * falloff);
	}
	
	vec4 result = vec4(max(new_v, 0.0));
	imageStore(output_image, uv, result);
}
