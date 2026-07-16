shader_type spatial;

// Star Power Shader - creates a scrolling rainbow gradient effect
group_uniforms Star_Power;
uniform bool star_active = false;
uniform float gradient_offset : hint_range(0, 1) = 0.0;
uniform float gradient_speed : hint_range(0, 5) = 2.0;
uniform vec3 color1 : source_color = vec3(1.0, 0.0, 0.0);
uniform vec3 color2 : source_color = vec3(1.0, 0.5, 0.0);
uniform vec3 color3 : source_color = vec3(1.0, 1.0, 0.0);
uniform vec3 color4 : source_color = vec3(0.0, 1.0, 0.0);
uniform vec3 color5 : source_color = vec3(0.0, 0.0, 1.0);
uniform vec3 color6 : source_color = vec3(0.5, 0.0, 1.0);

// Original material properties (copied from the original material)
uniform vec3 albedo : source_color = vec3(0.8, 0.8, 0.8);
uniform float roughness : hint_range(0, 1) = 0.5;
uniform float metallic : hint_range(0, 1) = 0.0;

void fragment() {
	vec3 final_color = albedo;
	
	if (star_active) {
		// Create a scrolling gradient based on UV and world position
		float grad_pos = UV.x + gradient_offset;
		
		// Use UV.x for horizontal gradient, add some vertical variation
		float noise = sin(UV.y * 10.0 + gradient_offset * 3.0) * 0.2 + 0.8;
		grad_pos = fract(grad_pos + UV.y * 0.3);
		
		// Define color stops
		vec3 colors[6];
		colors[0] = color1;
		colors[1] = color2;
		colors[2] = color3;
		colors[3] = color4;
		colors[4] = color5;
		colors[5] = color6;
		
		// Find which two colors to blend between
		float pos = grad_pos * 6.0;
		int index = int(floor(pos));
		float blend = fract(pos);
		
		// Wrap around
		if (index >= 6) {
			index = 5;
			blend = 1.0;
		}
		
		vec3 color_a = colors[index];
		vec3 color_b = colors[(index + 1) % 6];
		
		// Blend between colors
		vec3 gradient_color = mix(color_a, color_b, blend);
		
		// Add some sparkle effect
		float sparkle = pow(max(sin(UV.x * 100.0 + UV.y * 50.0 + gradient_offset * 20.0), 0.0), 8.0);
		gradient_color += vec3(sparkle * 0.5);
		
		// Apply gradient with some metallic/roughness preservation
		final_color = mix(albedo, gradient_color, 0.7);
		
		// Keep some base color for depth
		final_color = mix(final_color, gradient_color, 0.9);
		
		// Boost brightness for star power effect
		final_color *= 1.2;
	}
	
	// Standard lighting
	ALBEDO = final_color;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	
	// Add subtle emission for star power
	if (star_active) {
		EMISSION = final_color * 0.3;
	}
}