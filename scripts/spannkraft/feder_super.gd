class_name FederSuper
extends Node2D
## Meisterzug of Spannkraft (costs 3 Stufen of the Legendenleiste). Common
## intro: the figure grins and smacks a fist into the palm, a manga cut-in.
## Then one of three supers:
##  dampfhagel   Siedepuls: heat shimmer and grey steam rise, then a fast
##               barrage of stretched fists in front (one target)
##  federkanone  Prallform: one arm swells up like a barrel in spring coils
##               with a steel-blue Eisenwille sheen, then one giant blast
##               that throws light enemies far away
##  grenzenlos   Freier Lauf: a colourful comic burst, then 8 s free rules
##               (FederCaster.free_time) and a big shock at the end
## The intro freezes the world; afterwards hit-stop applies.

const INTRO := 0.75

var room: TrainingRoom
var player: Player
var caster: FederCaster
var ffx: FederFx
var variant := "dampfhagel"
var title := "Meisterzug"

var phase := "intro"
var _t := 0.0
var _step := 0
var _target: Node2D = null
var _dealt: Dictionary = {}
var _pose := 5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.z_index = CombatFx.FOCUS_Z
	player.sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	var cfx := room.fx
	cfx.hold(true)
	cfx.dim(0.85)
	cfx.punch(0.18)
	cfx.flash(0.25 * FxSettings.factor("flash"), Color(1.0, 0.9, 0.55))
	if room.hud != null:
		room.hud.show_cutin(title + "!", caster.style.color("coral"))
	_target = _nearest(340.0)
	if _target != null:
		player.facing = 1 if _target.global_position.x >= player.global_position.x else -1
	ffx.word(_center() + Vector2(0, -46), "HEHE!", caster.style.color("yellow"), 22)
	Sfx.play("super_flash")


# --- helpers -----------------------------------------------------------------------

func _c(k: String) -> Color:
	return caster.style.color(k)


func _center() -> Vector2:
	return player.global_position + Vector2(0, -20)


func _shoulder() -> Vector2:
	return player.global_position + Vector2(player.facing * 3.0, -27.0)


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


func _deal(t: Node2D, dmg: float, kb: float, profile := "super", launch := 0.0) -> void:
	var dealt := room.deal_hit(t, dmg, "", player.global_position.x, kb, profile, launch)
	var id := t.get_instance_id()
	if not _dealt.has(id):
		_dealt[id] = [t, 0]
	_dealt[id][1] += dealt
	player.on_attack_hit()


func _show_totals() -> void:
	for id in _dealt:
		var e: Array = _dealt[id]
		if is_instance_valid(e[0]) and e[1] > 0:
			room.numbers.spawn_number(e[0].head_position() + Vector2(0, -14), e[1], _c("yellow"), id + 1, true)
	_dealt.clear()


func _front(x0: float, w: float, y_top: float, h: float) -> Rect2:
	var x := player.global_position.x + (x0 if player.facing > 0 else -x0 - w)
	return Rect2(x, player.global_position.y + y_top, w, h)


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
		return
	_t += delta
	match phase:
		"intro":
			_intro()
		"steam":
			_steam_up()
		"barrage":
			_barrage()
		"swell":
			_swell()
		"blast":
			_blast()
		"free":
			_free_burst()
		"end":
			if _t >= 0.45:
				_finish()
	if phase != "end" or _t < 0.2:
		_set_pose(_pose)


func _intro() -> void:
	_set_pose(1 if _t < 0.35 else 3)
	if _step == 0 and _t >= 0.35:
		_step = 1
		# fist into the palm
		ffx.burst("stossring", _shoulder() + _fwd(8, 4), 60.0, 0.3)
		ffx.word(_center() + Vector2(0, -62), "KLATSCH!", _c("white"), 20)
		room.fx.flash(0.3 * FxSettings.factor("flash"), Color(1.0, 0.92, 0.6))
		Sfx.play("hit_heavy")
	if _t >= INTRO:
		room.fx.hold(false)
		room.fx.dim(0.55)
		match variant:
			"federkanone":
				_next("swell")
			"grenzenlos":
				_next("free")
			_:
				_next("steam")


