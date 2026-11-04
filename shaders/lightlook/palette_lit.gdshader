// Palette-swap character sprite (same encoding as assets/shaders/palette_swap.gdshader)
// with the light look's pixel lighting: automatic rounded normal and light
// posterised into hard steps (see pixel_lit.gdshader).
shader_type canvas_item;

uniform sampler2D palette : filter_nearest, repeat_disable;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float steps = 4.0;
uniform float half_w = 10.0;
uniform float center_y = -24.0;
uniform float half_h = 26.0;
uniform float flip = 1.0;
uniform float wrap = 0.45;

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	if (src.a < 0.5) {
		discard;
	}
	int tone = clamp(int(floor(src.r * 255.0 / 32.0)), 0, 7);
	int slot = clamp(int(floor(src.g * 255.0 / 64.0)), 0, 3);
	vec4 c = texelFetch(palette, ivec2(tone, slot), 0);
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a * COLOR.a);
	vec2 q = clamp(vec2(lp.x * flip / half_w, (lp.y - center_y) / half_h), -1.0, 1.0);
	NORMAL = normalize(vec3(q.x, q.y * 0.6, 0.75));
}

void light() {
	float nd = wrap + (1.0 - wrap) * max(dot(NORMAL, LIGHT_DIRECTION), 0.0);
	vec3 l = LIGHT_COLOR.rgb * LIGHT_ENERGY * nd;
	l = floor(l * steps + 0.25) / steps;
	LIGHT = vec4(COLOR.rgb * l, LIGHT_COLOR.a);
}
