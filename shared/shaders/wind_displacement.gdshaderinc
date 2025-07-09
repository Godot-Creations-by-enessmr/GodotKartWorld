global uniform sampler2D wind_noise_texture;
global uniform vec3 wind_direction;
global uniform float wind_strength;

//vec3 get_wind_displacement(vec3 global_position, float strength){
	//float time_factor = 0.01;
	//float position_factor = 0.0015;
	//vec3 wind = normalize((texture(wind_noise_texture, position_factor * global_position.xz + (time_factor * TIME) * wind_direction.xz).rgb - vec3(.5)) * vec3(1, 0.2, 1));
	//float d = abs(dot(wind, wind_direction));
	//return (strength * d * wind_strength) * wind;
//}

vec3 get_wind_displacement(vec3 global_position, float strength){
	float time_factor = 0.025;
	float position_factor = 0.002;

	vec3 wind = texture(wind_noise_texture, position_factor * global_position.xz + (time_factor * TIME) * wind_direction.xz).rgb - vec3(.5) * vec3(1, 0.1, 1);
	wind = wind + wind_direction * 0.5;

	//float d = abs(dot(wind, wind_direction));
	return (strength * wind_strength) * wind;
}