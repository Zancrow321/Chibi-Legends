class_name MondCaster
extends GlutCaster
## Runs the Züge of the fighting style Schwarzmond (docs/stil-schwarzmond.md).
## Shares the frame of GlutCaster (cast, cooldowns, phases, pose, velocity
## hooks for the player) and replaces the rules:
##  - Mondphase (`stage` 0..3 = Neumond, Sichel, Halbmond, Vollmond): every
##    Zug that hits fills one phase, but not the same Zug twice in a row.
##    At Vollmond the next Zug is enhanced for free and empties it. Without
##    hits for 4 s it sinks one phase per second.
##  - L held during the Anlauf still costs 1 Stufe of the Legendenleiste;
##    both together = +25 % Haltungsschaden.
##  - Druckbruch: only enhanced Züge deal Haltungsschaden (x3).
##  - Schattenlarve: 5 s after every Meisterzug (not Mondfinsternis), every
##    Zug hit fills a phase. Can't be extended.
##  - Neumond form (Meisterzug A): 8 s faster Züge and J/K, shorter cooldowns.
##  - Erschöpfung after Mondfinsternis: no enhancement for 10 s.

const DECAY_WAIT := 4.0
const PHASE_NAMES := ["Neumond", "Sichel", "Halbmond", "Vollmond"]
const LARVE_TIME := 5.0

var mfx: MondFx
var larve_time := 0.0
var neumond_time := 0.0
var neumond_max := 8.0
var erschoepft := 0.0
var eclipse_used := false

var _last_zug := ""
var _decay := 0.0
var _vollmond := false  # this activation was enhanced by the Vollmond
var _both := false      # Vollmond + L held: +25 % Haltung
var _charge_k := 0.0
var _hit_any := false
var _cut := false
var _lunge := 0.0
var _dash_dir := Vector2.RIGHT
var _hover := 0.0
var _open := false
var _aura_t := 0.0


func setup(p: Player, st: FightingStyle) -> void:
	super.setup(p, st)
	mfx = MondFx.new()
	mfx.room = world
	mfx.caster = self
	world.add_child(mfx)


func reset_fight() -> void:
	eclipse_used = false
	erschoepft = 0.0


func phase_name() -> String:
	return PHASE_NAMES[clampi(stage, 0, 3)]


func rim_color() -> Color:
	if larve_time > 0.0:
		return MondFx.EMBER
	if neumond_time > 0.0:
		return MondFx.WHITE
	return MondFx.CYAN


func trail_color() -> Color:
	if larve_time > 0.0:
		return Color("ff4a5a")
	if neumond_time > 0.0:
		return Color("e8f4ff")
	return Color("6fe3ff")


func normal_element() -> String:
	return ""


func normal_mul() -> float:
	return 1.1 if neumond_time > 0.0 else 1.0


func normal_speed() -> float:
	return 1.25 if neumond_time > 0.0 else 1.0


func blade_heat() -> float:
	return 0.0


# --- casting -------------------------------------------------------------------

func cast(dir: String) -> bool:
	if busy() or player.in_super:
		return false
	var z := style.zug_in(dir)
	if z == "":
		z = style.zug_in("neutral")
	if z == "" or cooldowns.get(z, 0.0) > 0.0:
		return false
	zug_id = z
	phase = "startup"
	t = 0.0
	frames = style.frames(z).duplicate()
	if neumond_time > 0.0:
		for i in frames.size():
			frames[i] = maxi(2, int(round(frames[i] * 0.75)))
	_vollmond = stage >= 3 and erschoepft <= 0.0
	enhanced = _vollmond
	_both = false
	_decided = false
	params = style.params(z, enhanced)
	_hit_set = {}
	_reported = false
	_step = 0
	_x_start = player.global_position.x
	_y_start = player.global_position.y
	_age = 0.0
	_charge_k = 0.0
	_hit_any = false
	_cut = false
	_lunge = 0.0
	_hover = 0.0
	_open = false
	var cd := float(style.zug(z).get("cd", 1.0))
	cooldowns[z] = cd * (0.6 if neumond_time > 0.0 else 1.0)
	player.move = {}
	if _vollmond:
		stage = 0
		var c := _blade_mid()
		mfx.sichel(c + Vector2(0, -6), Vector2(player.facing, -0.3), 18.0, 0.35, MondFx.WHITE, 1.6)
		fx.word(c + Vector2(-player.facing * 18.0, -60), "VOLLMOND", MondFx.WHITE, 17, -0.05)
		fx.light(c, Color(0.8, 0.9, 1.0), 2.0, 0.7, 0.3)
	_on_start()
	return true


