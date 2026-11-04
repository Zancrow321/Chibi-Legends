class_name WirbelSuper
extends Node2D
## Meisterzug of Wirbelwille (costs 3 Stufen of the Legendenleiste). Common
## intro: close-up cut-in, a hand sign (palms together, then pulled apart),
## wind tearing at the figure. Then one of three supers:
##  sturmrad          two Windschatten help form a giant wind pinwheel; it
##                    is thrown, spins at the target (6 hits) and then folds
##                    and bursts everything apart
##  hundert_schatten  an opening blow; if it lands, six Windschatten attack
##                    in a fixed circle sequence (2 s). Missed: 1 Stufe back
##  orkanmantel       8 s storm cloak with two storm arms (WirbelCaster
##                    mantle_time), a wind burst at the end
## The intro freezes the world; afterwards hit-stop applies.

const INTRO := 0.8

var room: TrainingRoom
var player: Player
var caster: WirbelCaster
var wfx: WirbelFx
var variant := "sturmrad"
var title := "Meisterzug"

var phase := "intro"
var _t := 0.0
var _step := 0
var _target = null
var _dealt: Dictionary = {}
var _pose := "cast_wind"
var _wheel := Vector2.ZERO
var _wheel_v := 0.0
var _wheel_t := 0.0
var _helpers: Array = []
var _ring: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.z_index = CombatFx.FOCUS_Z
	player.sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	var cfx := room.fx
	cfx.hold(true)
	cfx.dim(0.85)
	cfx.punch(0.2)
	cfx.flash(0.25 * FxSettings.factor("flash"), Color(0.75, 1.0, 1.0))
	if room.hud != null:
		room.hud.show_cutin(title + "!", caster.style.color("turq"))
	_target = _nearest(360.0)
	if _target != null:
		player.facing = 1 if _target.global_position.x >= player.global_position.x else -1
	Sfx.play("super_flash")


# --- helpers -----------------------------------------------------------------------

func _c(k: String) -> Color:
	return caster.style.color(k)


func _center() -> Vector2:
	return player.global_position + Vector2(0, -20)


func _fwd(d: float, y := 0.0) -> Vector2:
	return Vector2(player.facing * d, y)


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


func _deal(t: Node2D, dmg: float, kb: float, profile := "super", launch := 0.0, element := "") -> void:
	var dealt := room.deal_hit(t, dmg, element, player.global_position.x, kb, profile, launch)
	var id := t.get_instance_id()
	if not _dealt.has(id):
		_dealt[id] = [t, 0]
	_dealt[id][1] += dealt
	player.on_attack_hit()


func _show_totals() -> void:
	for id in _dealt:
		var e: Array = _dealt[id]
		if is_instance_valid(e[0]) and e[1] > 0:
			room.numbers.spawn_number(e[0].head_position() + Vector2(0, -14), e[1], _c("gold"), id + 1, true)
	_dealt.clear()


func _set_pose(name: String) -> void:
	_pose = name
	player.sprite.scale.x = player.facing
	player.sprite.set_state("attack")
	player.sprite.attack_phase = "active"
	player.sprite.attack_k = 0.5
	player.sprite.attack_power = 1.3
	player.sprite.attack_pose = name


func _next(p: String) -> void:
	phase = p
	_t = 0.0
	_step = 0


## A super clone (outside the two-clone limit of normal fighting).
func _clone(pos: Vector2, dir: int, steps: Array) -> WindClone:
	var c := WindClone.new()
	c.caster = caster
	c.world = room
	c.wfx = wfx
	c.facing = dir
	c.steps = steps
	c.global_position = pos
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	room.add_child(c)
	return c


# --- main loop ------------------------------------------------------------------

func _process(delta: float) -> void:
	if phase != "intro" and room.fx.is_frozen():
		return
	_t += delta
	match phase:
		"intro":
			_intro()
		"form":
			_form()
		"throw":
			_throw(delta)
		"spin":
			_spin(delta)
		"opener":
			_opener()
		"shadows":
			_shadows()
		"cloak":
			_cloak()
		"end":
			if _t >= 0.45:
				_finish()
	if phase != "end" or _t < 0.2:
		_set_pose(_pose)


