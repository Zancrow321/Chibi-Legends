class_name GodFx
extends Node2D
## Effekte der GOD-Teile an einer LayeredBody-Figur (siehe GodItems).
## Alles additiv mit Farben über 1.0, damit der Bloom es aufblühen lässt.
##  - Flügel (Talisman): zwei PixelLab-Flügelhälften schlagen am Rücken-Anker,
##    leuchtende Kopie darüber, Federn/Lichtfunken (Heilig) oder Glut und
##    Rauch (Dämon) rieseln heraus.
##  - Sonnenkrone: schwebender Heiligenschein mit drehendem Strahlenkranz.
##  - Hörnerkrone: schwarz-rote Flammen an beiden Hornspitzen.
##  - Oberteil: Aura hinter dem Körper, aufsteigende Funken.
##  - Hose: Bannkreis am Boden (Licht-Runen oder Höllenfeuer-Ring).
##  - Schuhe: Spuren beim Laufen (Lichtblüten oder Glutabdrücke).
##  - Waffen: Leuchtkopie der Klinge und Funkenschweif; Faust-Waffen: Auren
##    an beiden Händen.
##  - Ganze Serie (5 Kleidungsteile): „Erhebung“, Lichtsäule oder Höllentor.

const DIR := "res://assets/god/fx/"
const HOLY_HOT := Color(2.4, 2.1, 1.3)
const HOLY := Color(1.0, 0.86, 0.45)
const DEMON_HOT := Color(2.6, 0.5, 0.35)
const DEMON := Color(0.9, 0.08, 0.16)
## Faust-Auren je Waffe: [heiß, Grundfarbe]
const FIST_COLORS := {
	"god_sonnenfaeuste": [Color(2.6, 2.0, 0.9), Color(1.0, 0.75, 0.25)],
	"god_himmelswirbel": [Color(1.2, 2.2, 2.8), Color(0.55, 0.85, 1.0)],
	"god_hoellenfaust": [Color(2.8, 0.7, 0.2), Color(0.95, 0.2, 0.05)],
	"god_teufelsfeder": [Color(2.2, 0.3, 0.9), Color(0.6, 0.05, 0.3)],
}

var body: LayeredBody
var ids: Array = []
var style := ""

var _t := 0.0
var _nodes: Array = []
var _wings := []  # [links, rechts, leuchten links, leuchten rechts, serie]
var _halo: Sprite2D
var _halo_glow: Sprite2D
var _rays: _Rays
var _horns: Array = []
var _aura: Sprite2D
var _aura_sparks: CPUParticles2D
var _ring: _Ring
var _steps: CPUParticles2D
var _fists: Array = []
var _blade_glow: Sprite2D
var _blade_sparks: CPUParticles2D
var _ascend: _Pillar
var _prism: CPUParticles2D
var _last_pos := Vector2.INF
var _add: CanvasItemMaterial

static var _tex := {}
static var _dot: Texture2D


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var p := DIR + name + ".png"
		_tex[name] = load(p) if ResourceLoader.exists(p) else null
	return _tex[name]


## Weicher runder Lichtpunkt (für Auren und Funken ohne eigenes Bild).
static func dot() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_dot = t
	return _dot


func _ready() -> void:
	_add = CanvasItemMaterial.new()
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func setup(worn: Array, style_id: String) -> void:
	ids = worn.duplicate()
	style = style_id
	if _add == null:
		_ready()
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	_wings.clear()
	_horns.clear()
	_fists.clear()
	_halo = null
	_halo_glow = null
	_rays = null
	_aura = null
	_aura_sparks = null
	_ring = null
	_steps = null
	_blade_glow = null
	_blade_sparks = null
	_ascend = null
	_prism = null
	if body == null or body.rig() == null:
		return
	var full := GodItems.full_series(ids)
	if full != "":
		_make_ascend(full)
	for id in ids:
		var d := GodItems.info(id)
		var holy := str(d.get("series", "")) == GodItems.HOLY
		match str(d.get("fx", "")):
			"wings":
				_make_wings(holy)
			"halo":
				_make_halo()
			"horns":
				_make_horns()
			"radiance":
				_make_aura(holy)
			"motes":
				_make_ring(holy)
			"steps":
				_make_steps(holy)
			"fists":
				if str(d.get("style", "")) == style:
					_make_fists(id)
		if d.has("weapon") and str(d.get("style", "")) == style:
			_make_blade(holy)
	_make_prism()
	_process(0.0)


# Bausteine ---------------------------------------------------------------

