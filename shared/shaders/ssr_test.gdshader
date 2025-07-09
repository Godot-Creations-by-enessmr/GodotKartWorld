shader_type spatial;
render_mode world_vertex_coords;

#include "screen_space_reflections.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap, repeat_disable;

void fragment() {
		float far_clip = 256.0;
		int steps = 16;
		float ssr_screen_fade = 0.05;
		vec4 SSR = get_screen_space_reflection(far_clip, steps, ssr_screen_fade, VIEW, NORMAL, VERTEX, PROJECTION_MATRIX, INV_PROJECTION_MATRIX, DEPTH_TEXTURE, screen);
		ALBEDO = vec3(1.0);
		//schlickfresnel(1.0, 1.33, VIEW, NORMAL);
		ALBEDO = mix(ALBEDO, SSR.rgb , SSR.w);// 1.0 - SSR.w + SSR.rgb *  SSR.w;
}
