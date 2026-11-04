// Blocky terrain: pixel grass on top, rock strata on the sides, mapped in
// world space so every block lines up (16 texels per world unit).
shader_type spatial;
render_mode cull_back;
#include "res://shaders/hd2d/common.gdshaderinc"

uniform sampler2D tex_top : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D tex_side : source_color, filter_nearest_mipmap, repeat_enable;
uniform float texel_scale = 0.5;
uniform bool swap_top_uv = false;
uniform vec3 tint : source_color = vec3(1.0);
// lit tops get the full sun, so they are toned down to sit with the sides
uniform vec3 top_tint : source_color = vec3(0.78, 0.82, 0.74);

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(wnrm);
	vec3 c;
	if (n.y > 0.5) {
		vec2 uv = swap_top_uv ? wpos.zx : wpos.xz;
		c = texture(tex_top, uv * texel_scale).rgb * top_tint;
	} else if (n.x > n.z) {
		c = texture(tex_side, vec2(wpos.z, -wpos.y) * texel_scale).rgb;
	} else {
		c = texture(tex_side, vec2(wpos.x, -wpos.y) * texel_scale).rgb;
	}
	c *= tint;
	SPECULAR = 0.1;
	ROUGHNESS = 0.95;
	if (depth_mode) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(hd2d_depth(VERTEX.z));
	} else {
		float f = hd2d_fog(wpos, CAMERA_POSITION_WORLD);
		ALBEDO = c * (1.0 - f);
		EMISSION = fog_color * f;
	}
}