func _finish() -> void:
	_show_totals()
	room.fx.dim(0.0)
	room.fx.hold(false)
	player.z_index = 0
	player.in_super = false
	player.sprite.process_mode = Node.PROCESS_MODE_INHERIT
	queue_free()


# --- Siedepuls: Dampfhagel ---------------------------------------------------------

func _steam_up() -> void:
	_set_pose(6)
	ffx.steam(_center() + Vector2(randf_range(-8, 8), 6), 3, 10.0)
	if _step == 0:
		_step = 1
		ffx.burst("dampfhagel", _center() + Vector2(0, -8), 110.0, 0.6, 0.0, false, Color(1, 1, 1, 0.85))
		ffx.word(_center() + Vector2(0, -64), "SIEDEPULS!", _c("orange"), 24)
		room.fx.flash(0.2 * FxSettings.factor("flash"), Color(1.0, 0.6, 0.4))
		Sfx.play("dash", 4.0)
	ffx.glow(_center(), Color(_c("orange"), 0.25), 30.0, 0.06)
	if _t >= 0.45:
		_next("barrage")


func _barrage() -> void:
	const HITS := 24
	const DUR := 1.1
	_set_pose(3 if int(_t * 30.0) % 2 == 0 else 1)
	var sh := _shoulder()
	ffx.steam(_center(), 1, 10.0)
	# one turn allowed during the barrage
	var dx := Input.get_axis("move_left", "move_right")
	if _step < 50 and dx != 0.0 and signf(dx) != player.facing:
		player.facing = 1 if dx > 0.0 else -1
		_step += 50
	for i in 4:
		var tip := sh + _fwd(randf_range(40, 92), randf_range(-16, 14))
		ffx.limb(sh + Vector2(0, randf_range(-3, 3)), tip, caster._skin, 3.4, 4.6)
	if randf() < 0.6:
		ffx.burst("prasselfaust", sh + _fwd(78, -2), 90.0, 0.14, randf_range(-0.3, 0.3), player.facing < 0, Color(1, 1, 1, 0.8), 0.7)
	if randf() < 0.3:
		ffx.speedlines(sh + _fwd(60), 0.0 if player.facing > 0 else PI, 3, 50.0, _c("white"))
	var done := _step % 50
	var due := mini(HITS, int(_t / DUR * HITS))
	while done < due:
		done += 1
		_step += 1
		for tg in _targets():
			if _front(4, 104, -50, 54).intersects(tg.get_hurt_rect()):
				_deal(tg, 2.4, 20.0, "super", 0.0)
		if done % 6 == 0:
			ffx.word(sh + _fwd(70, -30 + randf_range(-10, 10)), "PRASSEL!", _c("yellow"), 16)
			room.fx.shake(2.0 * FxSettings.factor("shake"), player.facing)
			Sfx.play("hit_light")
	if _t >= DUR + 0.05:
		# last blow
		var tip2 := sh + _fwd(96, 0)
		ffx.limb(sh, tip2, caster._skin, 4.6, 7.0)
		ffx.burst("stossring", tip2, 130.0, 0.45)
		ffx.burst("schnappfaust", sh + _fwd(60), 140.0, 0.3, 0.0, player.facing < 0)
		ffx.word(tip2 + Vector2(0, -40), "DAMPFHAGEL!", _c("white"), 30)
		for tg in _targets():
			if _front(4, 120, -56, 60).intersects(tg.get_hurt_rect()):
				_deal(tg, 16.0, 300.0, "super_final", 120.0)
		room.fx.flash(0.35 * FxSettings.factor("flash"), Color(1.0, 0.85, 0.5))
		room.fx.shake(9.0 * FxSettings.factor("shake"), player.facing)
		room.fx.freeze(0.12 * FxSettings.factor("stop"))
		Sfx.play("break")
		room.fx.dim(0.2)
		_pose = 3
		_next("end")


# --- Prallform: Federkanone ------------------------------------------------------------

