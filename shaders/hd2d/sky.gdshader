// Morning sky on a far backdrop plane: pale warm horizon, soft blue top,
// sun glow at the upper left, faint drifting cloud bands.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform vec3 top_color : source_color = vec3(0.47, 0.70, 0.90);
uniform vec3 horizon_color : source_color = vec3(0.93, 0.95, 0.86);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.78);
uniform vec2 sun_uv = vec2(0.28, 0.18);
uniform bool depth_mode = false;

void fragment() {
	float h = clamp(1.0 - UV.y * 1.6, 0.0, 1.0);
	vec3 c = mix(horizon_color, top_color, pow(h, 1.4));
	vec2 d = (UV - sun_uv) * vec2(2.4, 1.0);
	float g = exp(-dot(d, d) * 14.0);
	c = mix(c, sun_color, g * 0.85);
	float band = sin(UV.x * 9.0 + TIME * 0.02) * 0.5 + sin(UV.x * 23.0 - TIME * 0.03) * 0.25;
	float cloud = smoothstep(0.55, 0.9, band) * smoothstep(0.15, 0.3, UV.y) * smoothstep(0.55, 0.35, UV.y);
	c = mix(c, vec3(1.0, 0.99, 0.95), cloud * 0.35);
	ALBEDO = depth_mode ? vec3(1.0) : c;
}
