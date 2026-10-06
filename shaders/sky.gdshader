shader_type sky;
// Blue-hour night sky with twinkling stars and the moon drawn from the main light.

uniform vec3 top_color : source_color = vec3(0.025, 0.04, 0.11);
uniform vec3 horizon_color : source_color = vec3(0.26, 0.33, 0.5);
uniform vec3 ground_color : source_color = vec3(0.1, 0.13, 0.2);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	float y = EYEDIR.y;
	vec3 c = y > 0.0 ? mix(horizon_color, top_color, pow(y, 0.45)) : mix(horizon_color, ground_color, pow(-y, 0.4));
	if (AT_CUBEMAP_PASS == false) {
		vec3 cell = floor(EYEDIR * 260.0);
		float h = hash(cell);
		float star = step(0.9975, h) * smoothstep(0.04, 0.35, y);
		star *= 0.55 + 0.45 * sin(TIME * (1.0 + h * 3.0) + h * 80.0);
		c += vec3(star) * 0.9;
	}
	if (LIGHT0_ENABLED) {
		float m = dot(EYEDIR, LIGHT0_DIRECTION);
		c += vec3(0.93, 0.95, 1.0) * smoothstep(0.99955, 0.9997, m);
		c += vec3(0.3, 0.38, 0.6) * pow(max(m, 0.0), 300.0) * 0.8;
		c += vec3(0.15, 0.2, 0.32) * pow(max(m, 0.0), 12.0) * 0.25;
	}
	COLOR = c;
}
