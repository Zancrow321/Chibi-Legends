class_name GlutSuper
extends Node2D
## Meisterzug of Glutatem (costs 3 Stufen of the Legendenleiste). One
## common intro, then one of three supers (chosen before the fight):
##  letzte_esse   three forge strikes with spark fountains, then a glow wave
##                rolls along the whole ground
##  schmelzofen   a glowing dome closes around one target, burns, then bursts
##                in slag and sparks (strong against one target)
##  funkensturm   the blade flies into the sky, sparks rain over the whole
##                screen, then the blade falls on the nearest target
## The intro freezes the world (super flash); afterwards the super respects
## hit-stop like everything else.

const INTRO := 0.8
const ORANGE := Color("ff9a2a")
const WHITE := Color("fff4d0")

var room: TrainingRoom
var player: Player
var caster: GlutCaster
var fx: GlutFx
var variant := "letzte_esse"
var title := "Meisterzug"

var phase := "intro"
var _t := 0.0
var _all := 0.0
var _step := 0
var _target: Node2D = null
var _dealt: Dictionary = {}  # target id -> [target, damage]
var _emit := 0.0
var _tick := 0.0
var _wave_hit: Dictionary = {}
var _wave_l := 0.0
var _wave_r := 0.0
var _wave_y := 0.0
var _dome := Vector2.ZERO
var _dome_r := 0.0
var _blade := Vector2.ZERO
var _blade_v := Vector2.ZERO
var _blade_rot := 0.0
var _pose := 5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = CombatFx.FOCUS_Z + 2
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	player.z_index = CombatFx.FOCUS_Z
	player.sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	var cfx := room.fx
	cfx.hold(true)
	cfx.dim(0.82)
	cfx.punch(0.2)
	cfx.flash(0.3 * FxSettings.factor("flash"), ORANGE)
	if room.hud != null:
		room.hud.show_cutin(title + "!", ORANGE)
	_target = _nearest(320.0)
	if _target != null:
		player.facing = 1 if _target.global_position.x >= player.global_position.x else -1
	fx.breath(_mouth(), player.facing, 0.9)


# --- helpers ---------------------------------------------------------------------

func _mouth() -> Vector2:
	return player.global_position + Vector2(player.facing * 7.0, -38.0)


func _blade_line(frame: int) -> Array:
	var b: Array = GlutCaster.BLADE[frame]
	var hand: Vector2 = b[0]
	var tip: Vector2 = b[1]
	var p := player.global_position
	return [p + Vector2(hand.x * player.facing, hand.y), p + Vector2(tip.x * player.facing, tip.y)]


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


## Super hits: small sparks, no single numbers; the total shows at the end.
func _tick_hit(t: Node2D, dmg: float, kb := 20.0) -> void:
	var dealt := room.deal_hit(t, dmg, "feuer", player.global_position.x, kb, "super")
	var id := t.get_instance_id()
	if not _dealt.has(id):
		_dealt[id] = [t, 0]
	_dealt[id][1] += dealt
	player.on_attack_hit()


func _show_totals(col := ORANGE) -> void:
	for id in _dealt:
		var e: Array = _dealt[id]
		if is_instance_valid(e[0]) and e[1] > 0:
			room.numbers.spawn_number(e[0].head_position() + Vector2(0, -14), e[1], col, id + 1, true)
	_dealt.clear()


func _set_pose(f: int) -> void:
	_pose = f
	player.sprite.scale.x = player.facing
	player.sprite.set_state("attack")
	player.sprite.attack_frame = f


func _next(p: String) -> void:
	phase = p
	_t = 0.0
	_step = 0


# --- main loop ------------------------------------------------------------------

func _process(delta: float) -> void:
	if phase != "intro" and room.fx.is_frozen():
		queue_redraw()
		return
	_t += delta
	_all += delta
	match phase:
		"intro":
			_intro(delta)
		"strikes":
			_esse_strikes()
		"wave":
			_esse_wave(delta)
		"dome":
			_ofen_dome(delta)
		"burst":
			_ofen_burst()
		"rise":
			_sturm_rise(delta)
		"rain":
			_sturm_rain(delta)
		"fall":
			_sturm_fall(delta)
		"end":
			if _t >= 0.45:
				_finish()
	_set_pose(_pose)
	queue_redraw()