func _intro() -> void:
	var c := _center()
	if _t < 0.3:
		_pose = "cast_wind"
	else:
		_pose = "super_0"
	# palms together: threads gather, then are pulled apart
	if _step == 0 and _t >= 0.3:
		_step = 1
		wfx.anim("windschatten_entstehen", c, 90.0, -1.0, 0.0, false, Color.WHITE, 1.2)
		wfx.ring(c, 40.0, _c("ice"), 0.35, 4.0)
		wfx.word(c + Vector2(0, -60), "FADEN!", _c("white"), 22)
		room.fx.flash(0.3 * FxSettings.factor("flash"), Color(0.75, 1.0, 1.0))
		Sfx.play("hit_heavy")
	if _step == 1:
		var k := clampf((_t - 0.3) / 0.4, 0.0, 1.0)
		for i in 6:
			var a := TAU * i / 6.0 + _t * 4.0
			wfx.thread(c + Vector2(cos(a), sin(a)) * (50.0 - 30.0 * k), c, _c("turq"), 1.0)
	wfx.gust(c, PI if player.facing > 0 else 0.0, 1, 30.0)
	if _t >= INTRO:
		room.fx.hold(false)
		room.fx.dim(0.55)
		match variant:
			"hundert_schatten":
				_next("opener")
			"orkanmantel":
				_next("cloak")
			_:
				_next("form")


func _finish() -> void:
	_show_totals()
	for h in _helpers:
		if is_instance_valid(h):
			h.vanish()
	room.fx.dim(0.0)
	room.fx.hold(false)
	player.z_index = 0
	player.in_super = false
	player.sprite.process_mode = Node.PROCESS_MODE_INHERIT
	queue_free()


# --- Sturmrad -------------------------------------------------------------------------

func _form() -> void:
	_pose = "super_0"
	_wheel = player.global_position + _fwd(30, -44)
	var k := clampf(_t / 0.7, 0.0, 1.0)
	if _step == 0:
		_step = 1
		for side in [-1, 1]:
			var pos := player.global_position + Vector2(side * 22.0, 0)
			_helpers.append(_clone(pos, -side if side != 0 else 1, [
				[0.0, func(c: WindClone): c.pose("cast_hit")],
				[2.0, func(c: WindClone): c.vanish()],
			]))
		wfx.word(_center() + Vector2(0, -70), "STURMRAD!", _c("turq"), 26)
		Sfx.play("swing_heavy", 4.0)
	# the helpers feed threads into the hub
	for h in _helpers:
		if is_instance_valid(h):
			wfx.thread(h.global_position + Vector2(0, -26), _wheel, _c("turq"), 1.2)
	wfx.thread(player.global_position + _fwd(8, -30), _wheel, _c("gold"), 1.4)
	_wheel_t += get_process_delta_time() * (1.0 + 3.0 * k)
	wfx.hold("sturmrad", _wheel, 30.0 + 90.0 * k, _wheel_t)
	wfx.glow(_wheel, Color(_c("turq"), 0.3 * k), 50.0 * k, 0.06)
	if randf() < 0.5:
		wfx.gust(_wheel + Vector2(randf_range(-60, 60), randf_range(-40, 40)) * k, randf() * TAU, 1, 30.0)
	room.fx.shake(1.5 * k * FxSettings.factor("shake"))
	if _t >= 0.75:
		for h in _helpers:
			if is_instance_valid(h):
				h.vanish()
		_helpers.clear()
		_wheel_v = 300.0
		_next("throw")
		_pose = "throw_0"
		wfx.gust(_wheel, 0.0 if player.facing > 0 else PI, 10, 70.0)
		Sfx.play("dash", 4.0)


func _throw(delta: float) -> void:
	_pose = "throw_0"
	_wheel_t += delta * 4.0
	_wheel.x += player.facing * _wheel_v * delta
	_wheel.y = move_toward(_wheel.y, player.global_position.y - 30.0, 60.0 * delta)
	wfx.hold("sturmrad", _wheel, 120.0, _wheel_t)
	wfx.glow(_wheel, Color(_c("turq"), 0.3), 60.0, 0.05)
	var hit := false
	for tg in _targets():
		if tg.get_hurt_rect().grow(30.0).has_point(_wheel):
			hit = true
	if hit or absf(_wheel.x - player.global_position.x) > 220.0 or _t > 1.2:
		_next("spin")
		wfx.word(_wheel + Vector2(0, -70), "WHIRR!", _c("white"), 26)