func interrupt() -> void:
	if zug_id in ["entschlossene_abwehr", "schwarze_spur"]:
		player.velocity.x = 0.0
	zug_id = ""
	phase = ""
	countering = false


func _decide_enhanced() -> void:
	_decided = true
	if float(params.get("charge", 0.0)) > 0.0:
		return  # L held charges this Zug instead
	if erschoepft > 0.0:
		return
	if Input.is_action_pressed("special") and (player.gauge >= 100.0 or player.infinite_aura):
		if not player.infinite_aura:
			player.gauge -= 100.0
		_both = enhanced
		enhanced = true
		params = style.params(zug_id, true)
		var c := _blade_mid()
		mfx.shock(c + Vector2(0, 10), 26.0, 0.3, MondFx.WHITE)
		mfx.streaks(c, -PI / 2.0, PI, 10, 200.0, 0.3, rim_color())
		fx.word(c + Vector2(-player.facing * 18.0, -62), "VERSTÄRKT", MondFx.WHITE, 16, -0.05)
		world.fx.flash(0.15 * FxSettings.factor("flash"), Color(0.6, 0.8, 1.0))


# --- per frame ----------------------------------------------------------------

func tick(delta: float) -> void:
	var cd_speed := 1.0 / 0.6 if neumond_time > 0.0 else 1.0
	for z in cooldowns:
		cooldowns[z] = maxf(0.0, cooldowns[z] - delta * cd_speed)
	invuln = maxf(0.0, invuln - delta)
	_stage_flash = maxf(0.0, _stage_flash - delta)
	larve_time = maxf(0.0, larve_time - delta)
	neumond_time = maxf(0.0, neumond_time - delta)
	erschoepft = maxf(0.0, erschoepft - delta)
	if stage > 0:
		if _combo_t > 0.0:
			_combo_t -= delta
			_decay = 1.0
		else:
			_decay -= delta
			if _decay <= 0.0:
				_decay = 1.0
				stage -= 1
	_draw_blade_heat()
	_tick_aura(delta)
	if not busy():
		return
	t += delta
	_age += delta
	if not _decided and _age >= 0.15:
		_decide_enhanced()
	match zug_id:
		"mondschnitt":
			_tick_mondschnitt()
		"mondsichel":
			_tick_mondsichel()
		"aufsteigender_mond":
			_tick_aufsteigend()
		"entschlossene_abwehr":
			_tick_abwehr()
		"schwarze_spur":
			_tick_spur()
		"fallender_mond":
			_tick_fallend()


func _on_start() -> void:
	match zug_id:
		"fallender_mond":
			if player.is_on_floor():
				player.velocity.y = -300.0
			else:
				frames = [6, frames[1], frames[2]]
		"entschlossene_abwehr":
			frames = [frames[0], int(round(float(params.get("stance", 0.5)) * 60.0)), frames[2]]
			var c := player.global_position + Vector2(player.facing * 10.0, -24.0)
			mfx.slash(c, 16.0, -PI / 2.0 - 0.9, -PI / 2.0 + 0.9 if player.facing > 0 else -PI / 2.0 - 0.9 + 1.8, 0.2, MondFx.CYAN, 4.0)


func _on_recovery() -> void:
	if zug_id == "entschlossene_abwehr":
		countering = false


# --- hits, Mondphase, Druckbruch ------------------------------------------------

func on_zug_hit(zid: String, targets: Array) -> void:
	if targets.is_empty():
		return
	if zid == zug_id:
		_hit_any = true
	player.add_gauge(6.0 if zid == zug_id and not _reported else 1.5)
	_combo_t = DECAY_WAIT
	if zid == zug_id and _reported:
		return
	if zid == zug_id:
		_reported = true
	if stage >= 3:
		return
	if larve_time > 0.0 or zid != _last_zug:
		_last_zug = zid
		_set_stage(stage + 1)


func _set_stage(s: int) -> void:
	stage = clampi(s, 0, 3)
	_stage_flash = 0.3
	_combo_t = DECAY_WAIT
	var c := _blade_mid()
	mfx.streaks(c, -PI / 2.0, 1.2, 4 + stage * 2, 150.0, 0.3, rim_color())
	fx.glow(c, Color(rim_color(), 0.6), 8.0 + stage * 4.0, 0.3)
	if stage == 3:
		fx.word(c + Vector2(-player.facing * 16.0, -52), "VOLLMOND!", MondFx.WHITE, 20)
		mfx.sichel(c + Vector2(0, -26), Vector2(-1, -0.2), 14.0, 0.5, MondFx.WHITE, 1.4)


