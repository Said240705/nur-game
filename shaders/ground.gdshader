shader_type canvas_item;
// Endless moonlit snowfield. Pattern is anchored to world space, so the rect
// can follow the camera without the snow sliding.

varying vec2 world_pos;

float hash(vec2 p) {
	p = mod(p, 4096.0);
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float drifts = fbm(world_pos / 460.0);
	float ripples = fbm(vec2(world_pos.x / 90.0, world_pos.y / 26.0));
	vec3 c = mix(vec3(0.74, 0.78, 0.85), vec3(0.96, 0.97, 0.99), drifts);
	c -= ripples * 0.06;
	float sparkle = step(0.9965, hash(floor(world_pos / 3.0)));
	c += sparkle * 0.35;
	COLOR = vec4(c, 1.0);
}
