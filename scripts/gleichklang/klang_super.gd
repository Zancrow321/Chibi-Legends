class_name KlangSuper
extends Node2D
## Meisterzug of Gleichklang (costs 3 Stufen of the Legendenleiste). Common
## intro: the figure grips the shaft with both hands, Nachhall and the figure
## call "Zusammen!", and two sound rings (the two souls) swing against each
## other until they pulse in the same beat. Then one of three supers:
##  erntebogen     a giant soul blade grows from the scythe, one very wide
##                 arc cuts everything in front and above (groups)
##  totengelaeut   three deep bell strikes condense the blade, then one
##                 vertical cut on the nearest target (one big target)
##  reiner_klang   one clear bell strike: a ring of white light clears the
##                 figure's bad states, hits and interrupts nearby enemies
## At the cut the background goes dark and the white outline of the arc stays
## for a moment. The intro freezes the world; afterwards hit-stop applies.

const INTRO := 0.9
var BLUE := Color("8fd3ff")
var PALE := Color("cfeaff")
var WHITE := Color("f4fbff")
var VIOLET := Color("a884f3")

var room: TrainingRoom
var player: Player
var caster: KlangCaster
var kfx: KlangFx
var variant := "erntebogen"
var title := "Meisterzug"

var phase := "intro"
var _t := 0.0
var _step := 0
var _target: Node2D = null
var _dealt: Dictionary = {}
var _blade_len := 0.0
var _blade_up := false
var _ring_r := 0.0
var _pose := 5


func _ready() -> void:
	# the chosen Klangfarbe
	BLUE = caster.style.color("blue")
	PALE = caster.style.color("pale")
	WHITE = caster.style.color("white")
	VIOLET = caster.style.color("violet")
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
	cfx.dim(0.85)
	cfx.punch(0.18)
	cfx.flash(0.25 * FxSettings.factor("flash"), PALE)
	if room.hud != null:
		room.hud.show_cutin(title + "!", BLUE)
	_target = _nearest(340.0)
	if _target != null:
		player.facing = 1 if _target.global_position.x >= player.global_position.x else -1
	kfx.speech("Zusammen!", 1.0)
	Sfx.play("bell_hit", 2.0)


# --- helpers -----------------------------------------------------------------------

func _center() -> Vector2:
	return player.global_position + Vector2(0, -22)


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


func _fa(a: float) -> float:
	return a if player.facing > 0 else PI - a


func _deal(t: Node2D, dmg: float, kb: float, profile := "super", launch := 0.0) -> void:
	var dealt := room.deal_hit(t, dmg, "seele", player.global_position.x, kb, profile, launch)
	var id := t.get_instance_id()
	if not _dealt.has(id):
		_dealt[id] = [t, 0]
	_dealt[id][1] += dealt
	player.on_attack_hit()


func _show_totals() -> void:
	for id in _dealt:
		var e: Array = _dealt[id]
		if is_instance_valid(e[0]) and e[1] > 0:
			room.numbers.spawn_number(e[0].head_position() + Vector2(0, -14), e[1], BLUE, id + 1, true)
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
	match phase:
		"intro":
			_intro()
		"grow":
			_ernte_grow()
		"cut":
			_ernte_cut()
		"toll":
			_toll()
		"vertical":
			_vertical()
		"ring":
			_clear_ring(delta)
		"end":
			if _t >= 0.5:
				_finish()
	_set_pose(_pose)
	queue_redraw()


