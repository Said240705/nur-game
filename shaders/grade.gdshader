shader_type canvas_item;
// One look for every illustration in the game, whatever image it came from:
// teal shadows, warm highlights, a touch more contrast, vignette and film grain.

uniform float grain = 0.07;
uniform float vignette = 0.9;
uniform float contrast = 1.08;
uniform float exposure = 1.25;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 shadows = vec3(0.02, 0.07, 0.1) * (1.0 - l);
	vec3 graded = c.rgb + shadows * 0.6;
	graded = mix(graded, graded * vec3(1.06, 0.98, 0.9), smoothstep(0.45, 1.0, l));
	graded = (graded - 0.5) * contrast + 0.5;
	vec2 v = SCREEN_UV - 0.5;
	graded *= 1.0 - dot(v, v) * vignette;
	float n = fract(sin(dot(SCREEN_UV * vec2(1234.5, 987.6) + fract(TIME * 7.0) * 31.0, vec2(12.9898, 78.233))) * 43758.5453);
	graded += (n - 0.5) * grain;
	COLOR = vec4(graded * exposure, c.a) * COLOR;
}