func _intro(delta: float) -> void:
	_set_pose(5 if _t < 0.5 else 6)
	var line := _blade_line(_pose)
	var k := clampf(_t / 0.5, 0.0, 1.0)
	# inhale: glowing motes are pulled into the mouth, the blade heats up
	_emit -= delta
	if _emit <= 0.0 and _t < 0.5:
		_emit = 0.02
		for i in 2:
			var a := randf() * TAU
			var from := _mouth() + Vector2(cos(a), sin(a)) * randf_range(40, 70)
			fx.glow(from, GlutFx.heat(0.5 + k * 0.4), randf_range(2.0, 4.0), 0.22, (_mouth() - from) / 0.22, 0.3)
	fx.glow_line(line[0], line[1], Color(GlutFx.heat(0.4 + k * 0.6), 1.0), 2.0 + k * 3.0)
	fx.light(player.global_position + Vector2(0, -24), GlutFx.heat(0.5 + k * 0.5), 1.0 + k * 2.0, 0.5 + k * 0.5, 0.06)
	if _t >= 0.5 and _step == 0:
		_step = 1
		var tip: Vector2 = line[1]
		fx.anvil(tip, 46.0, 12)
		fx.ring(tip, 70.0, WHITE, 0.45, 8.0)
		fx.sparks(tip, -PI / 2.0, PI, 50, 380.0, 0.7)
		room.fx.flash(0.45 * FxSettings.factor("flash"), Color(1.0, 0.75, 0.4))
		room.fx.punch(0.08)
	if _t >= INTRO:
		room.fx.hold(false)
		room.fx.dim(0.5)
		match variant:
			"schmelzofen":
				_next("dome")
				_start_dome()
			"funkensturm":
				_next("rise")
				_start_rise()
			_:
				_next("strikes")
				_start_strikes()


func _finish() -> void:
	_show_totals()
	room.fx.dim(0.0)
	room.fx.hold(false)
	player.z_index = 0
	player.in_super = false
	player.sprite.process_mode = Node.PROCESS_MODE_INHERIT
	queue_free()


# --- Letzte Esse ------------------------------------------------------------------

func _start_strikes() -> void:
	if _target == null:
		return
	# rush to the target in a streak of afterimages
	var tx := _target.global_position.x - player.facing * 30.0
	var gy := GlutHazard.ground_y(tx, _target.global_position.y - 6.0)
	if gy > 9000.0 or absf(tx - player.global_position.x) < 20.0:
		return
	var from := player.global_position
	var to := Vector2(tx, gy - 1.0)
	for i in 7:
		var p := from.lerp(to, float(i) / 7.0)
		fx.afterimage(player.sprite._sprite, p, player.facing, Color(1.0, 0.45, 0.15, 0.25 + i * 0.07), 0.3)
		fx.flame(p + Vector2(0, -18), 6.0, Vector2(0, -40), 0.3)
	player.global_position = to
	player.velocity = Vector2.ZERO


func _esse_strikes() -> void:
	var period := 0.3
	var k := int(_t / period)
	var local := fmod(_t, period)
	if k >= 3:
		_set_pose(5)
		if _t >= 3 * period + 0.18:
			_next("wave")
			_start_wave()
		return
	_set_pose(5 if local < 0.13 else 4)
	if k >= _step and local >= 0.13:
		_step = k + 1
		var p := player.global_position + Vector2(player.facing * 28.0, -2.0)
		var words := ["KLONG!", "KLANG!", "DONG!"]
		fx.anvil(p + Vector2(0, -8), 30.0 + k * 6.0, 10)
		fx.fountain(p, 26 + k * 8, 330.0 + k * 30.0)
		fx.ring(p + Vector2(0, -6), 34.0 + k * 8.0, ORANGE, 0.3, 5.0)
		fx.word(p + Vector2(0, -48 - k * 6), words[k], GlutFx.heat(0.8 + k * 0.1), 26 + k * 4)
		for i in 3:
			fx.smoke(p + Vector2(randf_range(-10, 10), -6), 10.0, Vector2(randf_range(-20, 20), -20), 1.2)
		room.fx.shake((5.0 + k * 2.0) * FxSettings.factor("shake"), player.facing)
		room.fx.punch(0.04 + k * 0.02)
		var r := Rect2(p.x - 34.0, p.y - 56.0, 68.0, 60.0)
		for t in _targets():
			if r.intersects(t.get_hurt_rect()):
				room.deal_hit(t, 22.0 + k * 4.0, "feuer", player.global_position.x, 50.0, "heavy", 60.0 if k == 2 else 0.0)
				player.on_attack_hit()