func _intro() -> void:
	_set_pose(6 if _t < 0.45 else 5)
	if _step == 0 and _t >= 0.45:
		_step = 1
		kfx.ring(_center(), 60.0, WHITE, 0.45, 5.0)
		kfx.motes(_center(), 16, 18.0, PALE, 0.7)
		kfx.klang_burst("meisterzug", player.global_position + Vector2(0, -62), 110.0, 0.8, 0.0, false, Color.WHITE, 0.3)
		room.fx.flash(0.35 * FxSettings.factor("flash"), Color(0.75, 0.88, 1.0))
		Sfx.play("bell_tick", 10.0)
	if _t >= INTRO:
		room.fx.hold(false)
		room.fx.dim(0.55)
		match variant:
			"totengelaeut":
				_next("toll")
				_blade_up = true
			"reiner_klang":
				_next("ring")
				Sfx.play("bell_clear")
				room.fx.flash(0.4 * FxSettings.factor("flash"), WHITE)
				kfx.word(player.global_position + Vector2(0, -80), "DONG!", WHITE, 32)
				kfx.klang_burst("reiner_klang", _center(), 230.0, 0.6, 0.0, false, Color(1, 1, 1, 0.55), 0.2)
				_clear_player()
			_:
				_next("grow")


func _finish() -> void:
	_show_totals()
	room.fx.dim(0.0)
	room.fx.hold(false)
	player.z_index = 0
	player.in_super = false
	player.sprite.process_mode = Node.PROCESS_MODE_INHERIT
	queue_free()


# --- Erntebogen ---------------------------------------------------------------------

func _ernte_grow() -> void:
	_set_pose(5)
	_blade_len = lerpf(10.0, 150.0, clampf(_t / 0.35, 0.0, 1.0))
	if randf() < 0.6:
		kfx.motes(caster.klangloch_pos(), 1, 8.0, PALE, 0.5)
	if _t >= 0.4:
		_next("cut")
		room.fx.dim(0.92)
		Sfx.play("swing_heavy", 4.0)


func _ernte_cut() -> void:
	_set_pose(4)
	var k := clampf(_t / 0.22, 0.0, 1.0)
	_blade_len = 150.0 * (1.0 - k * 0.3)
	if _step == 0:
		_step = 1
		var c := _center()
		kfx.arc(c, 130.0, _fa(-2.6), _fa(1.0), 34.0, BLUE, 0.5)
		kfx.arc(c, 136.0, _fa(-2.6), _fa(1.0), 14.0, WHITE, 0.45)
		kfx.contour(c, 140.0, minf(_fa(-2.6), _fa(1.0)), maxf(_fa(-2.6), _fa(1.0)), 0.9)
		kfx.word(c + Vector2(player.facing * 90.0, -100), "SHIIING!", WHITE, 36)
		kfx.klang_burst("erntebogen", c + Vector2(player.facing * 40.0, -20.0), 280.0, 0.55, 0.0, player.facing < 0, Color.WHITE, 0.6)
		room.fx.shake(10.0 * FxSettings.factor("shake"), player.facing)
		room.fx.punch(0.1)
		room.fx.flash(0.45 * FxSettings.factor("flash"), Color(0.8, 0.9, 1.0))
		Sfx.play("bell_big")
		for tg in _targets():
			var d: Vector2 = tg.get_hurt_rect().get_center() - c
			if d.length() < 175.0 and d.x * player.facing > -30.0:
				_deal(tg, 48.0, 200.0, "super_final", 160.0)
				kfx.shards(tg.get_hurt_rect().get_center(), 0.0 if player.facing > 0 else PI, 0.6, 8, 300.0)
	if _t >= 0.35:
		_blade_len = 0.0
		room.fx.dim(0.3)
		_next("end")


# --- Totengeläut ---------------------------------------------------------------------

