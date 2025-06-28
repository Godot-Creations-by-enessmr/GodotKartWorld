shader_type spatial;

render_mode ambient_light_disabled;

uniform sampler2D noise;
uniform float emission_strength;
uniform float noise_scale = 1.0f;
uniform float smoke_glow_offset = 0.0f;
uniform vec4 glow_color : source_color;
uniform vec4 primary_color : source_color;

varying float lifetime;
varying float ID;

float cheapHash(float f) {
	return sin(f * 54432.4325);
}

void vertex() {
	ID = cheapHash(INSTANCE_CUSTOM.x);
	lifetime = INSTANCE_CUSTOM.y;
}

void fragment() {
	float n_s = mix(noise_scale, 1.5 * noise_scale, ID);

	float edge = texture(noise, UV * n_s).r + lifetime;
	float d = 1.0 - floor(edge);
	if(d < 0.5) discard;

	EMISSION = primary_color.rgb;

	if(1.0 - edge < 0.2 * lifetime + smoke_glow_offset)
		EMISSION = glow_color.rgb * emission_strength * (0.5 * edge + 0.5);
}

void light() {

}