## Ordinary J/K hits keep the Mondphase from sinking.
func on_normal_hit() -> void:
	if stage > 0:
		_combo_t = DECAY_WAIT


## Druckbruch: enhanced hits wear down the Haltung of armored enemies.
func druckbruch(target: Node, amount: float, is_enhanced: bool, from_x: float) -> void:
	if not is_enhanced or not target.has_method("posture_hit"):
		return
	var k := 3.0 * (1.25 if _both else 1.0)
	if target.posture_hit(amount * k, from_x):
		var c: Vector2 = target.get_hurt_rect().get_center()
		mfx.shock(c, 34.0, 0.35, MondFx.WHITE)
		mfx.ink(c, 14, 140.0, 0.6)
		world.fx.shake(5.0 * FxSettings.factor("shake"))
		world.fx.freeze(0.06 * FxSettings.factor("stop"))


func _hit_rect(rect: Rect2, dmg: float, kb: float, prof := "", launch := 0.0, hit_set = null, posture := 1.0) -> Array:
	var targets := GlutHazard.strike(world, rect, dmg, player.global_position.x, kb, prof, launch, hit_set, "")
	for tg in targets:
		druckbruch(tg, dmg * posture, enhanced, player.global_position.x)
	on_zug_hit(zug_id, targets)
	return targets


func _wave(dir: Vector2, dmg: float, r: float, reach: float, speed := 430.0, pierce := false) -> MondWave:
	var w := MondWave.new()
	w.world = world
	w.caster = self
	w.zug_id = zug_id
	w.dir = dir.normalized()
	w.damage = dmg
	w.r = r
	w.reach = reach
	w.speed = speed
	w.pierce = pierce
	w.enhanced = enhanced
	w.rim_col = rim_color()
	w.profile = "heavy" if enhanced else "light"
	w.knockback = 140.0 if enhanced else 90.0
	w.global_position = player.global_position + Vector2(player.facing * 18.0, -22.0) + w.dir * 6.0
	world.attacks.add_child(w)
	return w


func _charging(max_charge: float) -> bool:
	return max_charge > 0.0 and Input.is_action_pressed("special") and t < _f(0) + max_charge


func _charge_fx(k: float) -> void:
	_aura_t -= get_physics_process_delta_time()
	if _aura_t > 0.0:
		return
	_aura_t = 0.03
	var c := _blade_mid() + Vector2(0, -6)
	for i in 2:
		var a := randf() * TAU
		var from := c + Vector2(cos(a), sin(a)) * randf_range(24, 40)
		fx.glow(from, Color(rim_color(), 0.7), randf_range(1.5, 3.0), 0.2, (c - from) / 0.2, 0.3)
	fx.glow(c, Color(rim_color(), 0.3 + k * 0.4), 6.0 + k * 10.0, 0.08)
	fx.light(c, rim_color(), 0.6 + k * 1.4, 0.4 + k * 0.3, 0.05)


# --- Mondschnitt -----------------------------------------------------------------

