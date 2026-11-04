shader_type canvas_item;
// Recolors palette-indexed character sprites (format: tools/sprites/rig.py).
// red = tone * 32 + 16, green = slot * 64 + 32. The palette texture is 8 x 4:
// column = tone, row = slot (rows 0-2 = the item's color channels, row 3 = fixed colors).

uniform sampler2D palette : filter_nearest, repeat_disable;
uniform float flash : hint_range(0.0, 1.0) = 0.0;  // white hit flash

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	if (src.a < 0.5) {
		discard;
	}
	int tone = clamp(int(floor(src.r * 255.0 / 32.0)), 0, 7);
	int slot = clamp(int(floor(src.g * 255.0 / 64.0)), 0, 3);
	vec4 c = texelFetch(palette, ivec2(tone, slot), 0);
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a * COLOR.a);
}
