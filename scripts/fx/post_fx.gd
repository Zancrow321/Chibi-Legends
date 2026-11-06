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
const MOODS := {
	"dusk": {"exposure": 1.04, "contrast": 1.08, "saturation": 1.12, "lift": Color(0.035, 0.012, 0.06), "gain": Color(1.04, 0.98, 0.94), "vignette": 0.42, "vcol": Color(0.03, 0.0, 0.07)},
	"day": {"exposure": 1.02, "contrast": 1.05, "saturation": 1.1, "lift": Color(0.02, 0.015, 0.04), "gain": Color(1.03, 1.0, 0.96), "vignette": 0.22, "vcol": Color(0.08, 0.04, 0.12)},
	"flat": {"exposure": 1.0, "contrast": 1.06, "saturation": 1.08, "lift": Color(0.02, 0.02, 0.03), "gain": Color(1.0, 1.0, 1.0), "vignette": 0.3, "vcol": Color(0.02, 0.03, 0.04)},
}

static var _inst: PostFx

var mood := "flat"
var _rect: ColorRect
var _mat: ShaderMaterial
var _waves: Array = []  # {pos (world), t, life, strength, speed}
var _heat_bursts: Array = []  # {pos, radius, strength, t, life}
var _heat_sources: Array = []  # {node, offset, radius, strength (Callable or float)}
var _aberration := 0.0
var _hold_ca := 0.0  # steady aberration (super pause)


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
	var d: Dictionary = MOODS.get(m, MOODS.flat)
	_mat.set_shader_parameter("exposure", d.exposure)
	_mat.set_shader_parameter("contrast", d.contrast)
	_mat.set_shader_parameter("saturation", d.saturation)
	_mat.set_shader_parameter("lift", Vector3(d.lift.r, d.lift.g, d.lift.b))
	_mat.set_shader_parameter("gain", Vector3(d.gain.r, d.gain.g, d.gain.b))
	_mat.set_shader_parameter("vignette", d.vignette)
	_mat.set_shader_parameter("vignette_color", Vector3(d.vcol.r, d.vcol.g, d.vcol.b))


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