func _start_wave() -> void:
	_set_pose(4)
	var p := player.global_position
	_wave_l = p.x
	_wave_r = p.x
	_wave_y = p.y
	_wave_hit = {}
	fx.fountain(p + Vector2(player.facing * 20.0, 0), 50, 420.0)
	fx.anvil(p + Vector2(player.facing * 20.0, -6), 50.0, 14)
	fx.ring(p + Vector2(0, -6), 90.0, WHITE, 0.5, 9.0)
	fx.word(p + Vector2(0, -70), "WOOOMM!", WHITE, 40)
	room.fx.flash(0.5 * FxSettings.factor("flash"), Color(1.0, 0.6, 0.25))
	room.fx.shake(10.0 * FxSettings.factor("shake"))
	room.fx.punch(0.1)


func _esse_wave(delta: float) -> void:
	_set_pose(4)
	var speed := 1100.0
	_wave_l -= speed * delta
	_wave_r += speed * delta
	room.fx.shake(3.0 * FxSettings.factor("shake"))
	_emit -= delta
	if _emit <= 0.0:
		_emit = 0.016
		for front in [_wave_l, _wave_r]:
			if front < -20.0 or front > TrainingRoom.WIDTH + 20.0:
				continue
			var gy := GlutHazard.ground_y(front, _wave_y - 60.0)
			if gy > 9000.0:
				continue
			var d := -1.0 if front < player.global_position.x else 1.0
			for i in 2:
				fx.flame(Vector2(front + randf_range(-6, 6), gy - 2), randf_range(8, 13), Vector2(d * 40.0, randf_range(-260, -160)), 0.45, 1.0)
			fx.sparks(Vector2(front, gy - 4), -PI / 2.0 + d * 0.3, 0.5, 3, 340.0, 0.5)
			if randf() < 0.4:
				fx.smoke(Vector2(front, gy - 20), 14.0, Vector2(d * 20.0, -30), 1.4)
			fx.light(Vector2(front, gy - 20), Color(1.0, 0.6, 0.25), 2.2, 0.8, 0.12)
	for t in _targets():
		var id: int = t.get_instance_id()
		if _wave_hit.has(id):
			continue
		var r: Rect2 = t.get_hurt_rect()
		if (r.position.x <= player.global_position.x and r.end.x >= _wave_l) or (r.end.x >= player.global_position.x and r.position.x <= _wave_r):
			if absf(r.end.y - GlutHazard.ground_y(r.get_center().x, r.end.y - 30.0)) < 60.0:
				_wave_hit[id] = true
				room.deal_hit(t, 40.0, "feuer", player.global_position.x, 160.0, "heavy", 300.0)
				player.on_attack_hit()
	if _wave_l < -40.0 and _wave_r > TrainingRoom.WIDTH + 40.0:
		_next("end")


# --- Schmelzofen -------------------------------------------------------------------

