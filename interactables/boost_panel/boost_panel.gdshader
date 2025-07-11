shader_type spatial;

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
varying float flip; // you cannot use boolean varyings from vertex to fragment.
varying vec2 uv_scalar;

void vertex() {	
	mat4 model = transpose(inverse(MODELVIEW_MATRIX));
	
	TBN = mat3(
		-(model * vec4(TANGENT, 0.0)).xyz,
		(model * vec4(BINORMAL, 0.0)).xyz,
		(model * vec4(NORMAL, 0.0)).xyz
	);	
	
	float scaleX = length(vec3(MODEL_MATRIX[0].x, MODEL_MATRIX[1].x, MODEL_MATRIX[2].x));
	uv_scalar = vec2(scaleX, 1.0);
	
	vec4 cam_pos_h = inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0);
	
	flip = cam_pos_h.z / cam_pos_h.w > 0.0 ? 0.0 : 1.0;
}

vec2 parallax_uv(vec2 uv, vec3 view_dir, float depth_offset) {
	vec2 vec_p = view_dir.xy / view_dir.z * depth_offset;	
	return uv + vec_p;
}

varying vec3 view_dir; 
void fragment() {
	
	vec2 uv = uv_scalar * mix(UV, vec2(1.0 - UV.x, 1.0 - UV.y), flip);
	float mult = flip > 0.5 ? -1.0 : 1.0; 
	
	view_dir = normalize(normalize(-VERTEX) * TBN);
	
	vec2 uv1 = parallax_uv(0.5*(pattern_uv_scale*uv + 0.2 * TIME), view_dir, mult * 0.025);
    float p1 = texture(pattern_texture, uv1).r;
	
	vec2 uv2 = parallax_uv(pattern_uv_scale * uv + 0.05 * TIME, view_dir, mult * 0.05);
    float p2 = texture(pattern_texture, uv2).r;
	
	vec2 uv3 = parallax_uv(pattern_uv_scale*0.5*uv - 0.02*TIME, view_dir, mult * 0.075);
    float p3 = texture(pattern_texture, uv3).r;
    float pat = mix(mix(p1,p2,0.5), p3, 0.5);
    vec3 base_col = mix(top_color, bottom_color, uv.y) * pat;

    vec2 arrow_uv = uv * arrow_uv_scale
                  + vec2(0.0, arrow_scroll_speed * TIME);
	
    arrow_uv = parallax_uv(arrow_uv, view_dir, mult * 0.03);
    vec2 ghost_uv = parallax_uv(arrow_uv, view_dir, mult * 0.06);

    float a_ghost = texture(arrow_texture, ghost_uv).r;
    float a_main  = texture(arrow_texture, arrow_uv).r;
    vec3 col = mix(base_col, arrow_color, min((a_main + 0.1 * a_ghost), 0.3));

    ALBEDO = col;
    EMISSION = col * brightness;
}
