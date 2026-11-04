// Shared by all HD-2D world shaders: distance haze + low mist over the
// river, and a "depth mode" used by the depth-of-field pass (the same mesh
// is drawn a second time into a small depth view, writing its distance).
uniform vec3 fog_color : source_color = vec3(0.80, 0.88, 0.86);
uniform float fog_start = 30.0;
uniform float fog_end = 150.0;
uniform float fog_max = 0.72;
uniform float mist_top = -5.5;
uniform float mist_range = 4.0;
uniform float mist_amount = 0.5;
uniform bool depth_mode = false;
uniform float depth_far = 160.0;

float hd2d_fog(vec3 wpos, vec3 cam) {
	float d = length(wpos - cam);
	float f = clamp((d - fog_start) / (fog_end - fog_start), 0.0, 1.0);
	f = f * (2.0 - f) * fog_max;
	float m = clamp((mist_top - wpos.y) / mist_range, 0.0, 1.0) * mist_amount * clamp((d - 12.0) / 25.0, 0.0, 1.0);
	return clamp(f + m * (1.0 - f), 0.0, 1.0);
}

float hd2d_depth(float view_z) {
	return clamp(-view_z / depth_far, 0.0, 1.0);
}
