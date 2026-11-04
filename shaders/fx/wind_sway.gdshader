// Wind for parallax tree layers (own work, MIT like the project).
// Tops sway more than the trunks; the shift snaps to whole texture pixels,
// so the pixel art never smears. Gusts roll through from left to right.
shader_type canvas_item;

uniform float amount = 1.5;       // max sway in texture pixels at the very top
uniform float speed = 1.3;
uniform float gust = 0.5;         // strength of the slow gusts
uniform float top = 0.0;          // uv.y of the highest leaves (full sway)
uniform float root = 0.85;        // uv.y below which nothing moves

varying vec4 tint;

void vertex() {
	tint = COLOR; // modulate only (in fragment COLOR already holds the texture)
}

void fragment() {
	vec2 tpx = TEXTURE_PIXEL_SIZE;
	vec2 tp = UV / tpx;
	float h = clamp((root - UV.y) / max(root - top, 0.001), 0.0, 1.0);
	h *= h;
	float wave = sin(TIME * speed + tp.x * 0.045) + 0.5 * sin(TIME * speed * 2.3 + tp.x * 0.11);
	float g = 1.0 + gust * sin(TIME * 0.35 - tp.x * 0.008);
	float shift = floor(wave * g * amount * h + 0.5);
	COLOR = texture(TEXTURE, UV - vec2(shift * tpx.x, 0.0)) * tint;
}