func _own(n: Node, behind := false) -> Node:
	var rig := body.rig()
	rig.add_child(n)
	if behind:
		rig.move_child(n, 0)
	_nodes.append(n)
	return n


func _particles(amount: int, life: float, texture: Texture2D, additive := true) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.texture = texture
	p.local_coords = false
	if additive:
		p.material = _add
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return p


func _ramp(a: Color, b: Color, fade_in := false) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(a, 0.0) if fade_in else a)
	if fade_in:
		g.add_point(0.15, a)
	g.set_color(g.get_point_count() - 1, Color(b, 0.0))
	return g


func _make_wings(holy: bool) -> void:
	var t := tex("fluegel_heilig" if holy else "fluegel_daemon")
	if t == null:
		return
	var w := t.get_width()
	var h := t.get_height()
	var halves := []
	for glow in [false, true]:
		for side in [0, 1]:
			var s := Sprite2D.new()
			s.texture = t
			s.region_enabled = true
			s.region_rect = Rect2(0 if side == 0 else w / 2, 0, w / 2, h)
			s.centered = false
			# Drehpunkt an der Innenkante, auf Schulterhöhe
			s.offset = Vector2(-w / 2.0 if side == 0 else 0.0, -h * 0.55)
			s.scale = Vector2.ONE * 0.62
			if glow:
				s.material = _add
				s.modulate = Color(HOLY_HOT if holy else DEMON_HOT, 0.4)
			_own(s, true)
			halves.append(s)
	_wings.append([halves[0], halves[1], halves[2], halves[3], holy])
	# Federn / Glut aus den Flügeln
	var drift := _particles(22, 2.6, tex("feder" if holy else "glutfetzen"))
	drift.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	drift.emission_rect_extents = Vector2(34, 16)
	drift.gravity = Vector2(0, 16) if holy else Vector2(0, -26)
	drift.initial_velocity_min = 4.0
	drift.initial_velocity_max = 14.0
	drift.spread = 180.0
	drift.angular_velocity_min = -90.0
	drift.angular_velocity_max = 90.0
	drift.angle_min = -180.0
	drift.angle_max = 180.0
	drift.scale_amount_min = 0.5
	drift.scale_amount_max = 0.9
	drift.color_ramp = _ramp(HOLY_HOT if holy else DEMON_HOT, HOLY if holy else DEMON, true)
	_own(drift)
	_wings[-1].append(drift)
	var motes := _particles(30, 1.6, dot())
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(36, 18)
	motes.gravity = Vector2(0, -22)
	motes.initial_velocity_max = 8.0
	motes.scale_amount_min = 0.08
	motes.scale_amount_max = 0.22
	motes.color_ramp = _ramp(HOLY_HOT if holy else DEMON_HOT, HOLY if holy else DEMON, true)
	_own(motes)
	_wings[-1].append(motes)
	if not holy:  # schwarzer Rauch hinter den Schwingen
		var smoke := _particles(16, 2.2, dot(), false)
		smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		smoke.emission_rect_extents = Vector2(30, 12)
		smoke.gravity = Vector2(0, -14)
		smoke.scale_amount_min = 0.5
		smoke.scale_amount_max = 1.1
		var sc := Curve.new()
		sc.add_point(Vector2(0, 0.4))
		sc.add_point(Vector2(1, 1.0))
		smoke.scale_amount_curve = sc
		smoke.color_ramp = _ramp(Color(0.08, 0.02, 0.05, 0.55), Color(0.02, 0.0, 0.02), true)
		_own(smoke, true)
		_wings[-1].append(smoke)


func _make_halo() -> void:
	_rays = _Rays.new()
	_rays.color = Color(2.0, 1.7, 0.9, 0.35)
	_rays.material = _add
	_own(_rays, true)
	var t := tex("heiligenschein")
	if t != null:
		_halo = Sprite2D.new()
		_halo.texture = t
		_halo.scale = Vector2(0.5, 0.32)
		_own(_halo)
		_halo_glow = Sprite2D.new()
		_halo_glow.texture = t
		_halo_glow.material = _add
		_halo_glow.scale = _halo.scale * 1.15
		_halo_glow.modulate = Color(HOLY_HOT, 0.6)
		_own(_halo_glow)
	var sp := _particles(14, 1.2, dot())
	sp.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	sp.emission_ring_radius = 9.0
	sp.emission_ring_inner_radius = 7.0
	sp.gravity = Vector2(0, -10)
	sp.scale_amount_min = 0.06
	sp.scale_amount_max = 0.14
	sp.color_ramp = _ramp(Color(3, 2.6, 1.6), HOLY, true)
	_own(sp)
	_rays.set_meta("sparks", sp)