func _spin(delta: float) -> void:
	_pose = "cast_hit"
	_wheel_t += delta * 6.0
	wfx.hold("sturmrad", _wheel, 130.0, _wheel_t)
	wfx.glow(_wheel, Color(_c("ice"), 0.35), 70.0, 0.05)
	if randf() < 0.6:
		wfx.shards(_wheel, randf() * TAU, 0.3, 2, 260.0, _c("ice"))
	var due := mini(6, int(_t / 1.5 * 6.0) + 1)
	while _step < due:
		_step += 1
		for tg in _targets():
			if tg.get_hurt_rect().get_center().distance_to(_wheel) < 64.0:
				_deal(tg, 5.0, 30.0, "super", 0.0, "wind")
				if tg.get("vel") != null:
					tg.vel = (_wheel - tg.global_position) * 2.0
		room.fx.shake(2.5 * FxSettings.factor("shake"))
		Sfx.play("hit_light")
	if _t >= 1.5:
		wfx.anim("sturmrad_abschluss", _wheel, 260.0)
		wfx.ring(_wheel, 110.0, _c("ice"), 0.45, 7.0)
		wfx.ring(_wheel, 70.0, _c("gold"), 0.35, 4.0)
		wfx.word(_wheel + Vector2(0, -80), "STURMRAD!", _c("gold"), 36)
		for tg in _targets():
			if tg.get_hurt_rect().get_center().distance_to(_wheel) < 90.0:
				_deal(tg, 24.0, 360.0, "super_final", 220.0, "wind")
				caster._posture(tg, 30.0)
		room.fx.flash(0.5 * FxSettings.factor("flash"), Color(0.8, 1.0, 1.0))
		room.fx.shake(14.0 * FxSettings.factor("shake"))
		room.fx.freeze(0.16 * FxSettings.factor("stop"))
		Sfx.play("break", 4.0)
		room.fx.dim(0.2)
		_next("end")


# --- Hundert Schatten -----------------------------------------------------------------

func _opener() -> void:
	_pose = "dashpunch_hit" if _t > 0.08 else "jab_wind"
	if _step == 0 and _t >= 0.08:
		_step = 1
		player.velocity.x = 0.0
		player.global_position.x += player.facing * 26.0
		wfx.gust(_center(), 0.0 if player.facing > 0 else PI, 8, 50.0)
		var r := Rect2(player.global_position.x + (0.0 if player.facing > 0 else -46.0), player.global_position.y - 44, 46, 44)
		for tg in _targets():
			if r.intersects(tg.get_hurt_rect()):
				_target = tg
		if _target == null:
			# missed: the Meisterzug is spent, but one Stufe comes back
			player.gauge = minf(player.gauge + 100.0, 300.0)
			wfx.word(_center() + Vector2(0, -50), "DANEBEN…", _c("storm"), 18)
			room.fx.dim(0.0)
			_next("end")
			return
		_deal(_target, 12.0, 20.0, "super")
		wfx.anim("kreiselfaust_treffer", _target.get_hurt_rect().get_center(), 90.0)
		wfx.word(_target.head_position() + Vector2(0, -20), "BAM!", _c("white"), 24)
		room.fx.freeze(0.08 * FxSettings.factor("stop"))
	if _t >= 0.3:
		_next("shadows")


