// Soft translucent mist / spray puff.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D tex : filter_linear;
uniform vec3 color : source_color = vec3(1.0, 0.99, 0.95);
uniform float amount = 0.3;

void fragment() {
	ALBEDO = color;
	ALPHA = texture(tex, UV).a * amount * COLOR.a;
}
