// Variant B: the 2D gameplay (characters, attacks, effects) rendered into
// its own viewport and shown as one crisp, unlit card standing in the 3D world.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D tex : source_color, filter_nearest;
uniform vec3 tint : source_color = vec3(1.0, 0.98, 0.94);
uniform bool depth_mode = false;
uniform float depth_far = 160.0;

void fragment() {
	vec4 t = texture(tex, UV);
	if (depth_mode) {
		if (t.a < 0.5) {
			discard;
		}
		ALBEDO = vec3(clamp(-VERTEX.z / depth_far, 0.0, 1.0));
		ALPHA = 1.0;
	} else {
		ALBEDO = t.rgb * tint;
		ALPHA = t.a;
	}
}
