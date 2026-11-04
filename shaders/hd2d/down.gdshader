// Post step 1: shrink the 3D image to quarter size with a soft 9-tap blur.
// Feeds both the depth-of-field and the bloom of the composite.
shader_type canvas_item;

void fragment() {
	vec2 s = 1.0 / vec2(textureSize(TEXTURE, 0));
	vec3 c = vec3(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			c += texture(TEXTURE, UV + vec2(float(x), float(y)) * s * 2.5).rgb;
		}
	}
	COLOR = vec4(c / 9.0, 1.0);
}