func _tick_mondschnitt() -> void:
	var charge := float(params.get("charge", 0.0))
	if phase == "startup":
		if _charging(charge) or t < _f(0):
			if charge > 0.0 and t >= _f(0):
				_charge_fx(clampf((t - _f(0)) / charge, 0.0, 1.0))
			return
		if charge > 0.0:
			_charge_k = clampf((t - _f(0)) / charge, 0.0, 1.0)
		_next_phase()
	elif phase == "active":
		var hits: Array = params.get("hits", [5, 5, 8])
		var due := int(t / maxf(0.001, _f(1)) * hits.size()) + 1
		while _step < mini(due, hits.size()):
			var i := _step
			_step += 1
			var last := _step == hits.size()
			var dmg := float(hits[i])
			if charge > 0.0:
				dmg = lerpf(dmg, 16.0, _charge_k)
			var w := float(params.get("w", 46))
			var h := float(params.get("h", 34))
			var r := _front_rect(w * 0.5 + 4.0, -24, w, h)
			var tg := _hit_rect(r, dmg, 150.0 if last else 35.0, "heavy" if last else "light", 0.0, {}, float(params.get("posture", 1.0)))
			_lunge = 70.0 if not last else 120.0
			var c := player.global_position + Vector2(player.facing * 8.0, -24.0)
			var down := i % 2 == 0
			var a0 := -1.3 if down else 1.0
			var a1 := 1.0 if down else -1.3
			if player.facing < 0:
				a0 = PI - a0
				a1 = PI - a1
			mfx.slash(c, w * 0.6, a0, a1, 0.2 if not last else 0.3, rim_color(), 6.0 if not last else 10.0)
			if last:
				fx.word(player.global_position + Vector2(player.facing * 40.0, -48), "ZASH!", MondFx.WHITE, 22 if charge <= 0.0 else 22 + int(_charge_k * 10.0))
				world.fx.shake((3.0 + _charge_k * 4.0) * FxSettings.factor("shake"), player.facing)
				if params.get("extra_wave", false):
					_wave(Vector2(player.facing, 0), 4.0, 14.0, 120.0)
			if tg.size() > 0:
				mfx.ink(tg[0].get_hurt_rect().get_center(), 4 if not last else 8, 90.0, 0.4)
		if t >= _f(1):
			_next_phase()
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


# --- Mondsichel -------------------------------------------------------------------

func _tick_mondsichel() -> void:
	var charge := float(params.get("charge", 0.0))
	if phase == "startup":
		if _charging(charge) or t < _f(0):
			_charge_fx(clampf((t - _f(0)) / maxf(0.01, charge), 0.0, 1.0) if charge > 0.0 and t >= _f(0) else t / maxf(0.01, _f(0)) * 0.4)
			return
		if charge > 0.0:
			_charge_k = clampf((t - _f(0)) / charge, 0.0, 1.0)
		_next_phase()
		var blade := float(params.get("blade", 4))
		var near := _hit_rect(_front_rect(22, -24, 36, 34), blade, 60.0, "light", 0.0, {})
		var dmg := float(params.get("damage", 7))
		if charge > 0.0:
			dmg = lerpf(dmg, 14.0, _charge_k)
		if near.size() > 0:
			dmg = minf(dmg, maxf(2.0, 11.0 - blade))  # blade + wave stay capped
		var scale := float(params.get("scale", 1.0)) * (1.0 + _charge_k * 0.3)
		_wave(Vector2(player.facing, 0), dmg, float(params.get("h", 34)) * 0.75 * scale, float(params.get("range", 240)),
				float(params.get("speed", 430)), params.get("pierce", false))
		var c := player.global_position + Vector2(player.facing * 14.0, -24.0)
		var a0 := -1.4 if player.facing > 0 else PI + 1.4
		var a1 := 1.1 if player.facing > 0 else PI - 1.1
		mfx.slash(c, 18.0, a0, a1, 0.2, rim_color(), 8.0)
		fx.word(player.global_position + Vector2(player.facing * 46.0, -50), "KSHH!", MondFx.CYAN if larve_time <= 0.0 else MondFx.EMBER, 22)
		world.fx.shake(3.0 * FxSettings.factor("shake"), player.facing)
		_lunge = -40.0
	elif phase == "active" and t >= _f(1):
		_next_phase()
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


# --- Aufsteigender Mond -------------------------------------------------------------

func _tick_aufsteigend() -> void:
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
			var w := float(params.get("w", 44))
			var h := float(params.get("h", 52))
			var r := Rect2(player.global_position.x + (player.facing * 14.0) - w * 0.5, player.global_position.y - 12.0 - h, w, h + 8.0)
			_hit_rect(r, float(params.get("damage", 8)), 30.0, "heavy", float(params.get("launch", 360)), {})
			var c := player.global_position + Vector2(player.facing * 6.0, -20.0)
			var a0 := 0.9 if player.facing > 0 else PI - 0.9
			var a1 := -1.9 if player.facing > 0 else PI + 1.9
			mfx.slash(c, maxf(20.0, w * 0.5), a0, a1, 0.25, rim_color(), 9.0)
			mfx.streaks(c + Vector2(0, -20), -PI / 2.0, 0.3, 8, 260.0, 0.3, rim_color())
			fx.word(c + Vector2(player.facing * 20.0, -48), "ZASH!", MondFx.WHITE, 20)
			if params.get("wave", false):
				_wave(Vector2(player.facing * 0.72, -0.7), float(params.get("damage", 8)) * 0.8, 16.0, 200.0, 420.0)
	elif phase == "active" and t >= _f(1):
		_next_phase()
	elif phase == "recovery":
		if float(params.get("follow", 0)) > 0.0 and _hit_any and Input.is_action_just_pressed("special"):
			player.velocity.y = -float(params.follow)
			player.world.afterimages.add(player.sprite.snapshot(), Color(0.3, 0.4, 0.8, 0.6))
			mfx.streaks(player.global_position + Vector2(0, -10), PI / 2.0, 0.3, 6, 180.0, 0.25, rim_color())
			zug_id = ""
			phase = ""
			return
		if t >= _f(2):
			_next_phase()


