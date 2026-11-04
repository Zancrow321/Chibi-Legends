// 2D lighting for pixel art: lights are posterised into a few hard steps
// (pixel-art bands instead of smooth gradients). Characters get an
// automatic rounded normal (no hand-made normal map needed), so a lantern
// on the left lights their left side and leaves a darker right side.
shader_type canvas_item;

uniform float steps = 4.0;
uniform bool auto_normal = false;
uniform float half_w = 10.0;
uniform float center_y = -24.0;
uniform float half_h = 26.0;
uniform float flip = 1.0;
uniform float wrap = 0.45; // how much light reaches the side facing away

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	if (auto_normal) {
		vec2 q = clamp(vec2(lp.x * flip / half_w, (lp.y - center_y) / half_h), -1.0, 1.0);
		NORMAL = normalize(vec3(q.x, q.y * 0.6, 0.75));
	}
}

void light() {
	float nd = 1.0;
	if (auto_normal) {
		nd = wrap + (1.0 - wrap) * max(dot(NORMAL, LIGHT_DIRECTION), 0.0);
	}
	vec3 l = LIGHT_COLOR.rgb * LIGHT_ENERGY * nd;
	l = floor(l * steps + 0.25) / steps;
	LIGHT = vec4(COLOR.rgb * l, LIGHT_COLOR.a);
}
