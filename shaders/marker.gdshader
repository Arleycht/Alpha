shader_type spatial;
render_mode unshaded;

uniform vec4 albedo;

void vertex() {
	VERTEX = VERTEX + vec3(0.0, sin(PI * TIME) * 0.125 + 0.125, 0.0);
}

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
}
