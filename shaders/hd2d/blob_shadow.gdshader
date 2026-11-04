// Round contact shadow under characters standing on the 3D ground.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float strength = 0.38;

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float r = length(q);
	ALBEDO = vec3(0.08, 0.07, 0.10);
	ALPHA = (1.0 - smoothstep(0.55, 1.0, r)) * strength;
}