# --- Entschlossene Abwehr -----------------------------------------------------------

func _tick_abwehr() -> void:
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
			countering = true
	elif phase == "active":
		var c := player.global_position + Vector2(player.facing * 10.0, -24)
		var perfect := t <= float(params.get("perfect", 0.15))
		var pulse := 0.5 + 0.5 * sin(t * 30.0)
		fx.glow(c, Color(MondFx.WHITE if perfect else MondFx.CYAN, 0.25 + 0.2 * pulse), 18.0, 0.05, Vector2.ZERO, 1.0)
		countering = perfect
		if t >= _f(1):
			countering = false
			_next_phase()
	elif phase == "counter":
		var at := 0.03 if params.get("fast", false) else 0.09
		if _step == 0 and t >= at:
			_step = 1
			var dmg := float(params.get("counter_damage", 14))
			_hit_rect(_front_rect(28, -26, 66, 44), dmg, 240.0, "heavy", 100.0, _hit_set, 1.5)
			var c2 := player.global_position + Vector2(player.facing * 16.0, -24.0)
			var a0 := -1.5 if player.facing > 0 else PI + 1.5
			var a1 := 1.2 if player.facing > 0 else PI - 1.2
			mfx.slash(c2, 26.0, a0, a1, 0.3, MondFx.WHITE, 12.0)
			fx.word(c2 + Vector2(player.facing * 20.0, -40), "ZASH!", MondFx.WHITE, 26)
		if t >= at + 0.22:
			_next_phase()
	elif phase == "recovery" and t >= _f(2) * 0.6:
		_next_phase()


## Perfect timing (first 0.15 s of the guard): counter.
func try_counter(from_x: float, projectile: Node = null) -> bool:
	if zug_id != "entschlossene_abwehr" or phase != "active" or t > float(params.get("perfect", 0.15)):
		return false
	countering = false
	invuln = 0.45
	phase = "counter"
	t = 0.0
	_step = 0
	_hit_set = {}
	player.facing = 1 if from_x >= player.global_position.x else -1
	var c := player.global_position + Vector2(player.facing * 10.0, -24.0)
	mfx.shock(c, 36.0, 0.35, MondFx.WHITE)
	mfx.streaks(c, PI if player.facing > 0 else 0.0, 1.0, 16, 260.0, 0.35, MondFx.CYAN)
	fx.word(c + Vector2(0, -44), "KONTER!", MondFx.WHITE, 28)
	world.fx.flash(0.2 * FxSettings.factor("flash"), Color(0.75, 0.85, 1.0))
	world.fx.freeze(0.12 * FxSettings.factor("stop"))
	world.fx.shake(5.0 * FxSettings.factor("shake"))
	player.add_gauge(15.0)
	_push_back()
	if projectile != null and projectile.has_method("burn"):
		projectile.burn()
	return true


## Too early: the guard only takes the edge off (block damage, no stun).
func guard_hit(damage: float, from_x: float, _source: Node) -> bool:
	if zug_id != "entschlossene_abwehr" or phase != "active":
		return false
	var dir := signf(player.global_position.x - from_x)
	player._block_hit(damage, dir if dir != 0.0 else -player.facing)
	mfx.slash(player.global_position + Vector2(player.facing * 10.0, -24), 18.0, -1.0, 1.0, 0.15, MondFx.CYAN, 4.0)
	_push_back()
	return true


func _push_back() -> void:
	if not params.get("push", false):
		return
	var c := player.global_position + Vector2(0, -22)
	mfx.shock(c, 60.0, 0.35, MondFx.CYAN)
	fx.word(c + Vector2(0, -50), "DOOM", MondFx.CYAN, 20)
	for e in world.get_tree().get_nodes_in_group("targets"):
		if (e.global_position - player.global_position).length() < 80.0:
			e.take_hit(240.0, player.global_position.x)


