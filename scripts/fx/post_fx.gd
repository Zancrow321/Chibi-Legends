class_name PostFx
extends CanvasLayer
## Screen shader over the play area (shaders/post/post_fx.gdshader): colour
## grading and vignette per area mood, shockwave rings and chromatic
## aberration for big hits and supers, heat haze over fire (forge, burning
## ground, the hot Glutatem blade). Sits above the world and the parallax
## foreground, below every HUD (layer 10+), so text stays sharp.
##
## Anyone can call the static helpers (PostFx.shockwave(...)); they do
## nothing when no PostFx is in the scene. Follows the graphics preset
## (Hd2dSettings: Niedrig = off, Mittel = no heat haze, Hoch = everything).

const LAYER := 4
const MAX_WAVES := 4
const MAX_HEAT := 6

## Moods: grading values per area. Kept gentle: the pixel art stays itself.
## The filmic part (curve, split toning, sky light, ground haze, vibrance)
## came with the post-processing pass; "legacy" shows the old look.
const MOODS := {
	# training forest at dusk: violet shadows, glowing orange lights, blue mist at the ground
	"dusk": {"exposure": 1.05, "contrast": 1.06, "saturation": 1.06, "lift": Color(0.03, 0.01, 0.06), "gain": Color(1.04, 0.98, 0.93), "vignette": 0.46, "vcol": Color(0.04, 0.0, 0.08),
		"filmic": 1.0, "shadow": Color(0.05, -0.01, 0.09), "high": Color(0.08, 0.035, -0.04), "vibrance": 0.45,
		"sky": Color(1.0, 0.55, 0.3, 0.22), "haze": Color(0.36, 0.3, 0.6, 0.3), "haze_h": 0.36},
	# academy courtyard by day: clean, warm sunlight from above, light blue air
	"day": {"exposure": 1.03, "contrast": 1.04, "saturation": 1.06, "lift": Color(0.015, 0.015, 0.035), "gain": Color(1.03, 1.0, 0.96), "vignette": 0.24, "vcol": Color(0.08, 0.05, 0.14),
		"filmic": 0.85, "shadow": Color(-0.015, 0.02, 0.06), "high": Color(0.06, 0.035, -0.015), "vibrance": 0.4,
		"sky": Color(1.0, 0.9, 0.65, 0.2), "haze": Color(0.62, 0.74, 0.92, 0.18), "haze_h": 0.3},
	# raid Glutschmiede: deep red shadows, molten highlights, smoke at the ground
	"ember": {"exposure": 1.04, "contrast": 1.1, "saturation": 1.08, "lift": Color(0.05, 0.008, 0.01), "gain": Color(1.06, 0.97, 0.88), "vignette": 0.55, "vcol": Color(0.08, 0.0, 0.01),
		"filmic": 0.9, "shadow": Color(0.06, 0.0, -0.01), "high": Color(0.06, 0.03, -0.04), "vibrance": 0.3,
		"sky": Color(1.0, 0.45, 0.15, 0.12), "haze": Color(0.32, 0.08, 0.05, 0.3), "haze_h": 0.3},
	# endless tower: arcane violet darks, cool cyan lights
	"arcane": {"exposure": 1.04, "contrast": 1.08, "saturation": 1.04, "lift": Color(0.03, 0.01, 0.07), "gain": Color(0.98, 1.0, 1.05), "vignette": 0.5, "vcol": Color(0.03, 0.0, 0.09),
		"filmic": 0.85, "shadow": Color(0.04, -0.01, 0.08), "high": Color(-0.02, 0.03, 0.05), "vibrance": 0.35,
		"sky": Color(0.6, 0.5, 1.0, 0.14), "haze": Color(0.3, 0.18, 0.5, 0.24), "haze_h": 0.3},
	"flat": {"exposure": 1.0, "contrast": 1.05, "saturation": 1.05, "lift": Color(0.02, 0.02, 0.03), "gain": Color(1.0, 1.0, 1.0), "vignette": 0.32, "vcol": Color(0.02, 0.03, 0.05),
		"filmic": 0.6, "shadow": Color(0.0, 0.01, 0.03), "high": Color(0.03, 0.02, 0.0), "vibrance": 0.25,
		"sky": Color(1.0, 0.95, 0.85, 0.08), "haze": Color(0.5, 0.6, 0.7, 0.1), "haze_h": 0.25},
}

