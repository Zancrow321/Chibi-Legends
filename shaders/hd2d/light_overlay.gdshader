// Variant A: morning light laid over the flat 2D play layer so it sits in
// the same light as the 3D backdrop: slanted sun rays, warm top haze.
shader_type canvas_item;
render_mode blend_add;

uniform float strength = 1.0;
uniform float scroll = 0.0;

void fragment() {
	vec2 p = UV;
	float a = (p.x + p.y * 0.55) * 7.0 + scroll * 0.002;
	float rays = smoothstep(0.55, 1.0, sin(a) * 0.5 + 0.5) * 0.6 + smoothstep(0.7, 1.0, sin(a * 2.3 + 1.7) * 0.5 + 0.5) * 0.4;
	rays *= smoothstep(1.0, 0.0, p.y) * (0.75 + 0.25 * sin(TIME * 0.6 + a));
	float haze = smoothstep(0.6, 0.0, p.y) * smoothstep(1.0, 0.0, p.x) * 0.5;
	COLOR = vec4(vec3(1.0, 0.93, 0.74) * (rays * 0.10 + haze * 0.10) * strength, 1.0);
}