func _start_dome() -> void:
	_set_pose(4)
	var cx := player.global_position.x + player.facing * 80.0
	if _target != null:
		cx = _target.global_position.x
	var gy := GlutHazard.ground_y(cx, (_target.global_position.y if _target != null else player.global_position.y) - 6.0)
	if gy > 9000.0:
		gy = player.global_position.y
	_dome = Vector2(cx, gy)
	_dome_r = 0.0
	fx.anvil(player.global_position + Vector2(player.facing * 18.0, -4), 30.0, 10)
	fx.word(_dome + Vector2(0, -80), "SCHMELZ!", ORANGE, 30)
	# a glowing crack runs from the blade to the dome
	for i in 10:
		var p := (player.global_position + Vector2(player.facing * 18.0, 0)).lerp(_dome, float(i) / 9.0)
		fx.flame(Vector2(p.x, GlutHazard.ground_y(p.x, p.y - 20.0) - 1.0), 5.0, Vector2(0, -60), 0.35 + i * 0.03)


func _ofen_dome(delta: float) -> void:
	_set_pose(4)
	_dome_r = minf(52.0, _dome_r + delta * 260.0)
	room.fx.shake(2.0 * FxSettings.factor("shake"))
	_emit -= delta
	if _emit <= 0.0:
		_emit = 0.025
		var a := randf_range(PI, TAU)
		var rr := randf() * _dome_r * 0.85
		var p := _dome + Vector2(cos(a) * rr, sin(a) * rr * 0.9)
		fx.flame(p, randf_range(6, 10), Vector2(-sin(a) * 60.0, -70.0), 0.4, 1.0)
		if randf() < 0.4:
			fx.embers(_dome + Vector2(randf_range(-_dome_r, _dome_r) * 0.7, -10), 2, 4.0, 60.0, 0.8)
		fx.light(_dome + Vector2(0, -_dome_r * 0.5), Color(1.0, 0.55, 0.25), 2.0 + 0.4 * sin(_all * 20.0), 0.9, 0.08)
	_tick -= delta
	if _tick <= 0.0 and _dome_r > 20.0:
		_tick = 0.12
		_step += 1
		var box := Rect2(_dome.x - _dome_r, _dome.y - _dome_r, _dome_r * 2.0, _dome_r)
		for t in _targets():
			if box.intersects(t.get_hurt_rect()):
				_tick_hit(t, 6.0, 4.0)
		if _step >= 8:
			_next("burst")


func _ofen_burst() -> void:
	_set_pose(6)
	if _step == 0:
		_step = 1
		var c := _dome + Vector2(0, -22)
		fx.anvil(c, 60.0, 14)
		fx.ring(c, 100.0, WHITE, 0.5, 10.0)
		fx.ring(c, 64.0, ORANGE, 0.35, 6.0)
		fx.slag_burst(c, 30, 300.0)
		fx.sparks(c, -PI / 2.0, PI, 70, 420.0, 0.8)
		for i in 8:
			fx.smoke(c + Vector2(randf_range(-30, 30), randf_range(-20, 10)), randf_range(14, 22), Vector2(randf_range(-40, 40), -30), 1.8)
		fx.word(c + Vector2(0, -60), "BUMM!!", WHITE, 44)
		var box := Rect2(_dome.x - 64.0, _dome.y - 80.0, 128.0, 84.0)
		for t in _targets():
			if box.intersects(t.get_hurt_rect()):
				_show_totals()
				room.deal_hit(t, 40.0, "feuer", _dome.x - player.facing, 220.0, "super_final", 320.0)
				player.on_attack_hit()
		_dome_r = 0.0
	if _t >= 0.2:
		_next("end")


# --- Funkensturm --------------------------------------------------------------------

func _start_rise() -> void:
	_set_pose(5)
	_blade = _blade_line(5)[1]
	_blade_v = Vector2(0, -900.0)
	fx.word(player.global_position + Vector2(0, -70), "HOCH!", ORANGE, 28)
	fx.sparks(_blade, -PI / 2.0, 0.4, 20, 300.0, 0.5)


func _sturm_rise(delta: float) -> void:
	_set_pose(5)
	_blade += _blade_v * delta
	_blade_rot += delta * 30.0
	fx.glow(_blade, GlutFx.heat(0.9), 8.0, 0.25, Vector2.ZERO, 0.2)
	if _t >= 0.35:
		_next("rain")
		room.fx.flash(0.35 * FxSettings.factor("flash"), Color(1.0, 0.65, 0.3))
		fx.word(player.global_position + Vector2(0, -90), "FUNKENSTURM!", WHITE, 30)


