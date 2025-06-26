#ifndef SHADER_UTILS
#define SHADER_UTILS

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


#endif