shader_type spatial;
render_mode cull_front, world_vertex_coords;

#include "res://shared/shaders/utils.gdshaderinc"

uniform float emmision_multiplier = 2.0;
uniform float pattern_scale = 0.2;
instance uniform vec3 box_color : source_color = vec3(1);
uniform sampler2D pattern_texture;

varying float distance_to_camera;
varying vec2 node_position_uv;

void vertex() {

    vec4 ndc = PROJECTION_MATRIX * vec4(NODE_POSITION_VIEW, 1.0);
    node_position_uv = ndc.xy / ndc.w; // Now in range [-1, 1]);
	distance_to_camera = distance(CAMERA_POSITION_WORLD, NODE_POSITION_WORLD);
}

void fragment() {
    // Convert SCREEN_UV from [0,1] to [-1,1]
    vec2 screen_uv = SCREEN_UV * 2.0 - 1.0;

    float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
    screen_uv.x *= aspect;
    vec2 node_uv = node_position_uv * vec2(aspect, 1.0);

    vec2 centered_uv = screen_uv - node_uv;

    vec2 uv = centered_uv * distance_to_camera * pattern_scale;

    // Sample pattern
    float pattern1 = texture(pattern_texture, 0.5 * (uv + 0.2 * TIME)).r;
    float pattern2 = texture(pattern_texture, uv + 0.05 * TIME).r;
    float pattern = mix(pattern1, pattern2, 0.5);

    ALBEDO = vec3(0);
	vec3 hsv_color = rgb2hsv(box_color);
	vec3 rgb_color = hsv2rgb(hsv_color + vec3(0.25 * (1.0 - pattern), 0, 0)); // + vec3(0.25 * (1.0 - pattern), 0, 0)

    EMISSION = rgb_color * pattern * emmision_multiplier;
}
