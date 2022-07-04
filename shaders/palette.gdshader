shader_type canvas_item;

uniform sampler2D palette : hint_default_black;
uniform int palette_size = 16;

void fragment(){ 
	vec4 target = texture(SCREEN_TEXTURE, SCREEN_UV);
	
	COLOR = vec4(0.0);
	
	for (int i = 0; i < palette_size; ++i) {
		float x = (float(i) + 0.5f) / float(palette_size);
		vec4 palette_color = texture(palette, vec2(x, 0.0f));
		
		if (distance(palette_color, target) < distance(COLOR, target)) {
			COLOR = palette_color;
		}
	}
}