func _toll() -> void:
	_set_pose(5)
	var strikes := int(_t / 0.34)
	if strikes >= _step and _step < 3:
		_step += 1
		Sfx.play("bell_big", -4.0 + _step * 2.0)
		var c := caster.klangloch_pos()
		kfx.ring(c, 40.0 + _step * 20.0, VIOLET if _step < 3 else WHITE, 0.5, 5.0)
		kfx.word(c + Vector2(0, -40 - _step * 10), "DONG!", PALE if _step < 3 else WHITE, 24 + _step * 4)
		kfx.klang_burst("seelenlauschen", c, 60.0 + _step * 24.0, 0.45, 0.0, false, Color(0.85, 0.75, 1.0), 0.3)
		room.fx.shake((3.0 + _step * 2.0) * FxSettings.factor("shake"))
		room.fx.punch(0.04)
	_blade_len = lerpf(20.0, 130.0, clampf(_t / 1.0, 0.0, 1.0))
	if _t >= 1.05:
		_next("vertical")
		room.fx.dim(0.95)
		# step to the target
		if _target != null and is_instance_valid(_target):
			var tx: float = _target.global_position.x - player.facing * 26.0
			var gy := GlutHazard.ground_y(tx, _target.global_position.y - 6.0)
			if gy < 9000.0:
				var snap := player.sprite.snapshot()
				for i in 5:
					room.afterimages.add(snap, Color(0.6, 0.8, 1.6, 0.25 + i * 0.1), (Vector2(tx, gy - 1.0) - player.global_position) * float(i) / 5.0, 0.3)
				player.global_position = Vector2(tx, gy - 1.0)


func _vertical() -> void:
	_set_pose(4)
	if _step == 0:
		_step = 1
		_blade_up = false
		var x := player.global_position.x + player.facing * 26.0
		var top := Vector2(x, player.global_position.y - 150.0)
		kfx.arc(Vector2(x - player.facing * 60.0, player.global_position.y - 70.0), 90.0, _fa(-1.4), _fa(0.9), 30.0, WHITE, 0.5)
		kfx.contour(Vector2(x - player.facing * 60.0, player.global_position.y - 70.0), 94.0, minf(_fa(-1.4), _fa(0.9)), maxf(_fa(-1.4), _fa(0.9)), 0.9)
		kfx.word(top + Vector2(0, 20), "TOTENGELÄUT", WHITE, 30)
		kfx.klang_burst("totengelaeut", Vector2(x, player.global_position.y - 76.0), 170.0, 0.55, 0.0, false, Color.WHITE, 0.5)
		room.fx.shake(12.0 * FxSettings.factor("shake"))
		room.fx.punch(0.12)
		room.fx.flash(0.5 * FxSettings.factor("flash"), Color(0.85, 0.9, 1.0))
		room.fx.freeze(0.12 * FxSettings.factor("stop"))
		Sfx.play("bell_big", 2.0)
		for tg in _targets():
			var d: float = absf(tg.get_hurt_rect().get_center().x - x)
			if d < 40.0 and absf(tg.global_position.y - player.global_position.y) < 120.0:
				var main: bool = tg == _target or _target == null
				_deal(tg, 72.0 if main else 30.0, 120.0, "super_final", -200.0)
				if tg.get("status") is Dictionary:
					tg.status["seelenbruch"] = KlangCaster.BREAK_TIME
				kfx.shards(tg.get_hurt_rect().get_center(), PI / 2.0, 0.9, 10, 280.0)
	_blade_len = maxf(0.0, _blade_len - 600.0 * get_process_delta_time())
	if _t >= 0.4:
		room.fx.dim(0.3)
		_next("end")


# --- Reiner Klang ----------------------------------------------------------------------

func _clear_player() -> void:
	if player.get("status") is Dictionary:
		player.status.clear()
	player.hitstun = 0.0
	kfx.ring(_center(), 30.0, WHITE, 0.4, 4.0)
	kfx.motes(_center(), 18, 14.0, WHITE, 0.8)


func _clear_ring(delta: float) -> void:
	_set_pose(6)
	_ring_r = 130.0 * (1.0 - pow(1.0 - clampf(_t / 0.45, 0.0, 1.0), 3.0))
	for tg in _targets():
		var id: int = tg.get_instance_id()
		if _dealt.has(id):
			continue
		if tg.get_hurt_rect().get_center().distance_to(_center()) <= _ring_r:
			_deal(tg, 28.0, 170.0, "super_final", 80.0)
			kfx.shards(tg.get_hurt_rect().get_center(), (tg.get_hurt_rect().get_center() - _center()).angle(), 0.4, 6, 240.0, WHITE)
	if randf() < 0.5:
		var a := randf() * TAU
		kfx.motes(_center() + Vector2(cos(a), sin(a)) * _ring_r, 1, 3.0, WHITE, 0.5)
	if _t >= 0.6:
		_ring_r = 0.0
		room.fx.dim(0.2)
		_next("end")


