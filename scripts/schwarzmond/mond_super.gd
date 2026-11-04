class_name MondSuper
extends Node2D
## Meisterzug of Schwarzmond (3 Stufen of the Legendenleiste). Common intro
## ("großes Bild"): a close look at the blade, then a black crescent over
## white; when it ends the colour snaps back. Then one of three variants:
##  neumond         the blade condenses: 8 s faster Züge, shorter cooldowns
##  blutmond        the Schattenlarve closes, a huge black-red crescent rolls
##                  in a straight line over the whole width (visible wind-up)
##  mondfinsternis  once per fight: the world goes black, a white corona,
##                  one giant cut over the whole view; afterwards everything
##                  is spent and the style is exhausted for 10 s
## The Schattenlarve starts after the super (not after Mondfinsternis).

const INTRO := 0.75
const PANEL_FROM := 0.22
const PANEL_TO := 0.55

var room: TrainingRoom
var player: Player
var caster: MondCaster
var fx: GlutFx
var variant := "neumond"
var title := "Meisterzug"

var phase := "intro"
var _t := 0.0
var _all := 0.0
var _step := 0
var _target: Node2D = null
var _dealt: Dictionary = {}
var _emit := 0.0
var _add: Node2D
var _wave_x := 0.0
var _wave_y := 0.0
var _wave_hit: Dictionary = {}
var _cut_y := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = CombatFx.FOCUS_Z + 2
	var im := CanvasItemMaterial.new()
	im.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = im
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_add = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_add.material = m
	_add.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_add.draw.connect(_draw_add)
	add_child(_add)
	player.z_index = CombatFx.FOCUS_Z
	player.sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	caster.mfx.z_index = CombatFx.FOCUS_Z + 1
	caster.mfx.process_mode = Node.PROCESS_MODE_ALWAYS
	var cfx := room.fx
	cfx.hold(true)
	cfx.dim(0.85)
	cfx.punch(0.2)
	cfx.flash(0.25 * FxSettings.factor("flash"), Color(0.8, 0.9, 1.0))
	if room.hud != null:
		room.hud.show_cutin(title + "!", MondFx.RED if variant == "blutmond" else MondFx.CYAN)
	_target = _nearest(340.0)
	if _target != null:
		player.facing = 1 if _target.global_position.x >= player.global_position.x else -1
	if variant == "blutmond":
		caster.start_larve()


# --- helpers ---------------------------------------------------------------------

func _view() -> Rect2:
	var cam := room.camera
	var size := get_viewport_rect().size / cam.zoom
	return Rect2(cam.get_screen_center_position() - size / 2.0, size)


func _targets() -> Array:
	return room.get_tree().get_nodes_in_group("targets")


