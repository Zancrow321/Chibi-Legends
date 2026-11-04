// Falling water sheet: pixel columns of streaks scrolling down, glowing.
shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/hd2d/common.gdshaderinc"

uniform float width_px = 64.0;
uniform float height_px = 48.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(float n) {
	return fract(sin(n * 91.345) * 47453.5453);
}

void fragment() {
	float col = floor(UV.x * width_px);
	float y = floor(UV.y * height_px) / height_px;
	float sp = 1.6 + hash(col) * 1.2;
	float v = fract(y * 3.0 - TIME * sp + hash(col + 7.0));
	vec3 c = mix(vec3(0.45, 0.78, 0.86), vec3(0.95, 1.0, 1.0), step(v, 0.28));
	c = mix(c, vec3(0.30, 0.62, 0.74), step(0.85, v) * 0.6);
	float edge = min(UV.x, 1.0 - UV.x) * width_px;
	ALPHA = edge < 1.0 + hash(col + floor(y * height_px)) * 1.5 ? 0.0 : 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	SPECULAR = 0.0;
	if (depth_mode) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(hd2d_depth(VERTEX.z));
	} else {
		float f = hd2d_fog(wpos, CAMERA_POSITION_WORLD);
		ALBEDO = c * 0.3 * (1.0 - f);
		EMISSION = c * 0.85 * (1.0 - f) + fog_color * f;
	}
}