# --- Schwarze Spur -------------------------------------------------------------------

func _tick_spur() -> void:
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
			_x_start = player.global_position.x
			_y_start = player.global_position.y
			_dash_dir = Vector2(player.facing, 0)
			if params.get("chase", false):
				var tg := _airborne_target(220.0)
				if tg != null:
					_dash_dir = (tg.get_hurt_rect().get_center() + Vector2(0, 20) - player.global_position).normalized()
					player.facing = 1 if _dash_dir.x >= 0.0 else -1
			invuln = float(params.get("invuln", 0.0))
			mfx.ink(player.global_position + Vector2(0, -20), 10, 80.0, 0.5)
			fx.word(player.global_position + Vector2(0, -52), "SHH", MondFx.CYAN, 18)
	elif phase == "active":
		_ghost_t -= get_physics_process_delta_time()
		if _ghost_t <= 0.0:
			_ghost_t = 0.022
			player.world.afterimages.add(player.sprite.snapshot(), Color(0.12, 0.12, 0.25, 0.85), Vector2.ZERO, 0.3)
			mfx.streaks(player.global_position + Vector2(0, -20), _dash_dir.angle() + PI, 0.25, 2, 200.0, 0.2, rim_color())
		if player._queued in ["light", "heavy"]:
			player._queued = ""
			_cut = true
		if t >= _f(1) or player.is_on_wall():
			_end_dash()
			_next_phase()
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


