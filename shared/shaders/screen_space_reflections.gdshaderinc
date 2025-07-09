#ifndef SHADER_SSR
#define SHADER_SSH


float schlickfresnel(float ior1, float ior2, vec3 view, vec3 norm) {
	float incident = dot(view, norm);
	float reflectance = pow(((ior2 - ior1)/(ior2 + ior1)), 2.0);
	float fresnelincident = reflectance + (1.0 - reflectance) * pow(1.0 - cos(incident), 5.0);
	return(fresnelincident / incident);
}


float linear_depth(float nonlinear_depth, mat4 inv_projection_matrix) {
	return 1.0 / (nonlinear_depth * inv_projection_matrix[2].w + inv_projection_matrix[3].w);
}

vec2 view2uv(vec3 position_view_space, mat4 proj_m)
{
	vec4 position_clip_space = proj_m * vec4(position_view_space.xyz, 1.0);
	vec2 position_ndc = position_clip_space.xy / position_clip_space.w;
	return position_ndc.xy * 0.5 + 0.5;
}

float remap1(float x, float min1, float max1) {
	return (x - min1) / (max1 - min1);
}

float edge_fade(vec2 uv, float size) {
	float x1 = clamp(remap1(uv.x, 0.0, size), 0.0, 1.0);
	float x2 = clamp(remap1(uv.x, 1.0, 1.0 - size), 0.0, 1.0);
	float y1 = clamp(remap1(uv.y, 0.0, size), 0.0, 1.0);
	float y2 = clamp(remap1(uv.y, 1.0, 1.0 - size), 0.0, 1.0);
	return x1*x2*y1*y2;
}

vec4 get_screen_space_reflection(float far_clip, int steps, float ssr_screen_fade, vec3 view, vec3 normal, vec3 pos, mat4 projection_matrix, mat4 inv_projection_matrix, sampler2D depth_texture, sampler2D screen_texture) {	
	vec3 reflected = -reflect(view, normal);
	int curstep = 0;
	vec2 uv;
	float currentdepth;
	while (curstep < steps) {
		float step_scale = float(curstep + 1) / float(steps);
		float step_dist = step_scale * step_scale * far_clip;
		pos += reflected * step_dist;
		curstep += 1;
		currentdepth = -pos.z;
		uv = view2uv(pos, projection_matrix);
		if (!(uv.x < 1.0 && uv.y < 1.0 && uv.x > 0.0 && uv.y > 0.0)) {
			return vec4(0.0);
		}
		float testdepth = linear_depth(texture(depth_texture, uv).r, inv_projection_matrix);
		if (testdepth < currentdepth && currentdepth < far_clip * 0.99) {
			vec3 reflection_color = texture(screen_texture, uv).xyz;//  * schlickfresnel(1.0, 1.33, view, normal);
			return vec4(reflection_color, edge_fade(uv, ssr_screen_fade));
		}
	}
		
	return vec4(0.0);
}

//void fragment() {
		//float far_clip = 256.0;
		//int steps = 16;
		//float ssr_screen_fade = 0.05;
		//vec4 SSR = get_screen_space_reflection(far_clip, steps, ssr_screen_fade, VIEW, NORMAL, VERTEX, PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
		//ALBEDO = vec3(1.0);
		////schlickfresnel(1.0, 1.33, VIEW, NORMAL);
		//ALBEDO = mix(ALBEDO, SSR.rgb , SSR.w);// 1.0 - SSR.w + SSR.rgb *  SSR.w;
//}

#endif