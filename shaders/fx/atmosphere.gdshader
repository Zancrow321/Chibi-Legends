// Atmosphere between the backdrop and the play layer (own work, MIT like the
// project): slanted god rays from a low sun and a drifting ground mist.
// Drawn in art-pixel blocks and posterised into a few bands, so it reads
// as pixel art and not as a smooth gradient. One full-screen pass, no
// textures; premultiplied alpha: the rays add light, the mist veils.
shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

uniform vec2 sun = vec2(1.05, -0.25);        // sun position in screen uv
uniform vec3 ray_color : source_color = vec3(1.0, 0.7, 0.45);
uniform float ray_strength = 0.22;
uniform float ray_count = 9.0;
uniform vec3 mist_color : source_color = vec3(0.45, 0.38, 0.62);
uniform float mist_strength = 0.35;
uniform float mist_top = 0.62;              // uv.y where the mist starts
uniform float mist_bottom = 0.9;            // uv.y where it is densest
uniform float cam_x = 0.0;                  // camera x in world pixels (parallax drift)
uniform float art_px = 2.0;
uniform float bands = 4.0;
uniform float aspect = 1.7778;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 45758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float posterise(float v) {
	return floor(v * bands + 0.5) / bands;
}

void fragment() {
	// art-pixel blocks
	vec2 block = SCREEN_PIXEL_SIZE * art_px;
	vec2 uv = (floor(SCREEN_UV / block) + 0.5) * block;

	// god rays: bright and dark wedges around the sun, slowly breathing
	vec2 d = (uv - sun) * vec2(aspect, 1.0);
	float ang = atan(d.y, d.x);
	float r = sin(ang * ray_count + TIME * 0.15) * 0.5 + 0.5;
	r *= sin(ang * ray_count * 2.3 - TIME * 0.11 + 1.7) * 0.35 + 0.65;
	r = smoothstep(0.45, 0.95, r);
	float fall = clamp(1.0 - length(d) / 1.9, 0.0, 1.0);
	float ray = posterise(r * fall * fall) * ray_strength * (1.0 - smoothstep(0.35, 0.98, uv.y));

	// ground mist: two noise layers drifting at different speeds
	vec2 mp = vec2(uv.x * aspect * 3.0 + cam_x * 0.0012, uv.y * 7.0);
	float n = noise(mp + vec2(TIME * 0.05, 0.0)) * 0.6 + noise(mp * 2.1 - vec2(TIME * 0.09, 0.0)) * 0.4;
	float h = smoothstep(mist_top, mist_bottom, uv.y);
	float mist = posterise(clamp(h * (0.35 + n * 0.9), 0.0, 1.0)) * mist_strength;

	COLOR = vec4(ray_color * ray + mist_color * mist, mist);
}
