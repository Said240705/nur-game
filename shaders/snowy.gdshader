shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// Takes a KayKit atlas-textured model and lays snow on every upward-facing surface.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float snow_amount = 0.55;
uniform vec3 snow_color : source_color = vec3(0.9, 0.93, 0.99);
uniform float darken = 0.8;

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * darken;
	float up = smoothstep(1.0 - snow_amount, 1.0 - snow_amount + 0.12, world_normal.y);
	ALBEDO = mix(c, snow_color, up);
	ROUGHNESS = mix(0.85, 0.6, up);
}