func _nearest(max_d: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_d
	for t in _targets():
		var d: float = absf(t.global_position.x - player.global_position.x) + absf(t.global_position.y - player.global_position.y) * 0.5
		if d < best_d:
			best = t
			best_d = d
	return best


func _hit(t: Node2D, dmg: float, kb := 60.0, prof := "super", launch := 0.0) -> void:
	var dealt := room.deal_hit(t, dmg, "", player.global_position.x, kb, prof, launch)
	var id := t.get_instance_id()
	if not _dealt.has(id):
		_dealt[id] = [t, 0]
	_dealt[id][1] += dealt
	player.on_attack_hit()
	if t.has_method("posture_hit"):
		t.posture_hit(dmg * 2.0, player.global_position.x)


func _show_totals(col := MondFx.WHITE) -> void:
	for id in _dealt:
		var e: Array = _dealt[id]
		if is_instance_valid(e[0]) and e[1] > 0:
			room.numbers.spawn_number(e[0].head_position() + Vector2(0, -14), e[1], col, id + 1, true)
	_dealt.clear()


func _set_pose(f: int) -> void:
	player.sprite.scale.x = player.facing
	player.sprite.set_state("attack")
	player.sprite.attack_frame = f


func _next(p: String) -> void:
	phase = p
	_t = 0.0
	_step = 0


# --- main loop ------------------------------------------------------------------

func _process(delta: float) -> void:
	if phase != "intro" and phase != "eclipse" and room.fx.is_frozen():
		queue_redraw()
		_add.queue_redraw()
		return
	_t += delta
	_all += delta
	match phase:
		"intro":
			_intro(delta)
		"form":
			_neumond_form(delta)
		"charge":
			_blut_charge(delta)
		"wave":
			_blut_wave(delta)
		"eclipse":
			_eclipse(delta)
		"cut":
			_eclipse_cut()
		"end":
			if _t >= 0.4:
				_finish()
	queue_redraw()
	_add.queue_redraw()


func _intro(delta: float) -> void:
	# shoulder pose, then the blade comes forward; Mondlast is drawn in
	_set_pose(6 if _t < 0.3 else 2)
	_emit -= delta
	if _emit <= 0.0 and _t < PANEL_FROM:
		_emit = 0.02
		var c := player.global_position + Vector2(0, -24)
		for i in 2:
			var a := randf() * TAU
			var from := c + Vector2(cos(a), sin(a)) * randf_range(40, 80)
			fx.glow(from, Color(caster.rim_color(), 0.8), randf_range(2.0, 4.0), 0.22, (c - from) / 0.22, 0.3)
	if _t >= PANEL_TO and _step == 0:
		_step = 1
		room.fx.flash(0.5 * FxSettings.factor("flash"), Color.WHITE)
		room.fx.punch(0.08)
		Sfx.play("hit_heavy")
	if _t >= INTRO:
		room.fx.hold(false)
		room.fx.dim(0.6)
		match variant:
			"blutmond":
				_next("charge")
			"mondfinsternis":
				room.fx.hold(true)
				room.fx.dim(1.0)
				_next("eclipse")
			_:
				_next("form")


func _finish() -> void:
	_show_totals()
	room.fx.dim(0.0)
	room.fx.hold(false)
	player.z_index = 0
	player.in_super = false
	player.sprite.modulate = Color.WHITE
	player.sprite.process_mode = Node.PROCESS_MODE_INHERIT
	caster.mfx.z_index = 4
	caster.mfx.process_mode = Node.PROCESS_MODE_INHERIT
	if variant != "mondfinsternis":
		caster.start_larve()
		var h := caster.head_pos()
		fx.word(h + Vector2(0, -26), "LARVE", MondFx.EMBER, 16)
	queue_free()


# --- Neumond ------------------------------------------------------------------------

func _neumond_form(_delta: float) -> void:
	_set_pose(6)
	var c := player.global_position + Vector2(0, -22)
	if _step == 0:
		_step = 1
		caster.start_neumond(8.0)
		caster.mfx.shock(c + Vector2(0, 20), 70.0, 0.5, MondFx.WHITE)
		caster.mfx.ink(c, 30, 200.0, 0.8)
		caster.mfx.streaks(c, -PI / 2.0, PI, 26, 320.0, 0.45, MondFx.WHITE)
		fx.word(c + Vector2(0, -50), "NEUMOND", MondFx.WHITE, 30)
		room.fx.shake(6.0 * FxSettings.factor("shake"))
		fx.light(c, Color(0.8, 0.9, 1.0), 3.0, 1.0, 0.4)
	if _t >= 0.6:
		_next("end")


# --- Blutmond -----------------------------------------------------------------------

func _blut_charge(delta: float) -> void:
	# hand before the face, then the blade drawn back: a clear wind-up
	_set_pose(5 if _t < 0.45 else 1)
	var c := player.global_position + Vector2(-player.facing * 8.0, -26)
	_emit -= delta
	if _emit <= 0.0:
		_emit = 0.025
		var a := randf() * TAU
		var from := c + Vector2(cos(a), sin(a)) * randf_range(30, 70)
		fx.glow(from, Color(MondFx.RED, 0.9), randf_range(2.0, 5.0), 0.25, (c - from) / 0.25, 0.3)
		caster.mfx.ink(c + Vector2(randf_range(-20, 20), randf_range(-20, 20)), 1, 40.0, 0.4)
	fx.light(c, MondFx.EMBER, 1.0 + _t * 3.0, 0.6, 0.05)
	if _t >= 0.7:
		_next("wave")
		_wave_x = player.global_position.x + player.facing * 20.0
		_wave_y = player.global_position.y - 40.0
		_set_pose(3)
		room.fx.shake(10.0 * FxSettings.factor("shake"), player.facing)
		room.fx.flash(0.18 * FxSettings.factor("flash"), Color(1.0, 0.3, 0.35))
		fx.word(player.global_position + Vector2(player.facing * 50.0, -70), "DOOOM!", MondFx.EMBER, 40)


func _blut_wave(delta: float) -> void:
	_set_pose(4)
	var speed := 620.0
	_wave_x += player.facing * speed * delta
	var area := Rect2(_wave_x - 36.0, _wave_y - 60.0, 72.0, 110.0)
	for t in _targets():
		var id: int = t.get_instance_id()
		if _wave_hit.has(id) or not area.intersects(t.get_hurt_rect()):
			continue
		_wave_hit[id] = true
		_hit(t, 30.0, 40.0, "super")
		_hit(t, 24.0, 300.0, "super_final", 220.0)
		caster.mfx.ink(t.get_hurt_rect().get_center(), 16, 160.0, 0.6)
		room.fx.freeze(0.05 * FxSettings.factor("stop"))
	_emit -= delta
	if _emit <= 0.0:
		_emit = 0.02
		caster.mfx.ink(Vector2(_wave_x - player.facing * 30.0, _wave_y + randf_range(-50, 50)), 2, 60.0, 0.5)
		fx.light(Vector2(_wave_x, _wave_y), MondFx.EMBER, 2.5, 0.9, 0.06)
	var v := _view()
	if _wave_x > v.end.x + 80.0 or _wave_x < v.position.x - 80.0 or _t > 1.6:
		_next("end")


# --- Mondfinsternis --------------------------------------------------------------------

func _eclipse(delta: float) -> void:
	_set_pose(6 if _t < 0.6 else 1)
	player.sprite.modulate = Color(0.05, 0.05, 0.08).lerp(Color.WHITE, 0.0)
	if _t >= 0.9:
		_next("cut")
		_cut_y = player.global_position.y - 24.0
		room.fx.hold(false)


func _eclipse_cut() -> void:
	_set_pose(4)
	if _step == 0:
		_step = 1
		var v := _view()
		for t in _targets():
			if v.grow(40).intersects(t.get_hurt_rect()):
				_hit(t, 40.0, 60.0, "super")
				_hit(t, 56.0, 320.0, "super_final", 260.0)
				caster.mfx.ink(t.get_hurt_rect().get_center(), 20, 200.0, 0.8)
		room.fx.flash(0.9 * FxSettings.factor("flash"), Color.WHITE)
		room.fx.shake(12.0 * FxSettings.factor("shake"))
		room.fx.freeze(0.12 * FxSettings.factor("stop"))
		room.fx.dim(0.0)
		player.sprite.modulate = Color.WHITE
		fx.word(player.global_position + Vector2(0, -70), "ZAAASH!", MondFx.WHITE, 44)
		# everything is spent
		caster.stage = 0
		caster.larve_time = 0.0
		caster.neumond_time = 0.0
		caster.erschoepft = 10.0
		caster.eclipse_used = true
		player.gauge = 0.0
	if _t >= 0.5:
		_next("end")


# --- draw ---------------------------------------------------------------------------

func _draw() -> void:
	var v := _view()
	match phase:
		"intro":
			if _t >= PANEL_FROM and _t < PANEL_TO:
				# das große Bild: a black crescent over white
				var k := (_t - PANEL_FROM) / (PANEL_TO - PANEL_FROM)
				draw_rect(v, Color(0.97, 0.97, 1.0, 1.0))
				var c := v.get_center() + Vector2(0, -v.size.y * 0.04)
				var r := v.size.y * (0.32 + 0.06 * k)
				MondFx.draw_crescent(self, null, c, Vector2(-player.facing, -0.25).normalized(), r, 1.0, MondFx.CYAN, 1.3, 0.42)
				# speed lines of the manga panel
				for i in 18:
					var a := TAU * i / 18.0 + 0.2
					var d := Vector2(cos(a), sin(a))
					var inner := r * 1.25 + 10.0 * sin(i * 3.1 + _all * 20.0)
					draw_line(c + d * inner, c + d * (v.size.x), Color(0, 0, 0, 0.5), 1.5, true)
				if variant == "blutmond":
					draw_circle(c + Vector2(player.facing * r * 0.25, -r * 0.1), r * 0.06, MondFx.RED)
		"wave":
			MondFx.draw_crescent(self, null, Vector2(_wave_x, _wave_y), Vector2(player.facing, 0), 62.0, 1.0, MondFx.RED, 1.3, 1.3)
		"eclipse":
			var c2 := Vector2(v.get_center().x, v.position.y + v.size.y * 0.3)
			draw_circle(c2, 28.0, Color(0, 0, 0, 1))


func _draw_add() -> void:
	var tex := GlutFx.glow_texture()
	var v := _view()
	var center := player.global_position + Vector2(0, -24)
	match phase:
		"intro":
			if _t < PANEL_FROM:
				var k := _t / PANEL_FROM
				var r := 40.0 + 30.0 * k
				_add.draw_texture_rect(tex, Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(caster.rim_color(), 0.3 * k))
		"form":
			var r2 := 60.0 * (1.0 - _t / 0.6)
			_add.draw_texture_rect(tex, Rect2(center - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false, Color(MondFx.WHITE, 0.4))
		"charge":
			var r3 := 30.0 + _t * 40.0
			_add.draw_texture_rect(tex, Rect2(center - Vector2(r3, r3), Vector2(r3, r3) * 2.0), false, Color(MondFx.RED, 0.45))
		"wave":
			var c := Vector2(_wave_x, _wave_y)
			_add.draw_texture_rect(tex, Rect2(c + Vector2(player.facing * 60.0, 0) - Vector2(50, 90), Vector2(100, 180)), false, Color(MondFx.EMBER, 0.25))
			MondFx.draw_crescent(null, _add, c, Vector2(player.facing, 0), 62.0, 1.0, MondFx.EMBER, 1.3, 1.3)
			# the scar it leaves behind
			var x0 := player.global_position.x + player.facing * 20.0
			_add.draw_line(Vector2(x0, _wave_y), Vector2(_wave_x, _wave_y), Color(MondFx.RED, 0.5), 3.0, true)
		"eclipse":
			# the corona: a white ring like a total eclipse
			var c2 := Vector2(v.get_center().x, v.position.y + v.size.y * 0.3)
			var k2 := clampf(_t / 0.5, 0.0, 1.0)
			_add.draw_texture_rect(tex, Rect2(c2 - Vector2(80, 80), Vector2(160, 160)), false, Color(MondFx.WHITE, 0.5 * k2))
			_add.draw_arc(c2, 29.0, 0.0, TAU, 48, Color(MondFx.WHITE, k2), 2.5, true)
			for i in 24:
				var a := TAU * i / 24.0 + _all * 0.3
				var d := Vector2(cos(a), sin(a))
				_add.draw_line(c2 + d * 31.0, c2 + d * (38.0 + 14.0 * fposmod(i * 0.61, 1.0)), Color(MondFx.CYAN, 0.6 * k2), 1.2, true)
			# rim light on the silhouette
			_add.draw_texture_rect(tex, Rect2(center - Vector2(20, 30), Vector2(40, 60)), false, Color(MondFx.WHITE, 0.55 * k2))
		"cut":
			var a2 := 1.0 - clampf(_t / 0.5, 0.0, 1.0)
			_add.draw_line(Vector2(v.position.x, _cut_y), Vector2(v.end.x, _cut_y), Color(MondFx.WHITE, a2), 6.0 * a2 + 1.0, true)
			_add.draw_texture_rect(tex, Rect2(v.position.x, _cut_y - 30.0, v.size.x, 60.0), false, Color(MondFx.CYAN, 0.4 * a2))
