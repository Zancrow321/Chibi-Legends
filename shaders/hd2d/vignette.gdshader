shader_type canvas_item;

uniform float strength = 0.35;

void fragment() {
	vec2 q = UV - 0.5;
	COLOR = vec4(0.05, 0.04, 0.08, clamp(dot(q, q) * 1.6 * strength, 0.0, 1.0));
}
