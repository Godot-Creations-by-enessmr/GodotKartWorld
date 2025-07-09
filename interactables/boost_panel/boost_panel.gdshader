shader_type spatial;
//render_mode world_vertex_coords;

uniform sampler2D arrow_texture;
uniform vec2       arrow_uv_scale   = vec2(5.0, 1.0);
uniform float      arrow_scroll_speed = 1.0;

uniform sampler2D  pattern_texture;
uniform vec2       pattern_uv_scale = vec2(2.5, 0.5);
uniform vec3       bottom_color     : source_color;
uniform vec3       top_color        : source_color;
uniform vec3       arrow_color      : source_color;
uniform float      brightness       = 5.0;

varying mat3 TBN;

void vertex() {	
	mat4 model = transpose(inverse(MODELVIEW_MATRIX));
	
	TBN = mat3(
		-(model * vec4(TANGENT, 0.0)).xyz,
		(model * vec4(BINORMAL, 0.0)).xyz,
		(model * vec4(NORMAL, 0.0)).xyz
	);	
}

vec2 parallax_uv(vec2 uv, vec3 view_dir, float depth_offset) {
	vec2 vec_p = view_dir.xy / view_dir.z * depth_offset;	
	return uv + vec_p;
}

varying vec3 view_dir; 
void fragment() {
	view_dir = normalize(normalize(-VERTEX) * TBN);
	
	vec2 uv1 = parallax_uv(0.5*(pattern_uv_scale*UV + 0.2 * TIME), view_dir, 0.025);
    float p1 = texture(pattern_texture, uv1).r;
	
	vec2 uv2 = parallax_uv(pattern_uv_scale * UV + 0.05 * TIME, view_dir, 0.05);
    float p2 = texture(pattern_texture, uv2).r;
	
	vec2 uv3 = parallax_uv(pattern_uv_scale*0.5*UV - 0.02*TIME, view_dir, 0.075);
    float p3 = texture(pattern_texture, uv3).r;
    float pat = mix(mix(p1,p2,0.5), p3, 0.5);
    vec3 base_col = mix(top_color, bottom_color, UV.y) * pat;

    vec2 arrow_uv = UV * arrow_uv_scale
                  + vec2(0.0, arrow_scroll_speed * TIME);
	
    arrow_uv = parallax_uv(arrow_uv, view_dir, 0.03);
    vec2 ghost_uv = parallax_uv(arrow_uv, view_dir, 0.06);

    float a_ghost = texture(arrow_texture, ghost_uv).r;
    float a_main  = texture(arrow_texture, arrow_uv).r;
    vec3 col = mix(base_col, arrow_color, min((a_main + 0.1 * a_ghost), 0.3));

    ALBEDO = col;
    EMISSION = col * brightness;
}
