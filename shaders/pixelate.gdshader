shader_type canvas_item;

uniform float blur_strength = 0.5f;
uniform float scale = 4.0f;

void fragment() {
	vec2 res = SCREEN_PIXEL_SIZE * scale;
	vec2 uv = floor(SCREEN_UV / res) * res;
	
	COLOR = vec4(0.0f);
	
	COLOR += 0.0625 * texture(SCREEN_TEXTURE, uv + vec2(-res.x, -res.y));
	COLOR += 0.125 * texture(SCREEN_TEXTURE, uv + vec2(0.0f, -res.y));
	COLOR += 0.0625 * texture(SCREEN_TEXTURE, uv + vec2(res.x, -res.y));
	COLOR += 0.125 * texture(SCREEN_TEXTURE, uv + vec2(-res.x, 0.0f));
	COLOR += 0.25 * texture(SCREEN_TEXTURE, uv);
	COLOR += 0.125 * texture(SCREEN_TEXTURE, uv + vec2(res.x, 0.0f));
	COLOR += 0.0625 * texture(SCREEN_TEXTURE, uv + vec2(-res.x, res.y));
	COLOR += 0.125 * texture(SCREEN_TEXTURE, uv + vec2(0.0f, res.y));
	COLOR += 0.0625 * texture(SCREEN_TEXTURE, uv + vec2(res.x, res.y));
	
	COLOR = mix(texture(SCREEN_TEXTURE, uv), COLOR, blur_strength);
}