## Old values (before the filmic pass), for the before/after probe.
const LEGACY := {
	"dusk": {"exposure": 1.04, "contrast": 1.08, "saturation": 1.12, "lift": Color(0.035, 0.012, 0.06), "gain": Color(1.04, 0.98, 0.94), "vignette": 0.42, "vcol": Color(0.03, 0.0, 0.07)},
	"day": {"exposure": 1.02, "contrast": 1.05, "saturation": 1.1, "lift": Color(0.02, 0.015, 0.04), "gain": Color(1.03, 1.0, 0.96), "vignette": 0.22, "vcol": Color(0.08, 0.04, 0.12)},
	"flat": {"exposure": 1.0, "contrast": 1.06, "saturation": 1.08, "lift": Color(0.02, 0.02, 0.03), "gain": Color(1.0, 1.0, 1.0), "vignette": 0.3, "vcol": Color(0.02, 0.03, 0.04)},
}

## Which mood an area wears (2D views).
const AREA_MOODS := {"trainingswald": "dusk", "akademie_hof": "day", "glutschmiede": "ember", "turm": "arcane"}

## true = the look before the post-processing pass (probe: vorher/nachher).
static var legacy := false

static var _inst: PostFx

var mood := "flat"
var _rect: ColorRect
var _mat: ShaderMaterial
var _waves: Array = []  # {pos (world), t, life, strength, speed}
var _heat_bursts: Array = []  # {pos, radius, strength, t, life}
var _heat_sources: Array = []  # {node, offset, radius, strength (Callable or float)}
var _aberration := 0.0
var _hold_ca := 0.0  # steady aberration (super pause)
var _impact := 0.0  # manga impact frame, counts down in seconds
var _impact_len := 0.0
var _blur := 0.0  # radial zoom blur strength
var _blur_hold := 0.0  # steady blur while a super holds the screen
var _blur_pos := Vector2.ZERO  # world position of the blur centre
var _punch := 0.0
var _danger := 0.0
## The fighter whose HP drives the danger pulse (needs hp and max_hp). null = none.
var hp_player: Node


func _init() -> void:
	layer = LAYER


func _ready() -> void:
	_inst = self
	add_to_group("hd2d_view")  # apply_quality() runs once; quality is fixed at Hoch
	process_mode = Node.PROCESS_MODE_ALWAYS  # rings keep running during hit-stop
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/post/post_fx.gdshader")
	_rect.material = _mat
	add_child(_rect)
	set_mood(mood)
	apply_quality()


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


func set_mood(m: String) -> void:
	mood = m
	var table: Dictionary = LEGACY if legacy else MOODS
	var d: Dictionary = table.get(m, table.get("dusk" if m in ["ember", "arcane"] else "flat"))
	_mat.set_shader_parameter("exposure", d.exposure)
	_mat.set_shader_parameter("contrast", d.contrast)
	_mat.set_shader_parameter("saturation", d.saturation)
	_mat.set_shader_parameter("lift", _v3(d.lift))
	_mat.set_shader_parameter("gain", _v3(d.gain))
	_mat.set_shader_parameter("vignette", d.vignette)
	_mat.set_shader_parameter("vignette_color", _v3(d.vcol))
	_mat.set_shader_parameter("filmic", d.get("filmic", 0.0))
	_mat.set_shader_parameter("shadow_tint", _v3(d.get("shadow", Color(0, 0, 0))))
	_mat.set_shader_parameter("highlight_tint", _v3(d.get("high", Color(0, 0, 0))))
	_mat.set_shader_parameter("vibrance", d.get("vibrance", 0.0))
	var sky: Color = d.get("sky", Color(0, 0, 0, 0))
	var haze: Color = d.get("haze", Color(0, 0, 0, 0))
	_mat.set_shader_parameter("sky_light", Vector4(sky.r, sky.g, sky.b, sky.a))
	_mat.set_shader_parameter("ground_haze", Vector4(haze.r, haze.g, haze.b, haze.a))
	_mat.set_shader_parameter("haze_height", d.get("haze_h", 0.3))
	_mat.set_shader_parameter("dither", 0.0 if legacy else 1.0)