func _make_horns() -> void:
	for side in [-1, 1]:
		var fl := _particles(18, 0.7, tex("glutfetzen") if tex("glutfetzen") != null else dot())
		fl.gravity = Vector2(0, -60)
		fl.initial_velocity_min = 6.0
		fl.initial_velocity_max = 16.0
		fl.direction = Vector2(0, -1)
		fl.spread = 18.0
		fl.scale_amount_min = 0.35
		fl.scale_amount_max = 0.7
		fl.color_ramp = _ramp(Color(3.0, 0.9, 0.4), Color(0.3, 0.0, 0.05), false)
		fl.set_meta("side", side)
		_own(fl)
		_horns.append(fl)
	var smoke := _particles(10, 1.4, dot(), false)
	smoke.gravity = Vector2(0, -30)
	smoke.scale_amount_min = 0.25
	smoke.scale_amount_max = 0.5
	smoke.color_ramp = _ramp(Color(0.05, 0.0, 0.02, 0.6), Color(0, 0, 0), true)
	smoke.set_meta("side", 0)
	_own(smoke)
	_horns.append(smoke)


func _make_aura(holy: bool) -> void:
	_aura = Sprite2D.new()
	_aura.texture = dot()
	_aura.material = _add
	_aura.scale = Vector2(1.6, 2.2)
	_aura.modulate = Color(HOLY if holy else DEMON, 0.55)
	_own(_aura, true)
	_aura_sparks = _particles(26, 1.3, dot())
	_aura_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_aura_sparks.emission_rect_extents = Vector2(10, 16)
	_aura_sparks.gravity = Vector2(0, -40)
	_aura_sparks.initial_velocity_max = 10.0
	_aura_sparks.scale_amount_min = 0.05
	_aura_sparks.scale_amount_max = 0.16
	_aura_sparks.color_ramp = _ramp(HOLY_HOT if holy else DEMON_HOT, HOLY if holy else DEMON, true)
	_own(_aura_sparks)


func _make_ring(holy: bool) -> void:
	_ring = _Ring.new()
	_ring.holy = holy
	_ring.material = _add
	_own(_ring, true)


func _make_steps(holy: bool) -> void:
	_steps = _particles(28, 0.9 if holy else 1.4, tex("feder") if holy and tex("feder") != null else dot())
	_steps.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_steps.emission_rect_extents = Vector2(9, 1)
	_steps.direction = Vector2(0, -1)
	_steps.spread = 60.0
	_steps.initial_velocity_min = 8.0
	_steps.initial_velocity_max = 26.0
	_steps.gravity = Vector2(0, -12) if holy else Vector2(0, -30)
	_steps.scale_amount_min = 0.12 if not holy else 0.4
	_steps.scale_amount_max = 0.3 if not holy else 0.7
	_steps.color_ramp = _ramp(Color(2.6, 2.4, 1.5) if holy else Color(3, 0.7, 0.2), HOLY if holy else DEMON)
	_steps.emitting = false
	_own(_steps)


func _make_fists(id: String) -> void:
	var c: Array = FIST_COLORS.get(id, [HOLY_HOT, HOLY])
	for hand in ["hand_front", "hand_back"]:
		var glow := Sprite2D.new()
		glow.texture = dot()
		glow.material = _add
		glow.scale = Vector2.ONE * 0.7
		glow.modulate = Color(c[1], 0.8)
		_own(glow)
		var p := _particles(20, 0.55, dot())
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 4.0
		p.gravity = Vector2(0, -50) if id != "god_himmelswirbel" else Vector2.ZERO
		p.orbit_velocity_min = 0.6 if id == "god_himmelswirbel" else 0.0
		p.orbit_velocity_max = 1.2 if id == "god_himmelswirbel" else 0.0
		p.initial_velocity_max = 14.0
		p.spread = 180.0
		p.scale_amount_min = 0.08
		p.scale_amount_max = 0.22
		p.color_ramp = _ramp(c[0], c[1])
		_own(p)
		_fists.append([hand, glow, p])


func _make_blade(holy: bool) -> void:
	var w := body.weapon_sprite()
	if w == null:
		return
	_blade_glow = Sprite2D.new()
	_blade_glow.material = _add
	_blade_glow.centered = false
	_blade_glow.modulate = Color(HOLY_HOT if holy else DEMON_HOT, 0.45)
	_own(_blade_glow)
	_blade_sparks = _particles(40, 0.7, dot())
	_blade_sparks.gravity = Vector2(0, -20) if holy else Vector2(0, -45)
	_blade_sparks.initial_velocity_max = 10.0
	_blade_sparks.spread = 180.0
	_blade_sparks.scale_amount_min = 0.06
	_blade_sparks.scale_amount_max = 0.18
	_blade_sparks.color_ramp = _ramp(HOLY_HOT if holy else DEMON_HOT, HOLY if holy else DEMON)
	_own(_blade_sparks)


