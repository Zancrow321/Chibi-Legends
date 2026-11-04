// Post step 2: depth of field (real depth on "Hoch", tilt-shift otherwise),
// bloom, warm morning grade and a light vignette.
shader_type canvas_item;

uniform sampler2D scene_tex : filter_linear, repeat_disable;
uniform sampler2D blur_tex : filter_linear, repeat_disable;
uniform sampler2D depth_tex : filter_linear, repeat_disable;
uniform bool use_depth = false;
uniform float focus_depth = 0.2;
uniform float focus_range = 0.02;
uniform float far_ramp = 0.3;
uniform float near_ramp = 0.06;
uniform float tilt_focus_y = 0.6;
uniform float tilt_band = 0.18;
uniform float tilt_ramp = 0.35;
uniform float base_blur = 0.0;
uniform float dof_strength = 1.0;
uniform bool mid_blur = true;
uniform float bloom_threshold = 0.72;
uniform float bloom_strength = 0.8;
uniform float saturation = 1.04;
uniform float vignette = 0.35;

vec3 ring(sampler2D t, vec2 uv, vec2 r) {
	vec3 c = texture(t, uv).rgb;
	c += texture(t, uv + vec2(1.0, 0.0) * r).rgb;
	c += texture(t, uv + vec2(-1.0, 0.0) * r).rgb;
	c += texture(t, uv + vec2(0.0, 1.0) * r).rgb;
	c += texture(t, uv + vec2(0.0, -1.0) * r).rgb;
	c += texture(t, uv + vec2(0.7, 0.7) * r).rgb;
	c += texture(t, uv + vec2(-0.7, 0.7) * r).rgb;
	c += texture(t, uv + vec2(0.7, -0.7) * r).rgb;
	c += texture(t, uv + vec2(-0.7, -0.7) * r).rgb;
	return c / 9.0;
}

void fragment() {
	vec2 uv = UV;
	vec3 sharp = texture(scene_tex, uv).rgb;
	float coc;
	if (use_depth) {
		float d = texture(depth_tex, uv).r;
		float dd = d - focus_depth;
		coc = dd > 0.0 ? clamp((dd - focus_range) / far_ramp, 0.0, 1.0) : clamp((-dd - focus_range) / near_ramp, 0.0, 1.0);
	} else {
		float dy = uv.y - tilt_focus_y;
		coc = clamp((abs(dy) - tilt_band) / tilt_ramp, 0.0, 1.0);
	}
	coc = clamp(max(coc, base_blur) * dof_strength, 0.0, 1.0);
	vec2 bpx = 1.0 / vec2(textureSize(blur_tex, 0));
	vec3 soft = ring(blur_tex, uv, bpx * 1.2);
	vec3 col;
	if (mid_blur) {
		vec2 spx = 1.0 / vec2(textureSize(scene_tex, 0));
		vec3 mid = ring(scene_tex, uv, spx * 2.5);
		col = coc < 0.5 ? mix(sharp, mid, coc * 2.0) : mix(mid, soft, coc * 2.0 - 1.0);
	} else {
		col = mix(sharp, ring(blur_tex, uv, bpx * 2.0), smoothstep(0.0, 1.0, coc));
	}
	vec3 wide = ring(blur_tex, uv, bpx * 3.5);
	float l = max(wide.r, max(wide.g, wide.b));
	vec3 bloom = wide * max(l - bloom_threshold, 0.0) / (1.0 - bloom_threshold + 0.001);
	col += bloom * bloom_strength * vec3(1.0, 0.94, 0.82);
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation);
	col = col * vec3(1.03, 1.0, 0.95) + vec3(0.0, 0.012, 0.025) * (1.0 - lum);
	vec2 q = uv - 0.5;
	col *= 1.0 - vignette * dot(q, q) * 1.6;
	COLOR = vec4(col, 1.0);
}
