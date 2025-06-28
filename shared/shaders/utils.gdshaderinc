#ifndef SHADER_UTILS
#define SHADER_UTILS

// -------------------------------- NORMALS --------------------------------
vec3 unpack_normal(vec3 n) {
    return normalize(n * 2.0 - 1.0);
}

vec3 blend_normals(vec3 n1, vec3 n2) {
    n1 = unpack_normal(n1);
    n2 = unpack_normal(n2);

    vec3 t = normalize(vec3(n1.xy + n2.xy, n1.z * n2.z));
    return normalize(t) * 0.5 + 0.5; // pack back to [0,1]
}

vec3 scale_normal_strength(vec3 normal, float strength) {
    // Unpack from [0,1] to [-1,1]
    vec3 unpacked = normal * 2.0 - 1.0;

    // Scale the X and Y components (perturbation)
    unpacked.xy *= strength;

    // Re-normalize to ensure it's still a unit vector
    unpacked = normalize(unpacked);

    // Re-pack to [0,1]
    return unpacked * 0.5 + 0.5;
}

// -------------------------------- COLORS --------------------------------

vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

#endif