func _airborne_target(max_d: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_d
	for e in world.get_tree().get_nodes_in_group("targets"):
		if e.get("on_ground") != false:
			continue
		var d: float = (e.global_position - player.global_position).length()
		if d < best_d:
			best = e
			best_d = d
	return best


func _end_dash() -> void:
	var a := Vector2(_x_start, _y_start)
	var b := player.global_position
	var ghosts := int(params.get("ghosts", 0))
	if not _cut and ghosts <= 0:
		return
	var r := Rect2(Vector2(minf(a.x, b.x) - 10.0, minf(a.y, b.y) - 46.0), Vector2(absf(b.x - a.x) + 20.0, absf(b.y - a.y) + 48.0))
	var dmg := float(params.get("cut", 9)) if _cut else 0.0
	if _cut:
		_hit_rect(r, dmg, 160.0, "heavy", 60.0, {}, 1.2)
		fx.glow_line(a + Vector2(0, -24), b + Vector2(0, -24), Color(MondFx.WHITE, 1.0), 3.0)
		mfx.slash((a + b) * 0.5 + Vector2(0, -24), maxf(20.0, a.distance_to(b) * 0.5), PI if b.x > a.x else 0.0, 0.0 if b.x > a.x else PI, 0.3, rim_color(), 3.0)
		fx.word(b + Vector2(player.facing * 10.0, -56), "ZASH!", MondFx.WHITE, 24)
		world.fx.freeze(0.05 * FxSettings.factor("stop"))
	for i in ghosts:
		var p := a.lerp(b, (i + 1.0) / (ghosts + 1.0))
		player.world.afterimages.add(player.sprite.snapshot(), Color(0.2, 0.25, 0.5, 0.9), p - b, 0.4)
		_hit_rect(Rect2(p + Vector2(-22, -46), Vector2(44, 48)), 4.0, 80.0, "light", 0.0, {})
		mfx.slash(p + Vector2(0, -24), 16.0, -1.2, 1.2, 0.25, rim_color(), 5.0)


# --- Fallender Mond -------------------------------------------------------------------

func _tick_fallend() -> void:
	if phase == "startup":
		if t >= _f(0):
			if params.get("rain", false):
				phase = "active"
				t = 0.0
				_hover = 0.3
				_wave(Vector2(player.facing * 0.75, 0.66), float(params.get("damage", 9)), 16.0, 220.0, 460.0)
				fx.word(player.global_position + Vector2(player.facing * 30.0, -30), "KSHH!", MondFx.CYAN, 20)
				return
			phase = "fall"
			t = 0.0
			_hit_set = {}
			fx.glow(_blade_mid(), Color(rim_color(), 0.8), 14.0, 0.2)
	elif phase == "active":
		_hover -= get_physics_process_delta_time()
		if _hover <= 0.0:
			_next_phase()
	elif phase == "fall":
		_ghost_t -= get_physics_process_delta_time()
		if _ghost_t <= 0.0:
			_ghost_t = 0.03
			player.world.afterimages.add(player.sprite.snapshot(), Color(0.15, 0.15, 0.3, 0.6))
			if params.get("spin", false):
				var c0 := player.global_position + Vector2(0, -18)
				mfx.slash(c0, 24.0, t * 30.0, t * 30.0 + 2.2, 0.12, rim_color(), 5.0)
		var spin: bool = params.get("spin", false)
		var w := 60.0 if spin else 34.0
		var r := Rect2(player.global_position + Vector2(-w * 0.5, -24), Vector2(w, 30))
		_hit_rect(r, float(params.get("damage", 9)) * (0.8 if spin else 1.0), 40.0, "heavy", -260.0, _hit_set, float(params.get("posture", 1.0)))
		if player.is_on_floor() and t > 0.02:
			_impact()
			_next_phase()
		elif t > 0.9:
			_next_phase()
	elif phase == "recovery" and t >= _f(2) + (0.4 if _open else 0.0):
		_next_phase()


func _impact() -> void:
	var p := player.global_position
	var wv := float(params.get("wave", 50))
	mfx.shock(p + Vector2(0, -2), wv + 10.0, 0.35, rim_color())
	mfx.ink(p + Vector2(0, -4), 12, 140.0, 0.6)
	mfx.sichel(p + Vector2(player.facing * 12.0, -14), Vector2(0, 1), 18.0, 0.25, MondFx.WHITE, 1.5)
	fx.word(p + Vector2(0, -56), "DOOM!", MondFx.WHITE, 30)
	world.fx.shake(6.0 * FxSettings.factor("shake"))
	world.fx.punch(0.04)
	world.fx.freeze(0.05 * FxSettings.factor("stop"))
	var tg := _hit_rect(Rect2(p.x - wv, p.y - 22.0, wv * 2.0, 24.0), float(params.get("wave_damage", 6)), 130.0, "heavy", 140.0, {}, float(params.get("posture", 1.0)))
	if tg.is_empty() and not _hit_any:
		_open = true  # a whiffed heavy cut leaves you open
		fx.word(p + Vector2(0, -36), "offen", Color("9aa0b8"), 13)


# --- Mondfinsternis cost / Larve / Neumond (set by MondSuper) ---------------------

func start_larve() -> void:
	larve_time = LARVE_TIME


func start_neumond(seconds: float) -> void:
	neumond_time = seconds
	neumond_max = seconds


# --- movement & pose for the player --------------------------------------------

func drive_velocity(v: Vector2, delta: float, on_floor: bool) -> Vector2:
	match zug_id:
		"schwarze_spur":
			if phase == "active":
				var spd := float(params.get("dist", 120)) / _f(1)
				return _dash_dir * spd
			return Vector2(move_toward(v.x, 0.0, 2400.0 * delta), minf(v.y + Player.GRAVITY * delta * (0.3 if phase == "startup" else 1.0), Player.MAX_FALL))
		"fallender_mond":
			if phase == "fall":
				return Vector2(0.0, float(params.get("fall", 760)))
			if phase == "active":
				return Vector2(0.0, 0.0)  # Schwarzer Regen hovers
			if phase == "startup":
				return Vector2(v.x * 0.9, minf(v.y + Player.GRAVITY * 0.8 * delta, 120.0))
		"entschlossene_abwehr":
			return Vector2(0.0, minf(v.y + Player.GRAVITY * delta, Player.MAX_FALL))
	if _lunge != 0.0:
		var lv := _lunge
		_lunge = move_toward(_lunge, 0.0, 900.0 * delta)
		return Vector2(player.facing * lv, minf(v.y + Player.GRAVITY * delta, Player.MAX_FALL))
	var gx := move_toward(v.x, 0.0, (1800.0 if on_floor else 400.0) * delta)
	var fall := Player.GRAVITY * delta * (0.5 if not on_floor and phase == "active" else 1.0)
	return Vector2(gx, minf(v.y + fall, Player.MAX_FALL))


# --- blade, Larve and Neumond visuals ----------------------------------------------

## The blade: a cold rim when the Mondphase rises, black core in Neumond.
func _draw_blade_heat() -> void:
	if not player.sprite.visible:
		return
	var glow := 0.0
	if stage > 0:
		glow = 0.25 + stage * 0.2
	if neumond_time > 0.0 or larve_time > 0.0:
		glow = 1.0
	if busy() and glow < 0.35:
		glow = 0.35
	if glow <= 0.0:
		return
	var line := blade_now()
	var a: Vector2 = line[0]
	var e: Vector2 = line[1]
	var flick := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.025)
	fx.glow_line(a.lerp(e, 0.2), e, Color(rim_color(), 0.75 * glow * flick), 1.5 + glow * 1.5)
	if _stage_flash > 0.0:
		fx.glow_line(a, e, Color(1, 1, 1, _stage_flash * 2.0), 4.0)


