// Shared part of dissolve.gdshader and dissolve_seam.gdshader.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.6, 0.25, 1.0);
uniform float edge_glow = 2.4;
uniform float edge_width = 0.09;
uniform float block = 2.0;      // noise cell size in texture pixels
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.3) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 tp = floor(UV / TEXTURE_PIXEL_SIZE / block);
	float n = noise(tp * 0.45) * 0.65 + hash(tp) * 0.35;
	// burns from the head down: the top dissolves first
	float h = n * 0.6 + UV.y * 0.4;
	float p = progress * 1.25 - 0.1;
	float gone = step(h, p);
	float seam = step(h, p + edge_width) - gone;
#ifdef SEAM
	COLOR = vec4(edge_color.rgb * edge_glow, tex.a * seam * step(0.001, progress));
#else
	COLOR = vec4(tex.rgb, tex.a * (1.0 - gone - seam)) * tint;
#endif
}
