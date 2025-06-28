shader_type spatial;

render_mode particle_trails, cull_disabled;

uniform sampler2D noise;
uniform float emission_strength;
uniform vec4 color : source_color;

varying float lifetime;

void vertex(){
	lifetime = INSTANCE_CUSTOM.y;
}

void fragment() {
	float edge = 1.0 - abs(1.0 - 2.0 * UV.x) - lifetime * 0.5;

	float d = texture(noise, UV + vec2(0.0, -TIME)).r + edge;
	if(floor(d) < 0.2) discard;

	EMISSION = color.rgb * emission_strength;
}

void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
}
