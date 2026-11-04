// Grass overhang strip hanging over a cliff edge; tiles along the edge.
shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/hd2d/common.gdshaderinc"

uniform sampler2D tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool along_z = false;
uniform float texel_scale = 0.5;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize(vec3(0.0, 0.6, 0.8));
}

void fragment() {
	float u = (along_z ? wpos.z : wpos.x) * texel_scale;
	vec4 t = texture(tex, vec2(u, UV.y));
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
	if (depth_mode) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(hd2d_depth(VERTEX.z));
	} else {
		float f = hd2d_fog(wpos, CAMERA_POSITION_WORLD);
		ALBEDO = t.rgb * (1.0 - f);
		EMISSION = fog_color * f;
	}
}