func _swell() -> void:
	_set_pose(1)
	var k := clampf(_t / 0.8, 0.0, 1.0)
	var sh := _shoulder()
	var arm_c := sh + _fwd(-10.0 - 8.0 * k, 2.0)
	var r := lerpf(5.0, 22.0, k)
	var steel := Color(_c("steel"), 0.35 + 0.3 * k)
	# spring coils along the arm
	for i in 3:
		ffx.ball(arm_c + _fwd(-i * r * 0.55, 0.0), r * (1.0 - i * 0.18), caster._skin, steel)
	if randf() < 0.4:
		ffx.burst("eisenwille", arm_c, r * 3.2, 0.2, randf() * TAU, false, Color(1, 1, 1, 0.6), 0.8)
	ffx.glow(arm_c, Color(_c("steel"), 0.3 * k), r * 2.0, 0.06)
	if _step == 0 and k > 0.3:
		_step = 1
		ffx.word(_center() + Vector2(0, -64), "PRALLFORM!", _c("steel"), 24)
		Sfx.play("swing_heavy", 4.0)
	if _step == 1 and k > 0.75:
		_step = 2
		ffx.ring(arm_c, 50.0, _c("white"), 0.3, 4.0)
		room.fx.dim(0.9)
	if _t >= 0.8:
		_next("blast")


func _blast() -> void:
	_set_pose(3)
	var sh := _shoulder()
	var k := clampf(_t / 0.12, 0.0, 1.0)
	var tip := sh + _fwd(lerpf(10.0, 110.0, k), 0.0)
	ffx.limb(sh, tip, caster._skin, 9.0, 18.0, Color(_c("steel"), 0.5))
	if _step == 0 and k >= 1.0:
		_step = 1
		ffx.burst("federkanone", sh + _fwd(170, -4), 300.0, 0.6, 0.0, player.facing < 0)
		ffx.burst("stossring", tip, 160.0, 0.45)
		ffx.burst("eisenwille", tip, 120.0, 0.4)
		ffx.speedlines(sh + _fwd(120), 0.0 if player.facing > 0 else PI, 14, 90.0, _c("white"), 0.3)
		ffx.word(tip + Vector2(0, -60), "FEDERKANONE!", _c("white"), 34)
		for tg in _targets():
			if _front(0, 300, -90, 100).intersects(tg.get_hurt_rect()):
				var tough: bool = tg.has_method("is_elite") and tg.is_elite()
				_deal(tg, 68.0, 260.0 if tough else 520.0, "super_final", 160.0)
				if tg.get("status") is Dictionary:
					tg.status["taumel"] = FederCaster.TAUMEL_TIME
		room.fx.flash(0.5 * FxSettings.factor("flash"), Color(0.85, 0.92, 1.0))
		room.fx.shake(14.0 * FxSettings.factor("shake"), player.facing)
		room.fx.freeze(0.16 * FxSettings.factor("stop"))
		Sfx.play("break", 4.0)
		player.velocity.x = -player.facing * 220.0  # the recoil pushes the figure back
	if _t >= 0.4:
		room.fx.dim(0.25)
		_pose = 3
		_next("end")


# --- Grenzenlos: Freier Lauf ------------------------------------------------------------

func _free_burst() -> void:
	_set_pose(5)
	if _step == 0:
		_step = 1
		ffx.burst("grenzenlos", _center(), 200.0, 0.7)
		ffx.burst("stossring", _center(), 120.0, 0.45)
		ffx.word(_center() + Vector2(0, -74), "GRENZENLOS!", _c("yellow"), 34)
		ffx.word(_center() + Vector2(0, -50), "HAHAHA!", _c("sky"), 20)
		var cols := [_c("yellow"), _c("sky"), _c("coral")]
		for i in 3:
			ffx.ring(_center(), 50.0 + i * 25.0, cols[i], 0.45 + i * 0.1, 5.0)
		ffx.motes(_center(), 24, 30.0, _c("yellow"), 0.9)
		room.fx.flash(0.45 * FxSettings.factor("flash"), Color(1.0, 0.95, 0.6))
		room.fx.shake(6.0 * FxSettings.factor("shake"))
		Sfx.play("break")
		caster.free_time = caster.free_max
		caster.chain_left = FederCaster.FREE_CHAIN
		for tg in _targets():
			if tg.get_hurt_rect().get_center().distance_to(_center()) < 90.0:
				_deal(tg, 10.0, 200.0, "super_final", 140.0)
	if _t >= 0.35:
		room.fx.dim(0.0)
		_next("end")
