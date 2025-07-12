#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(r32f, set = 0, binding = 0) uniform restrict readonly image2D current_image;
layout(r32f, set = 1, binding = 0) uniform restrict writeonly image2D output_image;

layout(push_constant, std430) uniform Params {
	vec4 add_tire_point[4];
	vec2 texture_resolution;
	vec2 current_offset;
	vec2 output_offset;
	vec2 padding;
} params;

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
    float current_v = sample_current_texture(uv + d_1);
    float new_v = current_v;

    for (int i = 0; i < 4; ++i) {
        vec2 center = params.add_tire_point[i].xy;
        float radius = params.add_tire_point[i].w;
        float dist = length(vec2(uv) - center);
        if (dist < radius) {
            float falloff = 1.0 - (dist / radius);
            float tire_v = params.add_tire_point[i].z * falloff;
            new_v = max(new_v, tire_v);
        }
    }

	vec4 result = vec4(max(new_v, 0.0));
	imageStore(output_image, uv, result);
}
