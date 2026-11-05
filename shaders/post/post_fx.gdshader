// Screen post effect for the play area (own work, MIT like the project).
// One pass over the finished world image (HUD and menus are drawn later and
// stay untouched): shockwave rings, heat haze over fire, chromatic
// aberration on big hits, colour grading and a soft vignette.
// Distortion offsets snap to whole art pixels, so the pixel art stays crisp.
// Works in the Compatibility renderer (WebGL 2).
shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

// colour grading
uniform float exposure = 1.0;
uniform float contrast = 1.0;
uniform float saturation = 1.0;
uniform vec3 lift = vec3(0.0);   // added to the shadows
uniform vec3 gain = vec3(1.0);   // multiplies the highlights
uniform float grade_mix = 1.0;   // 0 = no grading
// vignette
uniform float vignette = 0.0;
uniform vec3 vignette_color = vec3(0.02, 0.0, 0.05);
// chromatic aberration in screen pixels
uniform float aberration = 0.0;
// shockwaves: xy = centre (screen uv), z = radius (in screen heights), w = strength
uniform vec4 waves[4];
// heat sources: xy = centre (screen uv), z = radius (in screen heights), w = strength
uniform vec4 heat[6];
uniform float heat_on = 1.0;
uniform float aspect = 1.7778;
uniform float art_px = 2.0;      // screen pixels per art pixel (snap of the offsets)

vec3 sample_rgb(vec2 uv) {
	return texture(screen_tex, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 off = vec2(0.0);
	float ring_ca = 0.0;

	for (int i = 0; i < 4; i++) {
		vec4 w = waves[i];
		if (w.w <= 0.0) {
			continue;
		}
		vec2 d = (uv - w.xy) * vec2(aspect, 1.0);
		float dist = length(d);
		float band = (dist - w.z) / (0.035 + w.z * 0.12);
		float ring = exp(-band * band * 2.0) * smoothstep(0.0, 0.02, dist);
		// sample from inside the ring: the edge looks magnified and pushed out
		off -= (d / max(dist, 0.0001)) / vec2(aspect, 1.0) * ring * w.w * 0.014;
		ring_ca += ring * w.w;
	}

	if (heat_on > 0.5) {
		for (int i = 0; i < 6; i++) {
			vec4 h = heat[i];
			if (h.w <= 0.0) {
				continue;
			}
			vec2 d = (uv - h.xy) * vec2(aspect, 1.0);
			// heat rises: the zone is stretched upwards
			d.y = d.y < 0.0 ? d.y * 0.55 : d.y * 1.8;
			float k = 1.0 - clamp(length(d) / h.z, 0.0, 1.0);
			k *= k;
			float wob = sin(uv.y * 180.0 + TIME * 9.0) + 0.6 * sin(uv.y * 77.0 - TIME * 5.3 + uv.x * 40.0);
			off.x += wob * k * h.w * px.x * art_px * 1.2;
			off.y += cos(uv.x * 130.0 + TIME * 6.0) * k * h.w * px.y * art_px * 0.6;
		}
	}

	// whole art pixels only
	vec2 snap = px * art_px;
	off = floor(off / snap + 0.5) * snap;
	uv += off;

	vec3 col;
	float ca = aberration + ring_ca * 3.0;
	if (ca > 0.05) {
		vec2 dir = (uv - 0.5) * vec2(aspect, 1.0);
		dir = dir / max(length(dir), 0.0001) / vec2(aspect, 1.0);
		vec2 shift = dir * px * floor(ca * (0.4 + length(uv - 0.5)) + 0.5);
		col = vec3(sample_rgb(uv + shift).r, sample_rgb(uv).g, sample_rgb(uv - shift).b);
	} else {
		col = sample_rgb(uv);
	}

	// grading: exposure, contrast around mid grey, saturation, lift / gain
	vec3 g = col * exposure;
	g = (g - 0.5) * contrast + 0.5;
	float lum = dot(g, vec3(0.299, 0.587, 0.114));
	g = mix(vec3(lum), g, saturation);
	vec3 base = clamp(g, 0.0, 1.0);
	g = g * gain + lift * (1.0 - base);
	col = mix(col, max(g, vec3(0.0)), grade_mix);

	// vignette
	vec2 v = (SCREEN_UV - 0.5) * vec2(aspect / 1.7778, 1.0);
	float vig = smoothstep(0.35, 0.85, length(v) * 1.15) * vignette;
	col = mix(col, vignette_color, vig);

	COLOR = vec4(col, 1.0);
}
