shader_type spatial;

uniform sampler2D arrow_texture;
uniform vec2 arrow_uv_scale = vec2(5, 1.0);
uniform float arrow_scroll_speed = 1.0;

uniform sampler2D pattern_texture;
uniform vec2 pattern_uv_scale = vec2(2.5, 0.5);

uniform vec3 bottom_color : source_color;
uniform vec3 top_color : source_color;
uniform vec3 arrow_color : source_color;
uniform float brightness = 5.0;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
    float pattern1 = texture(pattern_texture, 0.5 * (pattern_uv_scale * UV + 0.2 * TIME)).r;
    float pattern2 = texture(pattern_texture, pattern_uv_scale * UV + 0.05 * TIME).r;
    float pattern3 = texture(pattern_texture, pattern_uv_scale * 0.5 * UV + -0.02 * TIME).r;
    float pattern = mix(pattern1, pattern2, 0.5);
    pattern = mix(pattern, pattern3, 0.5);
	
	vec3 color = mix(top_color, bottom_color, UV.y) * pattern; 
	
	vec2 arrow_uv = UV * arrow_uv_scale + vec2(0, arrow_scroll_speed * TIME);
	ALBEDO = mix(color, arrow_color, texture(arrow_texture, arrow_uv).r);
	
	EMISSION = ALBEDO * brightness;	
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