func _make_ascend(series: String) -> void:
	_ascend = _Pillar.new()
	_ascend.holy = series == GodItems.HOLY
	_ascend.material = _add
	_own(_ascend, true)


## Regenbogen-Glitzer: jedes GOD-Teil zeigt, dass es GOD ist.
func _make_prism() -> void:
	_prism = _particles(8 + 2 * ids.size(), 1.1, dot())
	_prism.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_prism.emission_rect_extents = Vector2(16, 24)
	_prism.gravity = Vector2(0, -8)
	_prism.scale_amount_min = 0.04
	_prism.scale_amount_max = 0.1
	var g := Gradient.new()
	g.set_color(0, Color(2.5, 1.2, 1.2, 0.0))
	g.add_point(0.2, Color(2.5, 2.2, 1.0))
	g.add_point(0.45, Color(1.0, 2.5, 1.4))
	g.add_point(0.7, Color(1.0, 1.6, 2.8))
	g.set_color(g.get_point_count() - 1, Color(2.2, 1.0, 2.6, 0.0))
	_prism.color_ramp = g
	_own(_prism)


# Jedes Bild ----------------------------------------------------------------

func _process(delta: float) -> void:
	if body == null or body.rig() == null:
		return
	_t += delta
	var back := body.anchor("back")
	var head := body.anchor("head")
	var chest := back.lerp(Vector2.ZERO, 0.35)
	# Flügel: Schlag mit Ausholen, beim Rennen weiter zurückgelegt
	var moving := false
	var gp := body.global_position
	if _last_pos != Vector2.INF and delta > 0.0:
		moving = gp.distance_to(_last_pos) / delta > 30.0
	_last_pos = gp
	for wg in _wings:
		var holy: bool = wg[4]
		var speed := 3.2 if holy else 2.4
		var flap := sin(_t * speed) * (0.28 if holy else 0.2) + (0.18 if moving else 0.0)
		var base := back + Vector2(1, 2)
		for i in 4:
			var s: Sprite2D = wg[i]
			var left := i % 2 == 0
			s.position = base + Vector2(0, sin(_t * speed) * 1.5)
			s.rotation = (-flap if left else flap)
			s.scale = Vector2(0.62, 0.62 + 0.04 * sin(_t * speed * 2.0))
			if i >= 2:
				s.modulate.a = 0.3 + 0.2 * sin(_t * 4.0 + (0.0 if left else 1.0))
		for i in range(5, wg.size()):
			(wg[i] as Node2D).position = base + Vector2(0, -8)
	if _rays != null:
		_rays.position = head + Vector2(0, -6)
		_rays.angle = _t * 0.6
		var sp: CPUParticles2D = _rays.get_meta("sparks")
		sp.position = head + Vector2(0, -18 + sin(_t * 2.0) * 1.5)
	if _halo != null:
		_halo.position = head + Vector2(0, -18 + sin(_t * 2.0) * 1.5)
		_halo_glow.position = _halo.position
		_halo_glow.modulate.a = 0.45 + 0.3 * sin(_t * 3.0)
	for h in _horns:
		var side := int(h.get_meta("side"))
		h.position = head + Vector2(side * 6, -12 if side != 0 else -14)
	if _aura != null:
		_aura.position = chest
		_aura.modulate.a = 0.45 + 0.2 * sin(_t * 2.5)
		_aura_sparks.position = chest
	if _ring != null:
		_ring.position = Vector2(0, 0)
		_ring.t = _t
	if _steps != null:
		_steps.position = Vector2(0, -1)
		_steps.emitting = moving
	for f in _fists:
		var p := body.anchor(f[0])
		(f[1] as Sprite2D).position = p
		(f[1] as Sprite2D).scale = Vector2.ONE * (0.6 + 0.12 * sin(_t * 9.0))
		(f[2] as CPUParticles2D).position = p
	if _blade_glow != null:
		var w := body.weapon_sprite()
		_blade_glow.visible = w != null
		if w != null:
			_blade_glow.texture = w.texture
			_blade_glow.transform = w.transform
			_blade_glow.offset = w.offset
			_blade_glow.modulate.a = 0.35 + 0.25 * sin(_t * 6.0)
			var g: Array = body._wdata.get("grip", [0, 0])
			var tp: Array = body._wdata.get("tip", [0, 0])
			var along := Vector2(g[0], g[1]).lerp(Vector2(tp[0], tp[1]), randf_range(0.3, 1.0)) - Vector2(g[0], g[1])
			_blade_sparks.position = w.transform * along
	if _ascend != null:
		_ascend.t = _t
	if _prism != null:
		_prism.position = Vector2(0, -24)


