// God-ray card: additive, soft at the sides, fading toward the ground.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.93, 0.72);
uniform float intensity = 0.3;

void fragment() {
	float side = sin(UV.x * 3.14159);
	side *= side;
	float fade = smoothstep(1.0, 0.15, UV.y) * smoothstep(0.0, 0.08, UV.y);
	float shimmer = 0.75 + 0.25 * sin(TIME * 0.7 + UV.x * 6.0);
	ALBEDO = color * intensity * side * fade * shimmer;
}
