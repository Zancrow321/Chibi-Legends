// Upright pixel-art cards (trees, bushes, grass, rocks) facing the camera
// axis. Cut out with alpha scissor so they cast real shadows; tops sway.
shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/hd2d/common.gdshaderinc"

uniform sampler2D tex : source_color, filter_nearest_mipmap;
uniform float wind = 0.0;

varying vec3 wpos;
varying vec3 tintc;

void vertex() {
	float top = 1.0 - UV.y;
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	VERTEX.x += sin(TIME * 1.4 + base.x * 0.7 + base.z * 0.31) * wind * top * top;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// tilt normals upward: flat cards read better lit from the sky
	NORMAL = normalize(vec3(0.0, 0.75, 0.66));
	tintc = COLOR.rgb;
}

void fragment() {
	vec4 t = texture(tex, UV);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
	if (depth_mode) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(hd2d_depth(VERTEX.z));
	} else {
		float f = hd2d_fog(wpos, CAMERA_POSITION_WORLD);
		ALBEDO = t.rgb * tintc * (1.0 - f);
		EMISSION = fog_color * f;
	}
}
