shader_type canvas_item;
// Recolors sprites that use the master palette (assets/palettes, see tools/palette).
// Each pixel is looked up in master_palette (N x 1). If found, its color comes
// from swap_lut at (index, variant); row 0 of the LUT is the original palette.
// Pixels that are not in the palette stay unchanged, so mixed art still works.
// Use scripts/fx/palette_remap.gd to create the material and pick a variant by name.

uniform sampler2D master_palette : filter_nearest, repeat_disable;
uniform sampler2D swap_lut : filter_nearest, repeat_disable;
uniform int variant = 0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;  // white hit flash

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	vec3 rgb = src.rgb;
	int n = textureSize(master_palette, 0).x;
	int rows = textureSize(swap_lut, 0).y;
	int row = clamp(variant, 0, rows - 1);
	for (int i = 0; i < n; i++) {
		vec3 p = texelFetch(master_palette, ivec2(i, 0), 0).rgb;
		vec3 d = abs(p - rgb);
		if (max(d.r, max(d.g, d.b)) < 0.002) {
			rgb = texelFetch(swap_lut, ivec2(i, row), 0).rgb;
			break;
		}
	}
	COLOR = vec4(mix(rgb, vec3(1.0), flash), src.a * COLOR.a);
}