func _shadows() -> void:
	const N := 6
	const DUR := 2.0
	_pose = "super_0"
	if not is_instance_valid(_target):
		_next("end")
		return
	var c: Vector2 = _target.global_position
	if _target.get("vel") != null:
		_target.vel = Vector2.ZERO
	if _step == 0:
		_step = 1
		wfx.word(_center() + Vector2(0, -70), "HUNDERT SCHATTEN!", _c("ice"), 26)
		room.fx.dim(0.8)
		for i in N:
			var a := PI + PI * float(i) / (N - 1)  # half circle above and around
			var at := c + Vector2(cos(a) * 64.0, sin(a) * 28.0 if sin(a) < 0.0 else 0.0)
			at.y = minf(at.y, c.y)
			var dir := 1 if at.x < c.x else -1
			var start := 0.12 + i * 0.26
			var tg = _target
			var hs := {}
			_ring.append(_clone(at, dir, [
				[0.0, func(cl: WindClone): cl.pose("jab_wind", "startup")],
				[start, func(cl: WindClone):
					cl.pose("dash")
					cl.vel = ((c + Vector2(-dir * 4.0, -10.0)) - cl.global_position) / 0.1],
				[start + 0.1, func(cl: WindClone):
					cl.vel = Vector2.ZERO
					cl.pose(["jab_hit", "highkick_hit", "hook_hit", "airkick_hit", "cross_hit", "upper_hit"][i % 6])
					if is_instance_valid(tg):
						_deal(tg, 4.6, 10.0, "super", 0.0, "wind")
						_deal(tg, 4.6, 10.0, "super", 0.0, "")
						var hc: Vector2 = tg.get_hurt_rect().get_center()
						wfx.anim("kreiselfaust_treffer", hc, 70.0, -1.0, randf() * TAU, dir < 0)
						wfx.shards(hc, 0.0 if dir > 0 else PI, 1.0, 8, 280.0, _c("ice"))
						wfx.word(hc + Vector2(randf_range(-30, 30), -40 - i * 4), ["BAM!", "ZACK!", "WUMM!", "BAM!", "ZACK!", "HAA!"][i], _c("white"), 18)
						room.fx.shake(4.0 * FxSettings.factor("shake"), dir)
						Sfx.play("hit_heavy", -2.0)],
				[start + 0.3, func(cl: WindClone): cl.vanish()],
			]))
	if _t >= DUR:
		# final: the figure itself, a rising blow
		_pose = "upper_hit"
		player.global_position.x = c.x - player.facing * 20.0
		wfx.anim("windstoss", c + Vector2(0, -30), 160.0, -1.0, -PI / 2.0)
		wfx.anim("kreiselfaust_treffer", c + Vector2(0, -24), 150.0)
		wfx.ring(c + Vector2(0, -24), 80.0, _c("gold"), 0.4, 6.0)
		wfx.word(c + Vector2(0, -90), "ZUSAMMEN!", _c("gold"), 34)
		_deal(_target, 14.0, 260.0, "super_final", 360.0, "wind")
		caster._posture(_target, 30.0)
		room.fx.flash(0.45 * FxSettings.factor("flash"), Color(0.85, 1.0, 1.0))
		room.fx.shake(12.0 * FxSettings.factor("shake"))
		room.fx.freeze(0.14 * FxSettings.factor("stop"))
		Sfx.play("break", 4.0)
		room.fx.dim(0.2)
		_next("end")


# --- Orkanmantel ----------------------------------------------------------------------

func _cloak() -> void:
	_pose = "super_0"
	var c := _center()
	if _step == 0:
		_step = 1
		for cl in caster.clones.duplicate():
			if is_instance_valid(cl):
				cl.vanish()
		wfx.anim("orkanmantel_ausbruch", c, 170.0, -1.0, 0.0, false, Color(1, 1, 1, 0.9), 1.3)
		wfx.ring(c, 60.0, _c("ice"), 0.4, 5.0)
		wfx.ring(c, 90.0, _c("gold"), 0.5, 4.0)
		wfx.word(c + Vector2(0, -74), "ORKANMANTEL!", _c("gold"), 30)
		room.fx.flash(0.4 * FxSettings.factor("flash"), Color(0.8, 1.0, 1.0))
		room.fx.shake(6.0 * FxSettings.factor("shake"))
		Sfx.play("break")
		caster.mantle_time = caster.mantle_max
		for tg in _targets():
			if tg.get_hurt_rect().get_center().distance_to(c) < 70.0:
				_deal(tg, 8.0, 260.0, "super_final", 120.0, "wind")
	if _t >= 0.4:
		room.fx.dim(0.0)
		_next("end")
