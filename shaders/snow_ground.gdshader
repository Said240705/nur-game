shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// Endless snowfield anchored to world space: soft drifts, wind ripples, glitter.

uniform vec3 snow_color : source_color = vec3(0.78, 0.82, 0.9);
uniform vec3 shade_color : source_color = vec3(0.52, 0.6, 0.78);

varying vec3 world_pos;

float hash(vec2 p) {
	p = mod(p, 1024.0);
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float drifts(vec2 p) {
	return noise(p * 0.06) * 0.6 + noise(p * 0.17) * 0.3 + noise(vec2(p.x * 0.9, p.y * 0.3)) * 0.1;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float e = 0.3;
	float h = drifts(p);
	float hx = drifts(p + vec2(e, 0.0));
	float hz = drifts(p + vec2(0.0, e));
	vec3 n = normalize(vec3((h - hx) * 6.0, 1.0, (h - hz) * 6.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = mix(shade_color, snow_color, smoothstep(0.2, 0.8, h));
	ROUGHNESS = 0.75;
	float glitter = step(0.9985, hash(floor(p * 22.0)));
	EMISSION = vec3(glitter) * 0.6;
}
