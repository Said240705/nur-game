shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;
// Distant peaks: flat stylized shading, snowy upper slopes, blended into the night haze.

uniform vec3 rock_color : source_color = vec3(0.16, 0.2, 0.31);
uniform vec3 snow_color : source_color = vec3(0.72, 0.78, 0.92);
uniform vec3 haze_color : source_color = vec3(0.26, 0.33, 0.5);
uniform vec3 light_dir = vec3(-0.45, 0.55, 0.7);
uniform float haze = 0.45;
uniform float snow_line = 0.42;

varying vec3 world_normal;
varying float local_h;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	local_h = VERTEX.y;
}

void fragment() {
	float wobble = sin(local_h * 40.0 + world_normal.x * 6.0) * 0.04;
	float snow = smoothstep(snow_line, snow_line + 0.12, local_h + wobble) * smoothstep(0.05, 0.3, world_normal.y);
	snow = max(snow, smoothstep(0.55, 0.75, world_normal.y) * 0.85);
	vec3 c = mix(rock_color, snow_color, snow);
	float lit = 0.5 + 0.6 * max(dot(world_normal, normalize(light_dir)), 0.0);
	c *= lit;
	ALBEDO = mix(c, haze_color, haze * (1.0 - local_h * 0.3));
}