## Drehender Strahlenkranz hinter dem Kopf (Sonnenkrone).
class _Rays:
	extends Node2D
	var angle := 0.0
	var color := Color(2, 1.7, 0.9, 0.35)

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		for k in 12:
			var a := angle + k * TAU / 12.0
			var l := 22.0 + 6.0 * sin(angle * 5.0 + k)
			var p := PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a - 0.08) * l, Vector2.from_angle(a + 0.08) * l])
			draw_colored_polygon(p, Color(color, color.a * (0.6 + 0.4 * sin(angle * 3.0 + k * 1.7))))


## Bannkreis am Boden: Licht-Runen (Heilig) oder Höllenfeuer-Ring (Dämon).
class _Ring:
	extends Node2D
	var holy := true
	var t := 0.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _ellipse(r: float, col: Color, width: float) -> void:
		var pts := PackedVector2Array()
		for i in 33:
			var a := i * TAU / 32.0
			pts.append(Vector2(cos(a) * r, sin(a) * r * 0.28))
		draw_polyline(pts, col, width)

	func _draw() -> void:
		var hot := Color(2.4, 2.0, 1.0) if holy else Color(2.6, 0.4, 0.2)
		var base := Color(1.0, 0.8, 0.35) if holy else Color(0.9, 0.05, 0.1)
		var pulse := 0.6 + 0.4 * sin(t * 3.0)
		_ellipse(22.0, Color(hot, 0.55 * pulse), 1.5)
		_ellipse(17.0, Color(base, 0.45), 1.0)
		# Runen / Flammenzungen auf dem Ring
		for k in 10:
			var a := (t * (0.8 if holy else -1.1)) + k * TAU / 10.0
			var p := Vector2(cos(a) * 19.5, sin(a) * 19.5 * 0.28)
			if holy:
				draw_line(p + Vector2(-1.5, 0), p + Vector2(1.5, 0), Color(hot, 0.8), 1.0)
				draw_line(p + Vector2(0, -1.5), p + Vector2(0, 1.5), Color(hot, 0.8), 1.0)
			else:
				var h := 4.0 + 3.0 * sin(t * 9.0 + k * 2.3)
				draw_colored_polygon(PackedVector2Array([p + Vector2(-1.5, 0), p + Vector2(0, -h), p + Vector2(1.5, 0)]), Color(hot, 0.75))


## „Erhebung“: ganze Serie getragen. Heilig: Lichtsäule von oben,
## Dämon: Höllentor mit aufsteigenden Flammen hinter der Figur.
class _Pillar:
	extends Node2D
	var holy := true
	var t := 0.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var hot := Color(2.0, 1.8, 1.1) if holy else Color(2.4, 0.3, 0.2)
		var pulse := 0.7 + 0.3 * sin(t * 2.0)
		if holy:
			for k in 6:  # Lichtsäule aus Streifen, außen schwächer
				var w := 30.0 - k * 5.0
				draw_rect(Rect2(-w * 0.5, -260, w, 260), Color(hot, 0.05 * pulse * (k + 1)))
			for k in 5:  # fallende Lichtstreifen
				var y := fposmod(t * 90.0 + k * 52.0, 260.0) - 260.0
				draw_rect(Rect2(-12 + k * 6 - 12, y, 2, 26), Color(hot, 0.35))
		else:
			for k in 5:  # Höllentor: Bogen aus Flammenzungen
				var r := 34.0 - k * 4.0
				var pts := PackedVector2Array()
				for i in 25:
					var a := PI + i * PI / 24.0
					var f := 1.0 + 0.12 * sin(t * 8.0 + i * 1.3 + k)
					pts.append(Vector2(cos(a) * r * f, -20.0 + sin(a) * r * 1.4 * f))
				draw_polyline(pts, Color(hot, 0.1 + 0.05 * k * pulse), 3.0)
			for k in 7:
				var x := -26.0 + k * 8.7
				var h := 18.0 + 10.0 * sin(t * 7.0 + k * 1.9)
				draw_colored_polygon(PackedVector2Array([Vector2(x - 3, 0), Vector2(x, -h), Vector2(x + 3, 0)]), Color(hot, 0.4))