func _sturm_rain(delta: float) -> void:
	_set_pose(6)
	var v := _view()
	_emit -= delta
	if _emit <= 0.0:
		_emit = 0.012
		for i in 3:
			var x := randf_range(v.position.x - 40.0, v.end.x)
			fx.rain(Vector2(x, v.position.y - 4.0), Vector2(player.facing * randf_range(60.0, 110.0), randf_range(480.0, 600.0)), 0.9)
		if randf() < 0.35:
			var ix := randf_range(v.position.x, v.end.x)
			var gy := GlutHazard.ground_y(ix, v.position.y)
			if gy < 9000.0:
				fx.glow(Vector2(ix, gy - 2), GlutFx.heat(0.8), 8.0, 0.15)
				fx.sparks(Vector2(ix, gy - 2), -PI / 2.0, 0.9, 3, 120.0, 0.3)
				if randf() < 0.3:
					fx.light(Vector2(ix, gy - 10), Color(1.0, 0.6, 0.3), 1.6, 0.5, 0.1)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.2
		for t in _targets():
			if v.intersects(t.get_hurt_rect()):
				_tick_hit(t, 5.0, 8.0)
	if _t >= 1.6:
		_next("fall")
		var tgt := _nearest(400.0)
		var x := player.global_position.x + player.facing * 70.0
		if tgt != null:
			x = tgt.get_hurt_rect().get_center().x
		_blade = Vector2(x, v.position.y - 30.0)
		_blade_v = Vector2(0, 1500.0)
		_wave_y = GlutHazard.ground_y(x, (tgt.global_position.y - 6.0) if tgt != null else player.global_position.y - 6.0)


func _sturm_fall(delta: float) -> void:
	_set_pose(6)
	_blade += _blade_v * delta
	fx.glow(_blade, GlutFx.heat(1.0), 10.0, 0.2, Vector2.ZERO, 0.2)
	if _blade.y >= _wave_y - 6.0 and _step == 0:
		_step = 1
		_blade.y = _wave_y - 6.0
		var c := Vector2(_blade.x, _wave_y)
		fx.anvil(c + Vector2(0, -10), 56.0, 14)
		fx.fountain(c, 60, 460.0)
		fx.ring(c + Vector2(0, -8), 90.0, WHITE, 0.5, 9.0)
		fx.slag_burst(c, 16, 240.0)
		fx.word(c + Vector2(0, -70), "ZANG!!", WHITE, 44)
		_show_totals()
		var v := _view()
		for t in _targets():
			var r: Rect2 = t.get_hurt_rect()
			if r.grow(40.0).has_point(Vector2(c.x, r.get_center().y)):
				room.deal_hit(t, 35.0, "feuer", c.x - player.facing, 200.0, "super_final", 300.0)
				player.on_attack_hit()
			elif v.intersects(r):
				room.deal_hit(t, 12.0, "feuer", c.x, 120.0, "heavy", 120.0)
	if _step == 1 and _t >= 0.35:
		_next("end")


# --- drawing (additive) ---------------------------------------------------------------

