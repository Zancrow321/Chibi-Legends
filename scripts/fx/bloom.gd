class_name Bloom
extends WorldEnvironment
## Bloom for the 2D views: the viewport renders in HDR (use_hdr_2d), and only
## what is brighter than white glows. Effects get that brightness from
## FxSettings.boost() (sparks, swings, afterimages, fire, super beam); the
## white hit flash of a sprite (Color(4, 4, 4)) glows by itself. Normal
## pixel art stays at or below 1.0, so the scene itself does not bloom.
## Strength follows the effect level (V): Dezent / Kräftig / Maximal.

var room: Node2D


func _ready() -> void:
	add_to_group("bloom")
	get_viewport().use_hdr_2d = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = 0  # HUD and menus (higher layers) never bloom
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 2.0
	env.glow_bloom = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	for i in 7:
		env.set_glow_level(i, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.35)
	environment = env
	apply_level()


func apply_level() -> void:
	environment.glow_intensity = 0.9 * FxSettings.factor("bloom")
	environment.glow_strength = 1.0
	if room == null:
		return
	var b := FxSettings.boost()
	for n in [room.attacks, room.effects, room.fx.sparks, room.glut_fx]:
		if n != null:
			n.modulate = Color(b, b, b, 1.0)
