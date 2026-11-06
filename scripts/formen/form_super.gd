class_name FormSuper
extends Node2D
## Meisterzug of a Baukasten fighting style (3 Stufen of the Legendenleiste).
## A common intro (the world freezes, energy gathers, cut-in), then the
## chosen variant by its "kind":
##  strahl   a giant beam across the screen, many ticks, a final blast
##  regen    pieces rain over the whole screen
##  nova     energy gathers, then a huge blast around the figure
##  ansturm  the figure jumps from target to target, one cut each, final burst
##  feld     the style's effect fills the screen, ticks and pulls, then collapses
##  saeulen  a row of big columns marches forward out of the ground
## Variant params: damage (per tick / hit), radius, width, count, slashes, pull.

const INTRO := 0.75

var room: TrainingRoom
var player: Player
var caster: FormCaster
var variant := ""
var title := "Meisterzug"

var kind := "nova"
var vp: Dictionary = {}
var phase := "intro"
var _t := 0.0
var _step := 0
var _tick := 0.0
var _emit := 0.0
var _target: Node2D = null
var _dealt: Dictionary = {}
var _order: Array = []
var _pose := "super_0"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = CombatFx.FOCUS_Z + 2
	for v in caster.style.variants():
		if str(v.id) == variant:
			kind = str(v.get("kind", "nova"))
			vp = v.get("params", {})
	player.z_index = CombatFx.FOCUS_Z
	player.sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	var cfx := room.fx
	cfx.hold(true)
	cfx.dim(0.82)
	cfx.punch(0.2)
	cfx.flash(0.3 * FxSettings.factor("flash"), _c("main"))
	if room.hud != null:
		room.hud.show_cutin(title + "!", _c("main"))
	_target = _nearest(340.0)
	if _target != null:
		player.facing = 1 if _target.global_position.x >= player.global_position.x else -1
	Sfx.play("glut_super", -4.0)


func _c(key: String) -> Color:
	return caster.col(key)


func _fx() -> String:
	return "%s/%s" % [caster.style.id, variant]


func _center() -> Vector2:
	return player.global_position + Vector2(0, -22)


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
		var n: Node2D = t
		var d: float = absf(n.global_position.x - player.global_position.x) + absf(n.global_position.y - player.global_position.y) * 0.5
		if d < best_d:
			best = n
			best_d = d
	return best


func _hit(t: Node2D, dmg: float, kb := 20.0, final := false) -> void:
	var dealt := room.deal_hit(t, dmg * caster._blood_mul(), caster.elem, player.global_position.x, kb, "super_final" if final else "super", 200.0 if final else 0.0)
	var id := t.get_instance_id()
	if not _dealt.has(id):
		_dealt[id] = [t, 0]
	_dealt[id][1] += dealt
	player.on_attack_hit()


func _hit_rect(r: Rect2, dmg: float, kb := 20.0, final := false) -> int:
	var n := 0
	for t in _targets():
		var node: Node2D = t
		if r.intersects(node.get_hurt_rect()):
			_hit(node, dmg, kb, final)
			n += 1
	return n


func _show_totals() -> void:
	for id in _dealt:
		var e: Array = _dealt[id]
		if is_instance_valid(e[0]) and e[1] > 0:
			room.numbers.spawn_number(e[0].head_position() + Vector2(0, -14), e[1], _c("light"), id + 1, true)
	_dealt.clear()


func _set_pose(pose_name: String) -> void:
	_pose = pose_name
	player.sprite.scale.x = player.facing
	player.sprite.set_state("attack")
	player.sprite.attack_frame = 5
	player.sprite.attack_pose = pose_name


func _next(p: String) -> void:
	phase = p
	_t = 0.0
	_step = 0
	_tick = 0.0


func _process(delta: float) -> void:
	if phase != "intro" and room.fx.is_frozen():
		return
	_t += delta
	match phase:
		"intro":
			_intro(delta)
		"run":
			match kind:
				"strahl":
					_run_strahl(delta)
				"regen":
					_run_regen(delta)
				"nova":
					_run_nova(delta)
				"ansturm":
					_run_ansturm()
				"feld":
					_run_feld(delta)
				"saeulen":
					_run_saeulen()
				_:
					_run_nova(delta)
		"end":
			if _t >= 0.45:
				_finish()
	_set_pose(_pose)


