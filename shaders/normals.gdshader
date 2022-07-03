shader_type spatial;
render_mode shadows_disabled;

varying vec3 world_normal;

void vertex() {
	world_normal = NORMAL;
}

void fragment() {
	ALBEDO = world_normal;
}