static func _v3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


func apply_quality() -> void:
	var q := Hd2dSettings.quality
	visible = q > 0
	_mat.set_shader_parameter("heat_on", 1.0 if q >= 2 else 0.0)


static func enabled() -> bool:
	return _inst != null and _inst.visible


# --- static helpers --------------------------------------------------------------

## A ring that runs outwards from a world position. strength ~1 = big hit,
## 2 = super finisher. Scaled by the effect level (V).
static func shockwave(world_pos: Vector2, strength := 1.0, speed := 1.0, life := 0.55) -> void:
	if not enabled():
		return
	var s := strength * FxSettings.factor("shake") * 0.8 + strength * 0.2
	_inst._waves.append({"pos": world_pos, "t": 0.0, "life": life, "strength": s, "speed": speed})
	while _inst._waves.size() > MAX_WAVES:
		_inst._waves.pop_front()


## A short colour split (screen pixels), fades out by itself.
static func aberrate(amount: float) -> void:
	if not enabled():
		return
	_inst._aberration = maxf(_inst._aberration, amount * FxSettings.factor("flash"))


## Steady colour split while a super holds the screen (0 = off).
static func hold_aberration(amount: float) -> void:
	if _inst != null:
		_inst._hold_ca = amount


## Manga impact frame: for a moment the world turns into ink and paper
## for a few frames, like a panel in a fighting manga. For super
## finishers and Meisterzug hits. Scaled by the flash level.
static func impact_frame(seconds := 0.07, ink := Color(0.04, 0.02, 0.06), paper := Color(1.0, 0.96, 0.9)) -> void:
	if not enabled() or legacy or FxSettings.factor("flash") <= 0.05:
		return
	_inst._impact = seconds
	_inst._impact_len = seconds
	_inst._mat.set_shader_parameter("impact_ink", _v3(ink))
	_inst._mat.set_shader_parameter("impact_paper", _v3(paper))


## Radial zoom blur towards a world position (super start, big finisher).
static func zoom_blur(world_pos: Vector2, strength := 1.0) -> void:
	if not enabled() or legacy:
		return
	_inst._blur_pos = world_pos
	_inst._blur = maxf(_inst._blur, strength * FxSettings.factor("flash"))


## Steady zoom blur while a super holds the screen (0 = off).
static func hold_zoom_blur(world_pos: Vector2, strength: float) -> void:
	if _inst == null or legacy:
		return
	_inst._blur_pos = world_pos
	_inst._blur_hold = strength


## Short exposure punch (big hits glow brighter for a few frames).
static func exposure_punch(amount := 1.0) -> void:
	if not enabled() or legacy:
		return
	_inst._punch = maxf(_inst._punch, amount * FxSettings.factor("flash"))


## A short burst of heat haze (explosion, fire impact).
static func heat_burst(world_pos: Vector2, radius := 60.0, strength := 1.0, life := 0.8) -> void:
	if not enabled():
		return
	_inst._heat_bursts.append({"pos": world_pos, "radius": radius, "strength": strength, "t": 0.0, "life": life})
	while _inst._heat_bursts.size() > MAX_HEAT:
		_inst._heat_bursts.pop_front()


