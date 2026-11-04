shader_type canvas_item;
// Umfärben eines Creator-Teils. Umrisse (sehr dunkle Pixel) bleiben immer.
// Kleidung/Haare: Verlaufs-Map. Die Helligkeit jedes Pixels wird auf einen
//   Verlauf der Zielfarbe gelegt (Schatten -> Farbe -> Glanzlicht), so bleibt
//   die Schattierung erhalten. amount = 0 heißt Originalfarben.
// Haut (warm_only): HSV-Verschiebung nur auf warmen Hauttönen.

uniform vec4 target : source_color = vec4(1.0);
uniform float amount = 0.0;
uniform bool warm_only = false;
uniform float hue = 0.0;
uniform float sat = 1.0;
uniform float val = 1.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec3 h = rgb2hsv(col.rgb);
	bool outline = h.z < 0.16;
	if (!outline) {
		if (warm_only) {
			bool warm = (h.x < 0.12 || h.x > 0.95) && h.y > 0.18 && h.z > 0.35;
			if (warm) {
				h.x = fract(h.x + hue + 1.0);
				h.y = clamp(h.y * sat, 0.0, 1.0);
				h.z = clamp(h.z * val, 0.0, 1.0);
				col.rgb = hsv2rgb(h);
			}
		} else if (amount > 0.0) {
			float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
			vec3 dark = target.rgb * 0.38 + vec3(0.02, 0.0, 0.05);
			vec3 light = mix(target.rgb, vec3(1.0, 0.98, 0.94), 0.55);
			// Helligkeit auf Schatten..Farbe..Glanz legen (Wurzel hebt dunkle Stoffe an)
			float t = sqrt(clamp((lum - 0.1) / 0.75, 0.0, 1.0));
			vec3 g = t < 0.55 ? mix(dark, target.rgb, t / 0.55) : mix(target.rgb, light, (t - 0.55) / 0.45);
			col.rgb = mix(col.rgb, g, amount);
		}
	}
	COLOR = col * COLOR;
}
