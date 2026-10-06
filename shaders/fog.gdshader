shader_type canvas_item;
// The Silence: pale drifting fog that closes in around Nur's light.

uniform vec2 cam_pos = vec2(0.0);
uniform vec2 screen_size = vec2(1920.0, 1080.0);
// Radius of the clear circle around the screen centre, in screen heights.
uniform float clear_radius = 0.35;
uniform float density = 0.8;

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
		p *= 2.07;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 px = UV * screen_size;
	vec2 world = px + cam_pos - screen_size * 0.5;
	float t = TIME * 0.035;
	float n = fbm(world / 560.0 + vec2(t, t * 0.4)) * 0.65
			+ fbm(world / 240.0 - vec2(t * 1.8, t * 0.3)) * 0.35;
	vec2 d = (UV - 0.5) * vec2(screen_size.x / screen_size.y, 1.0);
	float r = length(d);
	float edge = smoothstep(clear_radius, clear_radius + 0.42, r);
	float a = clamp(n * 1.5 - 0.2, 0.0, 1.0) * edge * density;
	COLOR = vec4(vec3(0.82, 0.85, 0.9), a);
}