## Heat haze that follows a node while it lives. strength may be a Callable
## returning a float (for example the heat of the blade).
static func add_heat_source(node: Node2D, offset: Vector2, radius: float, strength: Variant = 1.0) -> void:
	if _inst == null:
		return
	_inst._heat_sources.append({"node": node, "offset": offset, "radius": radius, "strength": strength})


# --- per frame ----------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var ct := vp.get_canvas_transform()
	var zoom := ct.get_scale().x
	_mat.set_shader_parameter("aspect", size.x / size.y)
	# screen pixels per art pixel: camera zoom times window stretch
	var stretch := vp.get_final_transform().get_scale().x
	_mat.set_shader_parameter("art_px", maxf(1.0, round(zoom * stretch)))

	var waves: Array = []
	for w in _waves:
		w.t += delta
	_waves = _waves.filter(func(w): return w.t < w.life)
	for w in _waves:
		var k: float = w.t / w.life
		var uv: Vector2 = (ct * (w.pos as Vector2)) / size
		var radius: float = (0.04 + 0.5 * (1.0 - pow(1.0 - k, 2.2))) * w.speed * (zoom / 2.0)
		waves.append(Vector4(uv.x, uv.y, radius, w.strength * (1.0 - k) * (1.0 - k)))
	while waves.size() < MAX_WAVES:
		waves.append(Vector4.ZERO)
	_mat.set_shader_parameter("waves", waves)

	var heat: Array = []
	for b in _heat_bursts:
		b.t += delta
	_heat_bursts = _heat_bursts.filter(func(b): return b.t < b.life)
	_heat_sources = _heat_sources.filter(func(h): return is_instance_valid(h.node) and h.node.is_inside_tree())
	var items: Array = []
	for h in _heat_sources:
		var s: float = h.strength.call() if h.strength is Callable else float(h.strength)
		if s > 0.01:
			items.append([(h.node as Node2D).global_position + h.offset, h.radius, s])
	for b in _heat_bursts:
		var k2: float = b.t / b.life
		items.append([b.pos, b.radius, b.strength * (1.0 - k2)])
	for it in items:
		if heat.size() >= MAX_HEAT:
			break
		var uv2: Vector2 = (ct * (it[0] as Vector2)) / size
		if uv2.x < -0.3 or uv2.x > 1.3 or uv2.y < -0.3 or uv2.y > 1.3:
			continue
		heat.append(Vector4(uv2.x, uv2.y, it[1] * zoom / size.y, it[2]))
	while heat.size() < MAX_HEAT:
		heat.append(Vector4.ZERO)
	_mat.set_shader_parameter("heat", heat)

	_aberration = maxf(0.0, _aberration - delta * (6.0 + _aberration * 3.0))
	_mat.set_shader_parameter("aberration", _aberration + _hold_ca)

	# impact frame: a hard cut to ink on paper for a few frames, then straight back
	if _impact > 0.0:
		_impact = maxf(0.0, _impact - delta)
	_mat.set_shader_parameter("impact", 1.0 if _impact > 0.0 else 0.0)
	_mat.set_shader_parameter("impact_invert", 0.0)

	_blur = maxf(0.0, _blur - delta * 6.0)
	var blur := maxf(_blur, _blur_hold)
	var buv: Vector2 = (ct * _blur_pos) / size
	_mat.set_shader_parameter("zoom_blur", Vector3(buv.x, buv.y, blur))

	_punch = maxf(0.0, _punch - delta * 6.0)
	_mat.set_shader_parameter("punch", _punch)

	# low HP: below 30 % the edge starts to breathe red
	var target := 0.0
	if not legacy and is_instance_valid(hp_player):
		var frac := float(hp_player.get("hp")) / maxf(float(hp_player.get("max_hp")), 1.0)
		target = clampf((0.3 - frac) / 0.25, 0.0, 1.0) if frac > 0.0 else 0.0
	_danger = move_toward(_danger, target, delta * 1.5)
	_mat.set_shader_parameter("danger", _danger)