func _tick_aura(delta: float) -> void:
	if neumond_time <= 0.0 and larve_time <= 0.0:
		return
	_aura_t -= delta
	if _aura_t > 0.0:
		return
	_aura_t = 0.05
	var c := player.global_position + Vector2(randf_range(-8, 8), randf_range(-36, -2))
	if larve_time > 0.0:
		fx.glow(c, Color(MondFx.RED, 0.5), randf_range(4.0, 7.0), 0.4, Vector2(0, -50), 0.2)
		mfx.ink(c, 1, 30.0, 0.5)
	else:
		mfx.streaks(c, -PI / 2.0, 0.2, 1, 90.0, 0.3, MondFx.WHITE)
		mfx.ink(c, 1, 20.0, 0.4)


## Head centre in the world (the creator figure is ~2.8 heads tall).
func head_pos() -> Vector2:
	var sp := player.sprite
	if sp.use_body and sp.body != null and sp.body._hair != null:
		return sp.body._hair.global_position + Vector2(player.facing * 3.5, -8.0)  # neck anchor -> face
	return player.global_position + Vector2(player.facing * 2.5, -44.0)


## Ink layer: the Schattenlarve over the front half of the face, the black
## blade of the Neumond form.
func draw_ink(ci: CanvasItem) -> void:
	if not player.sprite.visible:
		return
	if neumond_time > 0.0:
		var line := blade_now()
		ci.draw_line(line[0], line[1], Color(MondFx.INK, 0.9), 3.0, true)
	if larve_time <= 0.0:
		return
	var grow := clampf((LARVE_TIME - larve_time) / 0.35, 0.0, 1.0) * clampf(larve_time / 0.4, 0.0, 1.0)
	if grow <= 0.0:
		return
	var f := float(player.facing)
	var h := head_pos()
	var pts := PackedVector2Array()
	for q in [Vector2(-0.5, -6.5), Vector2(2.5, -7.0), Vector2(5.5, -5.0), Vector2(6.8, -1.0), Vector2(6.2, 3.0),
			Vector2(4.0, 5.5), Vector2(1.0, 6.0), Vector2(-0.5, 4.0)]:
		pts.append(h + Vector2(q.x * f, q.y) * grow)
	ci.draw_colored_polygon(pts, Color(MondFx.INK, 0.95))
	# a short curved horn above the brow
	var horn := PackedVector2Array([h + Vector2(2.0 * f, -6.5) * grow, h + Vector2(7.5 * f, -13.0) * grow, h + Vector2(4.8 * f, -5.5) * grow])
	ci.draw_colored_polygon(horn, Color(MondFx.INK, 0.95))


func draw_add(ci: CanvasItem) -> void:
	if not player.sprite.visible or larve_time <= 0.0:
		return
	var grow := clampf((LARVE_TIME - larve_time) / 0.35, 0.0, 1.0) * clampf(larve_time / 0.4, 0.0, 1.0)
	if grow <= 0.0:
		return
	var f := float(player.facing)
	var h := head_pos()
	var crack := Color(MondFx.WHITE, 0.8 * grow)
	ci.draw_polyline(PackedVector2Array([h + Vector2(1.0 * f, -6.0), h + Vector2(2.5 * f, -2.5), h + Vector2(1.8 * f, 1.0), h + Vector2(3.5 * f, 4.5)]), crack, 0.7, true)
	ci.draw_line(h + Vector2(2.5 * f, -2.5), h + Vector2(5.5 * f, -3.5), crack, 0.6, true)
	var eye := h + Vector2(4.0 * f, -1.0)
	var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.012)
	var tex := GlutFx.glow_texture()
	ci.draw_texture_rect(tex, Rect2(eye - Vector2(6, 6), Vector2(12, 12)), false, Color(MondFx.EMBER, 0.6 * grow * pulse))
	ci.draw_circle(eye, 1.1, Color(1.0, 0.5, 0.5, grow))
