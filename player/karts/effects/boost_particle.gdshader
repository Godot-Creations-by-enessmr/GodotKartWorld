shader_type spatial;

render_mode ambient_light_disabled;

uniform sampler2D alpha_texture: repeat_disable;
uniform float lifetime = 0.2;
uniform float emission_strength;
uniform vec3 start_color : source_color;
uniform vec3 end_color : source_color;

varying float current_lifetime;
varying float ID;

#include "res://shared/shaders/billboard.gdshaderinc"

float cheapHash(float f) {
	return fract(sin(f * 54432.4325) * 4732.0543);
}

vec2 rotateUV(vec2 uv, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	mat2 mat = mat2(vec2(c, -s), vec2(s, c));
	return mat * (uv - 0.5) + vec2(0.5);
}

void vertex() {
	MODELVIEW_MATRIX = get_billboard_MODELVIEW(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX);
	current_lifetime = INSTANCE_CUSTOM.y / lifetime;
	ID = cheapHash(INSTANCE_CUSTOM.x);
}

void fragment() {
	ALPHA = texture(alpha_texture, rotateUV(UV, ID * 2.0 * PI)).a;
	EMISSION = mix(start_color, end_color, current_lifetime) * emission_strength;
}