func _intro(delta: float) -> void:
	_pose = "charge_0" if _t < 0.5 else "super_0"
	var k := clampf(_t / 0.5, 0.0, 1.0)
	var ffx := caster.ffx
	_emit -= delta
	if _emit <= 0.0 and _t < 0.55:
		_emit = 0.02
		for i in 3:
			var a := randf() * TAU
			var from := _center() + Vector2(cos(a), sin(a)) * randf_range(46, 80)
			ffx.glow(from, Color(_c("main"), 0.9), randf_range(2.5, 4.5), 0.22, (_center() - from) / 0.22)
	ffx.glow(_center(), Color(_c("light"), 0.25 + 0.4 * k), 14.0 + 22.0 * k, 0.05)
	caster.fx.light(_center(), _c("main"), 1.0 + 2.0 * k, 0.6 + 0.5 * k, 0.06)
	if _t >= 0.5 and _step == 0:
		_step = 1
		ffx.burst(_fx(), _center(), 120.0, 0.45, 0.0, player.facing < 0, Color.WHITE, 0.3)
		ffx.ring(_center(), 70.0, _c("light"), 0.45, 8.0)
		ffx.shards(_center(), -PI / 2.0, PI, 40, 360.0, _c("light"))
		room.fx.flash(0.45 * FxSettings.factor("flash"), _c("main"))
		room.fx.punch(0.08)
	if _t >= INTRO:
		room.fx.hold(false)
		room.fx.dim(0.5)
		_next("run")
		_start()


func _start() -> void:
	match kind:
		"ansturm":
			var list: Array = []
			var view := _view()
			for t in _targets():
				var n: Node2D = t
				if view.grow(40.0).has_point(n.global_position):
					list.append(n)
			list.sort_custom(func(a, b): return absf(a.global_position.x - player.global_position.x) < absf(b.global_position.x - player.global_position.x))
			_order = list
		"saeulen":
			_pose = "upper_hit"


func _end() -> void:
	_next("end")
	_pose = "super_0"


func _finish() -> void:
	_show_totals()
	room.fx.dim(0.0)
	room.fx.hold(false)
	player.z_index = 0
	player.in_super = false
	player.sprite.process_mode = Node.PROCESS_MODE_INHERIT
	queue_free()


# --- Strahl -------------------------------------------------------------------------

func _run_strahl(delta: float) -> void:
	_pose = "thrust_hit" if caster.armed else "cast_hit"
	var view := _view()
	var a := player.global_position + Vector2(player.facing * 14.0, -26.0)
	var end_x := view.end.x + 40.0 if player.facing > 0 else view.position.x - 40.0
	var b := Vector2(end_x, a.y)
	var w := float(vp.get("width", 56))
	var k := clampf(_t / 0.15, 0.0, 1.0)
	var flick := 0.9 + 0.1 * sin(_t * 60.0)
	caster.ffx.beam(_fx(), a, a.lerp(b, k), w * 2.2 * flick, Color.WHITE, 0.05)
	caster.ffx.glow(a, _c("light"), w * 0.9, 0.06)
	room.fx.shake(2.5 * FxSettings.factor("shake"), player.facing)
	_tick -= delta
	if _tick <= 0.0 and _t < 1.4:
		_tick = 0.08
		var x0 := minf(a.x, b.x)
		_hit_rect(Rect2(x0, a.y - w * 0.5, absf(b.x - a.x), w), float(vp.get("damage", 5)), 30.0)
		caster.ffx.shards(a.lerp(b, randf()), PI if player.facing < 0 else 0.0, 0.4, 4, 260.0, _c("light"))
	if _t >= 1.4 and _step == 0:
		_step = 1
		var x1 := minf(a.x, b.x)
		_hit_rect(Rect2(x1, a.y - w * 0.7, absf(b.x - a.x), w * 1.4), float(vp.get("damage", 5)) * 5.0, 260.0, true)
		room.fx.flash(0.4 * FxSettings.factor("flash"), _c("light"))
		room.fx.shake(9.0 * FxSettings.factor("shake"))
	if _t >= 1.55:
		_end()


