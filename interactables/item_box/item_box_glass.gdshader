shader_type spatial;

uniform vec4 color : source_color = vec4(1);
uniform float specular = 0.9;
uniform float roughness = 0.4;
uniform float metallic = 0.5;
uniform float strength = 1;
uniform float emission = 4.0;

uniform sampler2D normalmap;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment()
{
	vec2 offset = SCREEN_UV;
	float xNorm = NORMAL.x;
	float yNorm = NORMAL.y;
	offset.x += NORMAL.z * xNorm * strength * 0.01;
	offset.y += NORMAL.z * yNorm * strength * -0.01;

	ALBEDO = vec3(0);
	EMISSION = emission * ((texture(screen_texture, offset).xyz * (1.0 - color.a)) + (color.xyz * color.a)) / 2.0;

	SPECULAR = specular;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}