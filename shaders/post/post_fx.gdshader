// Screen post effect for the play area (own work, MIT like the project).
// One pass over the finished world image (HUD and menus are drawn later and
// stay untouched): shockwave rings, heat haze over fire, radial zoom blur
// for supers, chromatic aberration on big hits, a filmic colour grade per
// area (tone curve, split toning, ambient light from above, haze), a soft
// vignette, a danger pulse at low HP, manga impact frames and ordered
// dithering against banding.
// Distortion offsets and the dither snap to whole art pixels, so the pixel
// art stays crisp. Works in the Compatibility renderer (WebGL 2).
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
// filmic grade (0 = the old linear grade only)
uniform float filmic = 0.0;      // soft S-curve with a rolled-off shoulder
uniform vec3 shadow_tint = vec3(0.0);     // split toning: colour pushed into the darks
uniform vec3 highlight_tint = vec3(0.0);  // ... and into the lights
uniform float vibrance = 0.0;    // saturates dull colours more than vivid ones
// ambient light: screen-space light from above, depth haze near the bottom
uniform vec4 sky_light = vec4(0.0);   // rgb, a = strength (top of the screen)
uniform vec4 ground_haze = vec4(0.0); // rgb, a = strength (bottom of the screen)
uniform float haze_height = 0.35;     // how far the haze reaches up (screen heights)
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
// radial zoom blur (supers): xy = centre (screen uv), z = strength
uniform vec3 zoom_blur = vec3(0.5, 0.5, 0.0);
// low HP: 0..1, the screen edge pulses red and the colour drains
uniform float danger = 0.0;
// manga impact frame: 0..1, the image turns into two tones for a moment
uniform float impact = 0.0;
uniform vec3 impact_ink = vec3(0.04, 0.02, 0.06);
uniform vec3 impact_paper = vec3(1.0, 0.96, 0.9);
uniform float impact_invert = 0.0;
// short exposure punch on big hits
uniform float punch = 0.0;
uniform float dither = 0.0;      // ordered dither in art pixels (1 = one 8-bit step)
uniform float aspect = 1.7778;
uniform float art_px = 2.0;      // screen pixels per art pixel (snap of the offsets)

vec3 sample_rgb(vec2 uv) {
	return texture(screen_tex, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
}

float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x / 2.0 + a.y * a.y * 0.75);
}

// 4x4 ordered dither, about -0.5..0.5
float bayer4(vec2 p) {
	return bayer2(0.5 * p) * 0.25 + bayer2(p) - 0.5;
}

// soft S-curve around mid grey with a rolled-off shoulder (keeps the HDR
// effect glow from clipping flat white)
vec3 film_curve(vec3 c) {
	vec3 x = max(c, vec3(0.0));
	vec3 shoulder = x / (1.0 + x * 0.18) * 1.18;
	vec3 sc = clamp(shoulder, 0.0, 1.0);
	vec3 s = sc * sc * (3.0 - 2.0 * sc) + max(shoulder - 1.0, vec3(0.0));
	return mix(shoulder, s, 0.35);
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

	// radial zoom blur: streaks towards the super's centre, stepped in art pixels
	if (zoom_blur.z > 0.01) {
		vec2 to_c = uv - zoom_blur.xy;
		float reach = zoom_blur.z * 0.06;
		vec3 acc = col;
		float wsum = 1.0;
		for (int i = 1; i <= 7; i++) {
			float t = float(i) / 7.0;
			vec2 suv = uv - to_c * reach * t;
			suv = floor(suv / snap) * snap + snap * 0.5;
			float wgt = 1.0 - t * 0.6;
			acc += sample_rgb(suv) * wgt;
			wsum += wgt;
		}
		col = mix(col, acc / wsum, smoothstep(0.02, 0.3, length(to_c * vec2(aspect, 1.0))));
	}

	// grading: exposure, contrast around mid grey, saturation, lift / gain
	vec3 g = col * exposure * (1.0 + punch * 0.35);
	g = (g - 0.5) * contrast + 0.5;
	float lum = dot(g, vec3(0.299, 0.587, 0.114));
	g = mix(vec3(lum), g, saturation);
	vec3 base = clamp(g, 0.0, 1.0);
	g = g * gain + lift * (1.0 - base);

	if (filmic > 0.0) {
		// vibrance: dull colours get more saturation than strong ones
		float mx = max(g.r, max(g.g, g.b));
		float mn = min(g.r, min(g.g, g.b));
		float sat = clamp(mx - mn, 0.0, 1.0);
		float l2 = dot(g, vec3(0.299, 0.587, 0.114));
		g = mix(vec3(l2), g, 1.0 + vibrance * (1.0 - sat));
		// split toning by luminance
		float l = clamp(l2, 0.0, 1.0);
		g += shadow_tint * (1.0 - smoothstep(0.0, 0.55, l));
		g += highlight_tint * smoothstep(0.45, 1.0, l);
		g = mix(g, film_curve(g), filmic);
		// ambient light from above and haze that settles near the ground
		float top = 1.0 - smoothstep(0.0, 0.6, SCREEN_UV.y);
		g = mix(g, g + sky_light.rgb * (0.4 + 0.6 * l), sky_light.a * top);
		float low = smoothstep(1.0 - haze_height, 1.05, SCREEN_UV.y);
		g = mix(g, ground_haze.rgb, ground_haze.a * low * (0.6 + 0.4 * (1.0 - l)));
	}
	col = mix(col, max(g, vec3(0.0)), grade_mix);

	// low HP: the colour drains
	if (danger > 0.0) {
		float l3 = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(col, vec3(l3) * vec3(1.08, 0.9, 0.9), danger * 0.6);
	}

	// vignette, and at low HP an edge that breathes red
	vec2 v = (SCREEN_UV - 0.5) * vec2(aspect / 1.7778, 1.0);
	float vlen = length(v) * 1.15;
	float vig = smoothstep(0.35, 0.85, vlen) * vignette;
	col = mix(col, vignette_color, vig);
	if (danger > 0.0) {
		// heartbeat: two quick beats, then a pause
		float beat = fract(TIME * 1.1);
		float pulse = 0.6 + 0.4 * max(exp(-beat * 18.0), 0.7 * exp(-abs(beat - 0.22) * 18.0));
		float edge = smoothstep(0.25, 0.8, vlen) * danger * pulse;
		col = mix(col, vec3(0.6, 0.02, 0.06), clamp(edge * 1.1, 0.0, 0.9));
	}

	// manga impact frame: ink and paper (inverted on the first flash)
	if (impact > 0.0) {
		float l4 = dot(col, vec3(0.299, 0.587, 0.114));
		vec2 ap = floor(FRAGCOORD.xy / art_px);
		float th = 0.86 + bayer4(ap) * 0.1;
		float ink = step(th, l4);
		ink = mix(ink, 1.0 - ink, impact_invert);
		vec3 two = mix(impact_ink, impact_paper, ink);
		col = mix(col, two, impact);
	}

	// ordered dither in art pixels: breaks up banding in the vignette and haze
	if (dither > 0.0) {
		vec2 ap2 = floor(FRAGCOORD.xy / art_px);
		col += vec3(bayer4(ap2) * dither / 255.0 * 2.0);
	}

	COLOR = vec4(col, 1.0);
}