# --- Regen --------------------------------------------------------------------------

func _run_regen(delta: float) -> void:
	_pose = "super_0"
	var count := int(vp.get("count", 18))
	var dur := 1.6
	var view := _view()
	_tick -= delta
	while _tick <= 0.0 and _step < count:
		_tick += dur / count
		_step += 1
		var x := view.position.x + randf_range(0.08, 0.92) * view.size.x
		var h := FormHazard.new()
		h.world = room
		h.caster = caster
		h.zug_id = variant
		h.fx_id = _fx()
		h.kind = "drop"
		h.col = _c("main")
		h.dir = player.facing
		h.global_position = Vector2(x - 40.0, view.position.y - 20.0)
		h.vel = Vector2(80.0, 560.0 + randf() * 160.0)
		h.size = 1.8
		h.damage = float(vp.get("damage", 12)) * caster._blood_mul()
		h.life = 3.0
		room.attacks.add_child(h)
	if _step >= count and _t >= dur + 0.6:
		_end()


# --- Nova ---------------------------------------------------------------------------

func _run_nova(delta: float) -> void:
	var rad := float(vp.get("radius", 150))
	var c := _center()
	if _t < 0.55:
		_pose = "charge_0"
		_emit -= delta
		if _emit <= 0.0:
			_emit = 0.08
			caster.ffx.ring_in(c, rad * (1.0 - _t), _c("light"), 0.3, 3.0)
		caster.ffx.glow(c, Color(_c("main"), 0.4), 20.0 + _t * 60.0, 0.05)
		return
	if _step == 0:
		_step = 1
		_pose = "super_0"
		caster.ffx.burst(_fx(), c, rad * 2.4, 0.7, 0.0, false, Color.WHITE, 0.2)
		for i in 3:
			caster.ffx.ring(c, rad * (0.6 + 0.25 * i), _c("light") if i == 0 else _c("main"), 0.5 + 0.1 * i, 8.0 - i * 2.0)
		caster.ffx.shards(c, 0.0, PI, 60, 420.0, _c("light"))
		_hit_rect(Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0), float(vp.get("damage", 75)), 280.0, true)
		room.fx.flash(0.55 * FxSettings.factor("flash"), _c("light"))
		room.fx.shake(10.0 * FxSettings.factor("shake"))
		room.fx.punch(0.1)
		Sfx.play("glut_impact")
	if _t >= 1.1:
		_end()


# --- Ansturm ------------------------------------------------------------------------

func _run_ansturm() -> void:
	var slashes := int(vp.get("slashes", 7))
	var period := 0.15
	var k := int(_t / period)
	if k >= slashes:
		if _step <= slashes:
			_step = slashes + 1
			var c := _center()
			caster.ffx.burst(_fx(), c, 160.0, 0.55, 0.0, false, Color.WHITE, 0.3)
			caster.ffx.ring(c, 90.0, _c("light"), 0.45, 7.0)
			for id in _dealt:
				var e: Array = _dealt[id]
				if is_instance_valid(e[0]):
					_hit(e[0], float(vp.get("damage", 12)) * 2.0, 240.0, true)
			room.fx.flash(0.4 * FxSettings.factor("flash"), _c("light"))
			room.fx.shake(8.0 * FxSettings.factor("shake"))
		if _t >= slashes * period + 0.3:
			_end()
		return
	if k < _step:
		return
	_step = k + 1
	_pose = "slash_hit" if caster.armed else ("cross_hit" if k % 2 == 0 else "highkick_hit")
	var tg: Node2D = null
	_order = _order.filter(func(n): return is_instance_valid(n))
	if not _order.is_empty():
		tg = _order[k % _order.size()]
	var from := player.global_position
	var to := from + Vector2(player.facing * 60.0, 0)
	if tg != null:
		var side := -1.0 if k % 2 == 0 else 1.0
		to = Vector2(tg.global_position.x + side * 28.0, tg.global_position.y)
		player.facing = 1 if tg.global_position.x >= to.x else -1
	to.x = clampf(to.x, 12.0, TrainingRoom.WIDTH - 12.0)
	var snap := player.sprite.snapshot()
	for i in 4:
		room.afterimages.add(snap, Color(_c("main"), 0.2 + i * 0.12) * Color(1.6, 1.6, 1.6, 1.0), from.lerp(to, float(i) / 4.0) - from, 0.25)
	player.global_position = to
	var c2: Vector2 = to + Vector2(player.facing * 20.0, -22.0)
	if tg != null:
		c2 = tg.get_hurt_rect().get_center()
	caster.ffx.burst(_fx(), c2, 90.0, 0.28, randf_range(-0.8, 0.8), player.facing < 0, Color.WHITE, 0.5)
	caster.ffx.shards(c2, randf() * TAU, PI, 10, 300.0, _c("light"))
	if tg != null:
		_hit(tg, float(vp.get("damage", 12)), 40.0)
	room.fx.shake(3.0 * FxSettings.factor("shake"))
	Sfx.play("glut_attack", -6.0)


