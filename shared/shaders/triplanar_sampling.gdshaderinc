vec2 rotateUV(vec2 f_uv, float f_rotation_radians) {
	float c = cos(f_rotation_radians);
	float s = sin(f_rotation_radians);
	return vec2(f_uv.x * c + f_uv.y * s, f_uv.y * c - f_uv.x * s);
}

vec4 sampleTriplanarRotated(sampler2D f_sampler, vec3 f_global_position, vec3 f_global_normal, float f_scale, float rotation) {
	return (abs(f_global_normal.x) * texture(f_sampler, rotateUV(f_global_position.yz * f_scale, rotation))
    	+ abs(f_global_normal.y) * texture(f_sampler, rotateUV(f_global_position.xz * f_scale, rotation))
    	+ abs(f_global_normal.z) * texture(f_sampler, rotateUV(f_global_position.xy * f_scale, rotation)))
		/ (abs(f_global_normal.x) + abs(f_global_normal.y) + abs(f_global_normal.z));
}

vec4 sampleTriplanar(sampler2D f_sampler, vec3 f_global_position, vec3 f_global_normal, float f_scale) {
	return sampleTriplanarRotated(f_sampler, f_global_position, f_global_normal, f_scale, 0.0);
}

vec4 sample_y_planar(sampler2D f_sampler, vec3 f_global_position, float f_scale) {
    return texture(f_sampler, f_global_position.xz * f_scale);
}