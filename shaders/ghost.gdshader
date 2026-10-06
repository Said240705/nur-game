shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_disabled;
// The Faceless: pale veiled figures that sway like smoke and dissolve when released.

uniform float appear = 0.0;
uniform float dissolve = 0.0;
uniform float flash = 0.0;
uniform float phase = 0.0;
uniform float body_height = 1.95;

varying float h;

void vertex() {
	h = VERTEX.y / body_height;
	VERTEX.x += sin(TIME * 1.6 + phase) * 0.08 * h + sin(TIME * 3.1 + phase * 2.0 + VERTEX.y * 4.0) * 0.03 * (1.0 - h);
	VERTEX.z += cos(TIME * 1.3 + phase) * 0.05 * h;
	if (h < 0.18) {
		float a = atan(VERTEX.z, VERTEX.x);
		VERTEX.y += sin(a * 7.0 + TIME * 2.2 + phase) * 0.07 * (1.0 - h / 0.18);
	}
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = mix(vec3(0.78, 0.84, 0.94), vec3(1.0, 0.8, 0.55), flash);
	EMISSION = vec3(0.22, 0.32, 0.52) * (0.35 + fres * 1.8) + vec3(1.0, 0.65, 0.35) * flash * 2.0;
	float n = fract(sin(dot(floor(UV * vec2(40.0, 60.0)), vec2(12.9898, 78.233))) * 43758.5453);
	if (n < dissolve) {
		discard;
	}
	ALPHA = clamp((0.4 + fres * 0.55) * appear * smoothstep(0.0, 0.22, h + 0.02), 0.0, 1.0);
}
