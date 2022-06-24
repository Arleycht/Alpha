shader_type canvas_item;

uniform float scale = 2.0f;

void fragment() {
	vec2 res = SCREEN_PIXEL_SIZE * scale;
	vec2 uv = floor(SCREEN_UV / res) * res;
	
	COLOR = vec4(0.0f);
	
	// 3x3 mean blur
	COLOR += texture(SCREEN_TEXTURE, uv + vec2(-res.x, -res.y));
	COLOR += texture(SCREEN_TEXTURE, uv + vec2(0.0f, -res.y));
	COLOR += texture(SCREEN_TEXTURE, uv + vec2(res.x, -res.y));
	COLOR += texture(SCREEN_TEXTURE, uv + vec2(-res.x, 0.0f));
	COLOR += texture(SCREEN_TEXTURE, uv);
	COLOR += texture(SCREEN_TEXTURE, uv + vec2(res.x, 0.0f));
	COLOR += texture(SCREEN_TEXTURE, uv + vec2(-res.x, res.y));
	COLOR += texture(SCREEN_TEXTURE, uv + vec2(0.0f, res.y));
	COLOR += texture(SCREEN_TEXTURE, uv + vec2(res.x, res.y));
	
	COLOR /= 9.0f;
}