# --- Feld ---------------------------------------------------------------------------

func _run_feld(delta: float) -> void:
	_pose = "super_0"
	var view := _view()
	var dur := 2.2
	var a := clampf(_t / 0.3, 0.0, 1.0)
	caster.ffx.sheet(_fx(), view.grow(-10.0), Color(1, 1, 1, 0.55 * a), 0.05, player.facing < 0)
	var c := Vector2(view.get_center().x, player.global_position.y - 20.0)
	var pull := float(vp.get("pull", 50))
	for t in _targets():
		var n: Node2D = t
		if view.has_point(n.global_position) and pull > 0.0:
			var dx := c.x - n.global_position.x
			if absf(dx) > 6.0:
				n.global_position.x += signf(dx) * minf(absf(dx), pull * delta)
	_tick -= delta
	if _tick <= 0.0 and _t < dur:
		_tick = 0.25
		_hit_rect(view, float(vp.get("damage", 4)), 10.0)
		caster.ffx.motes(Vector2(view.position.x + randf() * view.size.x, view.position.y + randf() * view.size.y), 6, 30.0, _c("light"), 0.8)
	if _t >= dur and _step == 0:
		_step = 1
		caster.ffx.burst(_fx(), c, 200.0, 0.6, 0.0, false, Color.WHITE, 1.4)
		caster.ffx.ring(c, 120.0, _c("light"), 0.5, 8.0)
		_hit_rect(view, float(vp.get("damage", 4)) * 6.0, 220.0, true)
		room.fx.flash(0.45 * FxSettings.factor("flash"), _c("light"))
		room.fx.shake(9.0 * FxSettings.factor("shake"))
	if _t >= dur + 0.35:
		_end()


# --- Säulen -------------------------------------------------------------------------

func _run_saeulen() -> void:
	var count := int(vp.get("count", 8))
	var period := 0.12
	var k := int(_t / period)
	if k >= count:
		if _t >= count * period + 0.5:
			_end()
		return
	if k < _step:
		return
	_step = k + 1
	var x := player.global_position.x + player.facing * (40.0 + k * 44.0)
	var gy := GlutHazard.ground_y(x, player.global_position.y - 40.0)
	if gy > 9000.0:
		return
	var h := FormHazard.new()
	h.world = room
	h.caster = caster
	h.zug_id = variant
	h.fx_id = _fx()
	h.kind = "pillar"
	h.col = _c("main")
	h.dir = player.facing
	h.global_position = Vector2(x, gy)
	h.width = 46.0
	h.height = 150.0
	h.damage = float(vp.get("damage", 12)) * caster._blood_mul()
	h.params = {"launch": 380.0}
	h.life = 0.5
	room.attacks.add_child(h)
	caster.ffx.shards(Vector2(x, gy), -PI / 2.0, 0.6, 14, 320.0, _c("light"))
	room.fx.shake(4.0 * FxSettings.factor("shake"))
	if k == count - 1:
		room.fx.flash(0.3 * FxSettings.factor("flash"), _c("light"))