# --- draw ---------------------------------------------------------------------------

func _draw() -> void:
	var tex := GlutFx.glow_texture()
	if phase == "intro":
		# two souls: rings that swing against each other, then pulse together
		var k := clampf(_t / INTRO, 0.0, 1.0)
		var c := _center()
		var hole := caster.klangloch_pos()
		var sync := k * k
		var ra := 26.0 + 6.0 * sin(_t * 18.0)
		var rb := 26.0 + 6.0 * sin(_t * 18.0 + PI * (1.0 - sync))
		var mid := c.lerp(hole, 0.5)
		var off := (hole - c) * 0.5 * (1.0 - sync)
		draw_arc(mid - off, ra, 0.0, TAU, 48, Color(PALE, 0.5 + 0.4 * k), 2.0, true)
		draw_arc(mid + off, rb, 0.0, TAU, 48, Color(VIOLET, 0.5 + 0.4 * k), 2.0, true)
		draw_texture_rect(tex, Rect2(mid - Vector2(40, 40), Vector2(80, 80)), false, Color(BLUE, 0.15 + 0.25 * sync))
	if _blade_len > 1.0:
		_draw_soul_blade()
	if _ring_r > 1.0:
		var c2 := _center()
		var fade := 1.0 - clampf((_t - 0.3) / 0.3, 0.0, 1.0)
		draw_arc(c2, _ring_r, 0.0, TAU, 72, Color(WHITE, 0.9 * fade), 4.0, true)
		draw_arc(c2, _ring_r, 0.0, TAU, 72, Color(PALE, 0.35 * fade), 14.0, true)
		draw_texture_rect(tex, Rect2(c2 - Vector2(_ring_r, _ring_r), Vector2(_ring_r, _ring_r) * 2.0), false, Color(WHITE, 0.18 * fade))


## The giant soul blade: from the Klangloch a long, curved blade of light.
func _draw_soul_blade() -> void:
	var base := caster.klangloch_pos()
	var dir := Vector2(-player.facing * 0.35, -1.0).normalized() if _blade_up else Vector2(-player.facing * 0.8, -0.6).normalized()
	var bend := Vector2(-dir.y, dir.x) * (player.facing if not _blade_up else -player.facing)
	var n := 18
	var core := PackedVector2Array()
	for i in n + 1:
		var k := float(i) / n
		core.append(base + dir * _blade_len * k + bend * _blade_len * 0.35 * k * k)
	var pulse := 0.85 + 0.15 * sin(_t * 30.0)
	var wmax := 10.0 if _blade_up else 14.0
	for i in n:
		var k2 := float(i) / n
		var w := wmax * (1.0 - k2) + 1.5
		draw_line(core[i], core[i + 1], Color(BLUE, 0.28 * pulse), w * 2.2, true)
		draw_line(core[i], core[i + 1], Color(BLUE, 0.6 * pulse), w, true)
		draw_line(core[i] + bend * w * 0.3, core[i + 1] + bend * w * 0.3, Color(WHITE, 0.85), maxf(1.0, w * 0.25), true)
	draw_polyline(core, Color(WHITE, 0.9), 2.0, true)
	var tip: Vector2 = core[core.size() - 1]
	draw_texture_rect(GlutFx.glow_texture(), Rect2(tip - Vector2(10, 10), Vector2(20, 20)), false, Color(WHITE, 0.6))
	draw_texture_rect(GlutFx.glow_texture(), Rect2(base - Vector2(16, 16), Vector2(32, 32)), false, Color(BLUE, 0.6))