func _draw() -> void:
	var tex := GlutFx.glow_texture()
	var center := player.global_position + Vector2(0, -24)
	match phase:
		"intro":
			# heat aura and rotating speed rays around the fighter
			var k := clampf(_t / 0.5, 0.0, 1.0)
			var r := 50.0 + k * 40.0
			draw_texture_rect(tex, Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(GlutFx.heat(0.55), 0.35 + 0.2 * k))
			for i in 22:
				var a := TAU * i / 22.0 + _all * 0.6
				var inner := 26.0 + 10.0 * sin(i * 7.1 + _all * 9.0)
				var outer := inner + 40.0 + 70.0 * fposmod(i * 0.37 + _all * 2.0, 1.0)
				var d := Vector2(cos(a), sin(a))
				draw_line(center + d * inner, center + d * outer, Color(GlutFx.heat(0.6 + 0.4 * k), 0.35), 1.5, true)
		"strikes", "wave":
			var r2 := 70.0
			draw_texture_rect(tex, Rect2(center - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false, Color(GlutFx.heat(0.6), 0.25))
			if phase == "wave":
				var p := clampf(_t / 1.4, 0.0, 1.0)
				for front in [_wave_l, _wave_r]:
					var gy := GlutHazard.ground_y(front, _wave_y - 60.0)
					if gy > 9000.0:
						continue
					var h := 70.0
					draw_texture_rect(tex, Rect2(front - 18.0, gy - h, 36.0, h * 1.4), false, Color(GlutFx.heat(0.8), 0.8))
					draw_texture_rect(tex, Rect2(front - 7.0, gy - h * 0.7, 14.0, h * 0.9), false, Color(WHITE, 0.8))
				# glowing seam left behind on the ground
				for seg in [[_wave_l, player.global_position.x], [player.global_position.x, _wave_r]]:
					var x0: float = maxf(seg[0], 0.0)
					var x1: float = minf(seg[1], TrainingRoom.WIDTH)
					var x := x0
					while x < x1:
						var nx := minf(x1, x + 40.0)
						var gy2 := GlutHazard.ground_y((x + nx) * 0.5, _wave_y - 60.0)
						if gy2 < 9000.0:
							draw_line(Vector2(x, gy2 - 1), Vector2(nx, gy2 - 1), Color(GlutFx.heat(0.75), 0.7 * (1.0 - p * 0.6)), 2.0)
						x = nx
		"dome", "burst":
			if _dome_r > 1.0:
				var flick := 0.85 + 0.15 * sin(_all * 31.0)
				draw_texture_rect(tex, Rect2(_dome - Vector2(_dome_r * 1.6, _dome_r * 1.6), Vector2(_dome_r, _dome_r) * 3.2), false, Color(GlutFx.heat(0.55), 0.45 * flick))
				var pts := PackedVector2Array()
				var cols := PackedColorArray()
				pts.append(_dome + Vector2(0, -2))
				cols.append(Color(GlutFx.heat(0.9), 0.35))
				for i in 25:
					var a := PI + PI * i / 24.0
					pts.append(_dome + Vector2(cos(a) * _dome_r, sin(a) * _dome_r * 0.95))
					cols.append(Color(GlutFx.heat(0.6), 0.12))
				draw_polygon(pts, cols)
				draw_arc(_dome, _dome_r, PI, TAU, 32, Color(GlutFx.heat(0.75), 0.9 * flick), 3.0, true)
				draw_arc(_dome, _dome_r - 1.5, PI, TAU, 32, Color(WHITE, 0.7 * flick), 1.0, true)
				# heat cracks running up the dome
				for i in 5:
					var a2 := PI + PI * (i + 0.5) / 5.0 + 0.1 * sin(_all * 3.0 + i)
					var d2 := Vector2(cos(a2), sin(a2))
					draw_line(_dome + d2 * _dome_r * 0.55, _dome + d2 * _dome_r, Color(GlutFx.heat(0.9), 0.6), 1.2, true)
		"rise", "fall":
			var dir := Vector2(0, 1) if phase == "fall" else Vector2(cos(_blade_rot), sin(_blade_rot))
			var a3 := _blade - dir * 12.0
			var b3 := _blade + dir * 12.0
			draw_texture_rect(tex, Rect2(_blade - Vector2(16, 16), Vector2(32, 32)), false, Color(GlutFx.heat(0.8), 0.7))
			draw_line(a3, b3, Color(GlutFx.heat(0.85), 1.0), 4.0, true)
			draw_line(a3, b3, Color(WHITE, 1.0), 1.5, true)
			if phase == "fall":
				draw_texture_rect(tex, Rect2(_blade.x - 8.0, _blade.y - 160.0, 16.0, 160.0), false, Color(GlutFx.heat(0.7), 0.6))
		"rain":
			var v := _view()
			draw_texture_rect(tex, Rect2(v.position.x - v.size.x * 0.2, v.position.y - v.size.y * 0.5, v.size.x * 1.4, v.size.y * 0.8), false, Color(GlutFx.heat(0.5), 0.18))
