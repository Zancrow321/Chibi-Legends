// Stylised river: pixel-snapped ripples, bright crests, shore foam,
// sun sparkles (feed the bloom) and an optional planar reflection.
shader_type spatial;
render_mode cull_back;
#include "res://shaders/hd2d/common.gdshaderinc"

uniform vec3 deep : source_color = vec3(0.09, 0.32, 0.40);
uniform vec3 shallow : source_color = vec3(0.27, 0.60, 0.62);
uniform vec3 sky : source_color = vec3(0.80, 0.90, 0.93);
uniform float bank_a = -7.0;
uniform float bank_b = -15.0;
uniform float flow = 1.0;
uniform bool use_reflection = false;
uniform sampler2D reflection_tex : source_color, filter_linear;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = floor(wpos.xz * 16.0) / 16.0;
	float t = TIME;
	float w = sin(p.x * 1.7 - t * 1.6 * flow + sin(p.y * 2.3 + t * 0.4) * 1.5)
		+ 0.7 * sin(p.x * 0.9 + p.y * 3.1 - t * 1.1 * flow)
		+ 0.35 * sin((p.x + p.y) * 4.7 - t * 2.3);
	float edge = min(abs(wpos.z - bank_a), abs(wpos.z - bank_b));
	vec3 c = mix(shallow, deep, clamp(edge / 3.0, 0.0, 1.0));
	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	float fr = pow(1.0 - clamp(v.y, 0.0, 1.0), 3.0);
	vec3 refl = sky;
	if (use_reflection) {
		vec2 ruv = vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y) + vec2(w * 0.003, w * 0.006);
		refl = mix(sky, texture(reflection_tex, ruv).rgb, 0.85);
	}
	c = mix(c, refl, 0.22 + 0.55 * fr);
	float crest = step(1.45, w);
	c = mix(c, mix(c, vec3(0.92, 0.98, 1.0), 0.6), crest);
	float foam = step(edge, 0.35 + 0.25 * sin(p.x * 3.0 + t * 2.0) + 0.15 * sin(p.x * 7.3 - t * 3.1));
	c = mix(c, vec3(0.94, 0.98, 1.0), foam * 0.9);
	// sparkles: rare pixels flash white
	float s = hash(p + floor(t * 3.0));
	float sparkle = step(0.992, s) * step(0.8, w);
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
	if (depth_mode) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(hd2d_depth(VERTEX.z));
	} else {
		float f = hd2d_fog(wpos, CAMERA_POSITION_WORLD);
		ALBEDO = c * 0.45 * (1.0 - f);
		EMISSION = c * 0.55 * (1.0 - f) + fog_color * f + vec3(1.6) * sparkle * (1.0 - f);
	}
}
