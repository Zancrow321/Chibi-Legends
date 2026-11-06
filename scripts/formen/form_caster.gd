class_name FormCaster
extends GlutCaster
## Runs the Züge of every Baukasten fighting style (assets/combat/styles with
## "caster": "form"). Same interface as GlutCaster; what a Zug does comes
## from its "kind" and params in the JSON (see docs/formen-baukasten.md):
##   hieb      melee hits in front (hits, damage, len, h, sides, launch, pull, lunge)
##   geschoss  projectiles (count, spread, speed, dist, size, pierce, grav, angle,
##             homing, boomerang, burst, delay)
##   sturm     dash attack (dist, damage, back, trail)
##   saeule    columns out of the ground in front (at, width, height, launch,
##             count, step, delay, ride)
##   sturz     dive from the air / after a hop (damage, radius, waves,
##             wave_damage, aftershock, crater)
##   konter    counter stance (stance, counter_damage, reflect, heal, buff)
##   aura      buff (buff, bonus, heal, speed, armor, hp_cost, nova, nova_radius)
##   feld      field on the ground (at, width, life, tick, damage, pull, launch)
##   strahl    beam (len, width, damage, tick, up, push)
##   schritt   teleport behind the nearest target (dist, behind, damage)
##   regen     pieces falling from above (count, width, at, damage, big)
##   wirbel    spin around yourself (radius, hits, damage, pull, drift, lift)
## Every style has one Kern (its own rule), set in "kern":
##   rhythmus  different Züge in one combo raise the stage 1..3; at 3 the next
##             Zug gets an extra hit and +10 Leiste
##   ladung    each Zug that hits adds 1 charge; at 5: 6 s Überladung
##             (J/K +25 % with the style's element)
##   marken    hits put marks on targets (up to 3); the "zuender" Zug pops
##             them for +9 damage each
##   echo      a hit echoes 0.4 s later on the same targets with 40 % damage
##   blutzoll  each Zug costs 3 % HP; up to +60 % damage at low HP; hits heal 2 %
##   fokus     1.5 s without Zug and without being hit builds focus; the next
##             Zug spends it for up to +60 % damage

const MARK_TIME := 6.0
const ECHO_DELAY := 0.4
const ECHO_SHARE := 0.4
const OVERLOAD_TIME := 6.0
const FOCUS_WAIT := 1.5
const FOCUS_FILL := 1.6

var ffx: FormFx
var kind := ""
var elem := ""
var kern: Dictionary = {}
var kern_type := ""
var kern_value := 0.0
var kern_max := 3.0
var overload := 0.0
var armor := 0.0
var speed_buff := 1.0
var armed := true

var _power := 1.0
var _marks: Dictionary = {}    # target id -> {"n": Node2D, "c": int, "t": float}
var _echoes: Array = []        # {"t", "targets", "dmg", "id"}
var _echo_cd := 0.0
var _heal_cd := 0.0
var _quiet := 0.0
var _last_hp := -1.0
var _pending: Array = []       # delayed spawns: {"t", "what", ...}
var _charged: Dictionary = {}  # this activation already charged (ladung)
var _healed := false
var _tick_t := 0.0
var _ride := false
var _x_end := 0.0


func setup(p: Player, st: FightingStyle) -> void:
	super.setup(p, st)
	ffx = FormFx.new()
	ffx.room = world
	world.add_child(ffx)
	elem = str(st.data.get("element", ""))
	if not GameData.ELEMENTS.has(elem):
		elem = ""
	armed = bool(st.data.get("armed", true))
	kern = st.data.get("kern", {})
	kern_type = str(kern.get("type", ""))
	match kern_type:
		"ladung":
			kern_max = 5.0
		"fokus":
			kern_max = 1.0
		_:
			kern_max = 3.0


# --- colours & small queries ---------------------------------------------------

func col(key: String) -> Color:
	return style.color(key)


func stage_color() -> Color:
	return col("light") if stage >= 3 or overload > 0.0 else col("main")


func trail_color() -> Color:
	if overload > 0.0 or buff_time > 0.0:
		return col("light")
	return col("main")


func normal_element() -> String:
	return elem if overload > 0.0 or buff_time > 0.0 else ""


func normal_mul() -> float:
	var m := 1.0
	if buff_time > 0.0:
		m += buff_bonus
	if overload > 0.0:
		m += 0.25
	return m * _blood_mul()


func move_speed() -> float:
	return speed_buff if buff_time > 0.0 else 1.0


func blade_heat() -> float:
	return 0.0


func reset_fight() -> void:
	kern_value = 0.0
	overload = 0.0
	_marks.clear()
	_echoes.clear()
	stage = 0


## For the HUD: short state text of the Kern.
func kern_info() -> String:
	match kern_type:
		"ladung":
			if overload > 0.0:
				return "ÜBERLADEN %.1f s" % overload
		"fokus":
			if kern_value >= 0.99:
				return "VOLL"
		"blutzoll":
			return "+%d %%" % int(round((_blood_mul() - 1.0) * 100.0))
		"marken":
			var most := 0
			for k in _marks:
				most = maxi(most, int(_marks[k].c))
			return "%d auf Ziel" % most if most > 0 else ""
		"echo":
			return "Echo bereit" if _echo_cd <= 0.0 else ""
	if buff_time > 0.0:
		return "Stärkung %.1f s" % buff_time
	return ""


## Pips shown in the HUD (0..kern_max).
func kern_pips() -> float:
	match kern_type:
		"rhythmus":
			return float(stage)
		"marken":
			var most := 0
			for k in _marks:
				most = maxi(most, int(_marks[k].c))
			return float(most)
		"echo":
			return 0.0 if _echo_cd > 0.0 else 3.0
		"blutzoll":
			return 3.0 * (1.0 - player.hp / maxf(1.0, player.max_hp))
	return kern_value


func _blood_mul() -> float:
	if kern_type != "blutzoll" or player == null:
		return 1.0
	return 1.0 + 0.6 * clampf(1.0 - player.hp / maxf(1.0, player.max_hp), 0.0, 1.0)


func _dmg(base: float) -> float:
	return base * _power * _blood_mul()


func _fx_id(id := "") -> String:
	return "%s/%s" % [style.id, zug_id if id == "" else id]


func _center() -> Vector2:
	return player.global_position + Vector2(0, -22)


func _hand() -> Vector2:
	return player.global_position + Vector2(player.facing * 12.0, -24.0)


func _p(key: String, def):
	return params.get(key, def)


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
	kind = str(style.zug(z).get("kind", "hieb"))
	phase = "startup"
	t = 0.0
	frames = style.frames(z).duplicate()
	enhanced = false
	_decided = false
	params = style.params(z, false)
	_hit_set = {}
	_reported = false
	_step = 0
	_x_start = player.global_position.x
	_y_start = player.global_position.y
	_age = 0.0
	_charged = {}
	_healed = false
	_tick_t = 0.0
	_ride = false
	_bonus = kern_type == "rhythmus" and stage >= 3
	_bonus_used = false
	cooldowns[z] = style.cooldown(z)
	player.move = {}
	_power = 1.0
	if kern_type == "fokus":
		_power = 1.0 + 0.6 * kern_value
		if kern_value >= 0.5:
			ffx.word(_center() + Vector2(-player.facing * 16.0, -40), str(kern.get("name", "Fokus")).to_upper() + "!", col("light"), 18)
			ffx.ring(_center(), 30.0, col("light"), 0.3, 3.0)
		kern_value = 0.0
	_quiet = 0.0
	if kern_type == "blutzoll":
		player.hp = maxf(1.0, player.hp - player.max_hp * 0.03)
		ffx.shards(_center(), -PI / 2.0, 1.2, 6, 120.0, col("main"))
	ffx.ring(_center(), 16.0, col("main"), 0.2, 2.0)
	fx.light(_center(), col("main"), 1.0, 0.5, 0.2)
	Sfx.play("glut_cast", -10.0)
	_on_start()
	return true


func interrupt() -> void:
	if kind in ["sturm", "konter"]:
		player.velocity.x = 0.0
	zug_id = ""
	phase = ""
	countering = false


func _decide_enhanced() -> void:
	_decided = true
	if player.ctl.is_action_pressed("special") and (player.gauge >= 100.0 or player.infinite_aura):
		enhanced = true
		if not player.infinite_aura:
			player.gauge -= 100.0
		params = style.params(zug_id, true)
		var c := _center()
		ffx.ring(c, 28.0, col("light"), 0.3, 3.0)
		ffx.glow(c, col("main"), 30.0, 0.3)
		ffx.word(c + Vector2(-player.facing * 18.0, -50), "VERSTÄRKT", col("accent"), 16)
		world.fx.flash(0.15 * FxSettings.factor("flash"), col("main"))


func _on_start() -> void:
	match kind:
		"sturz":
			if player.is_on_floor():
				player.velocity.y = -float(_p("hop", 300))
			else:
				frames[0] = 6
		"konter":
			frames[1] = int(round(float(_p("stance", 0.45)) * 60.0))


# --- per frame ----------------------------------------------------------------

func tick(delta: float) -> void:
	for z in cooldowns:
		cooldowns[z] = maxf(0.0, cooldowns[z] - delta)
	invuln = maxf(0.0, invuln - delta)
	_echo_cd = maxf(0.0, _echo_cd - delta)
	_heal_cd = maxf(0.0, _heal_cd - delta)
	_tick_kern(delta)
	_tick_aura(delta)
	_tick_echoes(delta)
	_tick_pending(delta)
	_tick_marks(delta)
	if not busy():
		return
	t += delta
	_age += delta
	if not _decided and _age >= 0.15:
		_decide_enhanced()
	match phase:
		"startup":
			_startup_tick(delta)
			if t >= _f(0):
				phase = "active"
				t = 0.0
				Sfx.play("glut_attack", -6.0)
				_on_active()
		"active":
			_active_tick(delta)
			if phase == "active" and t >= _f(1) and kind != "sturz":
				_end_active()
		"fall":
			_fall_tick()
		"counter":
			_counter_tick()
		"back":
			_sturm_tick(true)
		"recovery":
			if t >= _f(2):
				zug_id = ""
				phase = ""
				countering = false
				_ride = false


func _end_active() -> void:
	if kind == "sturm" and bool(_p("back", false)) and phase == "active":
		_leave_trail()
		phase = "back"
		t = 0.0
		_hit_set = {}
		player.facing = -player.facing
		_x_start = player.global_position.x
		return
	if kind == "sturm":
		_leave_trail()
	if kind == "konter":
		countering = false
	phase = "recovery"
	t = 0.0


func _startup_tick(_delta: float) -> void:
	var k := clampf(t / maxf(0.01, _f(0)), 0.0, 1.0)
	if randf() < 0.5:
		var a := randf() * TAU
		var from := _hand() + Vector2(cos(a), sin(a)) * randf_range(18, 34)
		ffx.glow(from, Color(col("main"), 0.7), randf_range(2.0, 3.5), 0.18, (_hand() - from) / 0.18)
	fx.light(_hand(), col("main"), 0.5 + k, 0.4, 0.05)
	if kind == "sturz" and player.is_on_floor() and t > 0.05:
		t = _f(0)  # hopped and already down again: dive right away


func _on_active() -> void:
	match kind:
		"hieb":
			_step = 0
		"geschoss":
			_spawn_shots()
		"sturm":
			_x_start = player.global_position.x
			ffx.speedlines(_center(), PI if player.facing > 0 else 0.0, 6, 40.0, col("light"))
		"saeule":
			_spawn_pillars()
		"sturz":
			phase = "fall"
			t = 0.0
			_hit_set = {}
		"konter":
			countering = true
			ffx.ring(_center(), 24.0, col("main"), 0.25, 3.0)
		"aura":
			_cast_aura()
		"feld":
			_spawn_zone(player.global_position.x + player.facing * float(_p("at", 60)), float(_p("width", 80)),
				float(_p("life", 2.0)), float(_p("tick", 0.35)), _dmg(float(_p("damage", 4))), float(_p("pull", 0)), float(_p("launch", 0)))
		"schritt":
			_blink()
		"regen":
			_spawn_rain()
		"wirbel":
			_step = 0


func _active_tick(delta: float) -> void:
	match kind:
		"hieb":
			_hieb_tick()
		"sturm":
			_sturm_tick(false)
		"konter":
			var pulse := 0.5 + 0.5 * sin(t * 30.0)
			ffx.glow(_center(), Color(col("main"), 0.25 + 0.2 * pulse), 26.0, 0.05)
			if t >= _f(1):
				countering = false
		"strahl":
			_strahl_tick(delta)
		"wirbel":
			_wirbel_tick(delta)
		"saeule":
			if _ride:
				player.velocity.y = minf(player.velocity.y, -430.0)


# --- Kern -----------------------------------------------------------------------

func _tick_kern(delta: float) -> void:
	if overload > 0.0:
		overload -= delta
		if randf() < 0.35:
			ffx.motes(_center() + Vector2(randf_range(-8, 8), randf_range(-10, 14)), 1, 4.0, col("light"), 0.5)
		if overload <= 0.0:
			overload = 0.0
	if _combo_t > 0.0:
		_combo_t -= delta
		if _combo_t <= 0.0 and stage > 0:
			_cool_down()
	if kern_type == "fokus":
		if _last_hp >= 0.0 and player.hp < _last_hp - 0.5:
			if kern_value > 0.2:
				ffx.word(_center() + Vector2(0, -44), "GESTÖRT", Color(0.7, 0.7, 0.75), 13)
			kern_value = 0.0
			_quiet = 0.0
		if not busy() and not player.in_super:
			_quiet += delta
			if _quiet >= FOCUS_WAIT:
				var before := kern_value
				kern_value = minf(1.0, kern_value + delta / FOCUS_FILL)
				if before < 1.0 and kern_value >= 1.0:
					ffx.ring(_center(), 26.0, col("light"), 0.35, 3.0)
					ffx.word(_center() + Vector2(0, -46), str(kern.get("name", "Fokus")), col("light"), 15)
				if kern_value > 0.0 and randf() < 0.2 + kern_value * 0.3:
					ffx.motes(player.global_position + Vector2(randf_range(-10, 10), -4), 1, 3.0, col("light"), 0.7)
	_last_hp = player.hp


## Every Zug hit of this style (melee code and hazards) comes through here.
func strike_for(zid: String, rect: Rect2, dmg: float, kb: float, profile := "", launch := 0.0, hit_set = null, from_x := INF) -> Array:
	var fxx: float = player.global_position.x if from_x == INF else from_x
	var targets := GlutHazard.strike(world, rect, dmg, fxx, kb, profile, launch, hit_set, elem)
	if not targets.is_empty():
		_after_hit(zid, targets, dmg)
	return targets


func _after_hit(zid: String, targets: Array, dmg: float) -> void:
	var first := zid == zug_id and not _reported
	player.add_gauge(6.0 if first else 1.5)
	if zid == zug_id:
		_reported = true
	_combo_t = COMBO_TIME
	if zid == zug_id and float(_p("heal", 0)) > 0.0 and not _healed and kind != "konter" and kind != "aura":
		_healed = true
		_heal(float(_p("heal", 0)))
	match kern_type:
		"rhythmus":
			_rhythm_hit(zid, targets)
		"ladung":
			if not _charged.has(zid):
				_charged[zid] = true
				_charge(1.0)
		"marken":
			if zid == str(kern.get("zuender", "")):
				_detonate(targets)
			else:
				_mark(targets)
		"echo":
			if _echo_cd <= 0.0 and dmg >= 2.0:
				_echo_cd = 0.35
				_echoes.append({"t": ECHO_DELAY, "targets": targets.slice(0, 4), "dmg": maxf(2.0, dmg * ECHO_SHARE), "id": zid})
		"blutzoll":
			if _heal_cd <= 0.0:
				_heal_cd = 0.15
				player.hp = minf(player.max_hp, player.hp + player.max_hp * 0.02)


func _rhythm_hit(zid: String, targets: Array) -> void:
	if zid == zug_id and _bonus and not _bonus_used:
		_bonus_used = true
		_bonus = false
		var tg: Node2D = targets[0]
		var c: Vector2 = tg.get_hurt_rect().get_center()
		world.deal_hit(tg, 9.0 * _blood_mul(), elem, player.global_position.x, 160.0, "heavy")
		player.add_gauge(10.0)
		ffx.burst(_fx_id(), c, 70.0, 0.35, 0.0, player.facing < 0, col("light"))
		ffx.ring(c, 30.0, col("light"), 0.35, 5.0)
		ffx.word(c + Vector2(0, -40), str(kern.get("name", "Rhythmus")).to_upper() + "!", col("light"), 22)
		Sfx.play("glut_impact", -4.0)
		_cool_down()
		return
	if zid != zug_id or _combo_zuege.has(zid) or stage >= 3:
		return
	_combo_zuege[zid] = true
	_set_stage(stage + 1)


func _set_stage(s: int) -> void:
	stage = clampi(s, 0, 3)
	_combo_t = COMBO_TIME
	var c := _center()
	ffx.ring(c, 14.0 + stage * 6.0, stage_color(), 0.3, 2.0 + stage)
	ffx.motes(c, 3 + stage * 2, 10.0, stage_color(), 0.6)
	if stage == 3:
		ffx.word(c + Vector2(-player.facing * 16.0, -48), "x3!", col("light"), 22)


func _charge(n: float) -> void:
	if overload > 0.0:
		return
	kern_value = minf(kern_max, kern_value + n)
	var c := _center()
	ffx.ring(c, 12.0 + kern_value * 4.0, col("main"), 0.25, 2.0)
	if kern_value >= kern_max:
		kern_value = 0.0
		overload = OVERLOAD_TIME
		ffx.burst(_fx_id(_aura_fx()), c, 110.0, 0.5, 0.0, false, col("light"))
		ffx.ring(c, 46.0, col("light"), 0.45, 6.0)
		ffx.word(c + Vector2(0, -52), "ÜBERLADUNG!", col("light"), 24)
		world.fx.flash(0.2 * FxSettings.factor("flash"), col("main"))
		world.fx.shake(4.0 * FxSettings.factor("shake"))
		Sfx.play("glut_impact", -4.0)


## The fx sprite used for the big Kern moments: an aura Zug if the style has
## one, else its first Zug.
func _aura_fx() -> String:
	for z in style.zug_order:
		if str(style.zug(z).get("kind", "")) == "aura":
			return z
	return style.zug_order[0] if not style.zug_order.is_empty() else ""


func _mark(targets: Array) -> void:
	for tg in targets:
		if not is_instance_valid(tg):
			continue
		var id: int = tg.get_instance_id()
		var m: Dictionary = _marks.get(id, {"n": tg, "c": 0, "t": 0.0})
		m.c = mini(3, int(m.c) + 1)
		m.t = MARK_TIME
		_marks[id] = m


func _detonate(targets: Array) -> void:
	var any := false
	for tg in targets:
		if not is_instance_valid(tg):
			continue
		var id: int = tg.get_instance_id()
		if not _marks.has(id):
			continue
		var n := int(_marks[id].c)
		_marks.erase(id)
		var node: Node2D = tg
		var c: Vector2 = node.get_hurt_rect().get_center()
		world.deal_hit(node, 9.0 * n * _blood_mul(), elem, player.global_position.x, 150.0, "heavy")
		ffx.burst(_fx_id(), c, 50.0 + n * 18.0, 0.4, randf() * TAU, false, col("accent"))
		ffx.ring(c, 20.0 + n * 8.0, col("accent"), 0.35, 4.0)
		any = true
	if any:
		ffx.word(_center() + Vector2(player.facing * 30.0, -54), str(kern.get("name", "Marke")).to_upper() + "!", col("accent"), 22)
		world.fx.shake(4.0 * FxSettings.factor("shake"))
		player.add_gauge(8.0)
		Sfx.play("glut_impact", -4.0)


func _tick_marks(delta: float) -> void:
	for id in _marks.keys():
		var m: Dictionary = _marks[id]
		m.t = float(m.t) - delta
		if m.t <= 0.0 or not is_instance_valid(m.n):
			_marks.erase(id)
			continue
		var node: Node2D = m.n
		if not node.has_method("head_position"):
			continue
		var hp: Vector2 = node.head_position() + Vector2(0, -16)
		for i in int(m.c):
			var c := hp + Vector2((i - (int(m.c) - 1) * 0.5) * 7.0, 0)
			ffx.glow(c, Color(col("accent"), 0.8), 3.2, 0.04)
			ffx.glow(c, Color(1, 1, 1, 0.9), 1.3, 0.04)


func _tick_echoes(delta: float) -> void:
	if _echoes.is_empty():
		return
	var keep: Array = []
	for e in _echoes:
		e.t = float(e.t) - delta
		if e.t > 0.0:
			keep.append(e)
			continue
		for tg in e.targets:
			if not is_instance_valid(tg):
				continue
			var node: Node2D = tg
			var c: Vector2 = node.get_hurt_rect().get_center()
			world.deal_hit(node, float(e.dmg), elem, player.global_position.x, 60.0, "light")
			ffx.burst("%s/%s" % [style.id, str(e.id)], c, 44.0, 0.28, randf_range(-0.4, 0.4), player.facing < 0, Color(col("accent"), 0.75))
			ffx.motes(c, 4, 8.0, col("accent"), 0.5)
		if not e.targets.is_empty():
			ffx.word(_center() + Vector2(player.facing * 26.0, -50), str(kern.get("name", "Echo")), col("accent"), 13)
	_echoes = keep


func _tick_pending(delta: float) -> void:
	if _pending.is_empty():
		return
	var keep: Array = []
	for e in _pending:
		e.t = float(e.t) - delta
		if e.t > 0.0:
			keep.append(e)
			continue
		match str(e.what):
			"pillar":
				_pillar_at(float(e.x), e.p)
			"shot":
				_shot(e.p, float(e.angle), str(e.zid))
			"waves":
				_spawn_waves_at(e.pos, float(e.dmg), str(e.zid))
	_pending = keep


# --- Hieb -----------------------------------------------------------------------

func _hieb_tick() -> void:
	var hits := int(_p("hits", 3))
	var due := int(t / maxf(0.001, _f(1)) * hits) + 1
	while _step < mini(due, hits):
		_step += 1
		var last := _step == hits
		var length := float(_p("len", 50)) * player.sprite.reach()
		var h := float(_p("h", 36))
		for s in _p("sides", [1]):
			var side: float = float(s) * player.facing
			var ox := player.global_position.x + side * 8.0
			var r := Rect2(ox if side > 0.0 else ox - length, player.global_position.y - 4.0 - h, length, h + 4.0)
			var kb := 140.0 if last else 30.0
			if last and float(_p("pull", 0)) > 0.0:
				kb = -float(_p("pull", 0))
			strike_for(zug_id, r, _dmg(float(_p("damage", 5))), kb, "heavy" if last else "light",
				float(_p("launch", 0)) if last else 0.0, {})
			var c := Vector2(ox + side * length * 0.5, player.global_position.y - 4.0 - h * 0.5)
			var rot := randf_range(-0.25, 0.25) + (0.0 if _step % 2 == 1 else 0.35)
			ffx.burst(_fx_id(), c, maxf(46.0, length * 1.5), 0.24 if not last else 0.32, rot, side < 0.0, Color.WHITE, 0.6)
			ffx.shards(c, 0.0 if side > 0.0 else PI, 0.5, 4 if not last else 10, 200.0, col("light"))
		if last:
			world.fx.shake(2.5 * FxSettings.factor("shake"), player.facing)
		Sfx.play("glut_attack", -8.0)


# --- Geschoss --------------------------------------------------------------------

func _spawn_shots() -> void:
	var n := int(_p("count", 1))
	var spread := deg_to_rad(float(_p("spread", 0)))
	var base := deg_to_rad(float(_p("angle", 0)))
	var delay := float(_p("delay", 0.0))
	ffx.burst(_fx_id(), _hand(), 40.0, 0.2, 0.0, player.facing < 0, col("light"))
	for i in n:
		var k := 0.0 if n == 1 else float(i) / (n - 1) - 0.5
		var a := base + spread * k
		if delay > 0.0 and i > 0:
			_pending.append({"t": delay * i, "what": "shot", "p": params.duplicate(), "angle": a, "zid": zug_id})
		else:
			_shot(params, a, zug_id)


func _shot(p: Dictionary, angle: float, zid: String) -> void:
	var h := _fhazard("shot", _hand(), zid)
	var speed := float(p.get("speed", 420))
	h.vel = Vector2(cos(angle) * player.facing, sin(angle)) * speed
	h.params = p
	h.size = float(p.get("size", 1.0))
	h.damage = _dmg(float(p.get("damage", 12)))
	var dist := float(p.get("dist", 320))
	h.life = 3.0 if bool(p.get("boomerang", false)) else dist / maxf(60.0, speed) + 0.5
	world.attacks.add_child(h)


func _fhazard(k: String, pos: Vector2, zid := "") -> FormHazard:
	var h := FormHazard.new()
	h.world = world
	h.caster = self
	h.zug_id = zug_id if zid == "" else zid
	h.fx_id = "%s/%s" % [style.id, h.zug_id]
	h.kind = k
	h.col = col("main")
	h.dir = player.facing
	h.global_position = pos
	return h


# --- Sturm ------------------------------------------------------------------------

func _sturm_tick(back: bool) -> void:
	_ghost_t -= get_physics_process_delta_time()
	if _ghost_t <= 0.0:
		_ghost_t = 0.03
		world.afterimages.add(player.sprite.snapshot(), Color(col("main"), 0.6) * Color(1.6, 1.6, 1.6, 1.0))
	var a := player.global_position + Vector2(-player.facing * 30.0, -22)
	var b := player.global_position + Vector2(player.facing * 14.0, -22)
	ffx.beam(_fx_id(), a, b, 30.0, Color(1, 1, 1, 0.8), 0.06)
	fx.light(_center(), col("main"), 1.4, 0.5, 0.05)
	var body := Rect2(player.global_position + Vector2(-16, -46), Vector2(32, 48))
	strike_for(zug_id, body, _dmg(float(_p("damage", 10))), 120.0, "heavy", 90.0, _hit_set)
	if t >= _f(1) or player.is_on_wall():
		if back:
			_leave_trail()
			phase = "recovery"
			t = 0.0
		else:
			_end_active()


func _leave_trail() -> void:
	if not bool(_p("trail", false)):
		return
	var x1 := player.global_position.x
	if absf(x1 - _x_start) < 10.0:
		return
	var gy := GlutHazard.ground_y((x1 + _x_start) * 0.5, player.global_position.y - 10.0)
	if gy > 9000.0:
		return
	_spawn_zone((x1 + _x_start) * 0.5, absf(x1 - _x_start), 1.2, 0.3, _dmg(3.0), 0.0, 0.0)


# --- Säule ------------------------------------------------------------------------

func _spawn_pillars() -> void:
	var n := int(_p("count", 1))
	var at := float(_p("at", 56))
	var step := float(_p("step", 40))
	var delay := float(_p("delay", 0.12))
	if bool(_p("ride", false)) and player.is_on_floor():
		_ride = true
		player.velocity.y = -460.0
	for i in n:
		var x := player.global_position.x + player.facing * (at + step * i)
		if i == 0:
			_pillar_at(x, params)
		else:
			_pending.append({"t": delay * i, "what": "pillar", "x": x, "p": params.duplicate()})


func _pillar_at(x: float, p: Dictionary) -> void:
	var gy := GlutHazard.ground_y(x, player.global_position.y - 20.0)
	if gy > 9000.0:
		return
	var h := _fhazard("pillar", Vector2(x, gy))
	h.width = float(p.get("width", 30))
	h.height = float(p.get("height", 90))
	h.damage = _dmg(float(p.get("damage", 12)))
	h.params = {"launch": float(p.get("launch", 340))}
	h.life = 0.42
	world.attacks.add_child(h)
	ffx.shards(Vector2(x, gy), -PI / 2.0, 0.6, 10, 260.0, col("light"))
	world.dust.puff(Vector2(x, gy), 1.0, 4, 3.0, 60.0)
	world.fx.shake(2.0 * FxSettings.factor("shake"))


# --- Sturz ------------------------------------------------------------------------

func _fall_tick() -> void:
	_ghost_t -= get_physics_process_delta_time()
	if _ghost_t <= 0.0:
		_ghost_t = 0.03
		world.afterimages.add(player.sprite.snapshot(), Color(col("main"), 0.5) * Color(1.6, 1.6, 1.6, 1.0))
		ffx.glow(player.global_position + Vector2(0, -8), col("main"), 10.0, 0.2)
	var r := Rect2(player.global_position + Vector2(-16, -20), Vector2(32, 26))
	strike_for(zug_id, r, _dmg(float(_p("damage", 12))) * 0.5, 40.0, "heavy", -260.0, _hit_set)
	if player.is_on_floor() and t > 0.02:
		_impact()
		phase = "recovery"
		t = 0.0
	elif t > 0.9:
		phase = "recovery"
		t = 0.0


func _impact() -> void:
	var p := player.global_position
	var rad := float(_p("radius", 44))
	var rect := Rect2(p.x - rad, p.y - rad * 0.9, rad * 2.0, rad * 0.9 + 4.0)
	strike_for(zug_id, rect, _dmg(float(_p("damage", 12))), 170.0, "heavy", 200.0, {})
	ffx.burst(_fx_id(), p + Vector2(0, -rad * 0.45), rad * 2.6, 0.42, 0.0, player.facing < 0, Color.WHITE, 0.5)
	ffx.ring(p + Vector2(0, -4), rad, col("light"), 0.35, 5.0)
	ffx.shards(p, -PI / 2.0, 1.3, 18, 300.0, col("light"))
	world.dust.land(p, 1.0)
	world.fx.shake(6.0 * FxSettings.factor("shake"))
	world.fx.punch(0.04)
	world.fx.freeze(0.05 * FxSettings.factor("stop"))
	Sfx.play("glut_impact", -2.0)
	if bool(_p("waves", false)):
		_spawn_waves_at(p, _dmg(float(_p("wave_damage", 8))), zug_id)
	if bool(_p("aftershock", false)):
		_pending.append({"t": 0.4, "what": "waves", "pos": p, "dmg": _dmg(float(_p("wave_damage", 8))) * 0.8, "zid": zug_id})
	var crater := float(_p("crater", 0.0))
	if crater > 0.0:
		_spawn_zone(p.x, rad * 1.4, crater, 0.35, _dmg(3.0), 0.0, 0.0)


func _spawn_waves_at(p: Vector2, dmg: float, zid: String) -> void:
	for d in [-1.0, 1.0]:
		var h := _fhazard("wave", p + Vector2(d * 6.0, 0), zid)
		h.dir = d
		h.damage = dmg
		h.life = 1.1
		world.attacks.add_child(h)
	ffx.ring(p + Vector2(0, -6), 30.0, col("main"), 0.3, 3.0)


# --- Konter -----------------------------------------------------------------------

func try_counter(from_x: float, projectile: Node = null) -> bool:
	if not countering:
		return false
	countering = false
	invuln = 0.45
	phase = "counter"
	t = 0.0
	_step = 0
	_hit_set = {}
	player.facing = 1 if from_x >= player.global_position.x else -1
	var c := player.global_position + Vector2(player.facing * 8.0, -24.0)
	ffx.burst(_fx_id(), c, 90.0, 0.4, 0.0, player.facing < 0, Color.WHITE, 0.5)
	ffx.ring(c, 32.0, col("light"), 0.4, 5.0)
	ffx.shards(c, -PI / 2.0, PI, 24, 300.0, col("light"))
	ffx.word(c + Vector2(0, -44), "KONTER!", col("light"), 28)
	Sfx.play("parry")
	world.fx.flash(0.22 * FxSettings.factor("flash"), col("main"))
	world.fx.freeze(0.12 * FxSettings.factor("stop"))
	world.fx.shake(6.0 * FxSettings.factor("shake"))
	world.fx.punch(0.06)
	player.add_gauge(15.0)
	if float(_p("heal", 0)) > 0.0:
		_heal(float(_p("heal", 0)))
	if float(_p("buff", 0)) > 0.0:
		_start_buff(float(_p("buff", 0)), 0.2)
	if projectile != null and bool(_p("reflect", false)) and projectile.has_method("reflect"):
		projectile.reflect(player)
	elif projectile != null and projectile.has_method("burn"):
		projectile.burn()
	return true


func _counter_tick() -> void:
	if _step == 0 and t >= 0.08:
		_step = 1
		var r := _front_rect(28, -26, 68, 44)
		strike_for(zug_id, r, _dmg(float(_p("counter_damage", 20))), 260.0, "heavy", 120.0, _hit_set)
	if t >= 0.3:
		phase = "recovery"
		t = 0.0


# --- Aura -------------------------------------------------------------------------

func _cast_aura() -> void:
	var c := _center()
	var cost := float(_p("hp_cost", 0.0))
	if cost > 0.0:
		player.hp = maxf(1.0, player.hp - player.max_hp * cost)
		world.numbers.spawn_number(player.global_position + Vector2(0, -50), int(player.max_hp * cost), col("main"), get_instance_id(), false)
	var heal := float(_p("heal", 0.0))
	if heal > 0.0:
		_heal(heal)
	var b := float(_p("buff", 5.0))
	if b > 0.2:
		_start_buff(b, float(_p("bonus", 0.2)))
		armor = float(_p("armor", 0.0))
		speed_buff = float(_p("speed", 1.0))
	ffx.burst(_fx_id(), c, 96.0, 0.5, 0.0, false, Color.WHITE, 0.4)
	ffx.ring(c, 36.0, col("light"), 0.4, 4.0)
	ffx.word(c + Vector2(0, -50), str(style.zug(zug_id).get("name", "")).to_upper() + "!", col("light"), 18)
	world.fx.flash(0.12 * FxSettings.factor("flash"), col("main"))
	var nova := float(_p("nova", 0.0))
	if nova > 0.0:
		var rad := float(_p("nova_radius", 48))
		strike_for(zug_id, Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0), _dmg(nova), 180.0, "heavy", 140.0, {})
		ffx.ring(c, rad, col("main"), 0.35, 6.0)
		world.fx.shake(4.0 * FxSettings.factor("shake"))


func _start_buff(seconds: float, bonus: float) -> void:
	buff_time = seconds
	buff_max = seconds
	buff_bonus = bonus


func _tick_aura(delta: float) -> void:
	if buff_time <= 0.0:
		return
	buff_time -= delta
	_ember_t -= delta
	if _ember_t <= 0.0:
		_ember_t = 0.07
		ffx.motes(player.global_position + Vector2(randf_range(-9, 9), randf_range(-36, -4)), 1, 3.0, col("main"), 0.6)
		ffx.glow(_center(), Color(col("main"), 0.18), 22.0, 0.12)
	if buff_time <= 0.0:
		buff_time = 0.0
		armor = 0.0
		speed_buff = 1.0


func _heal(amount: float) -> void:
	var before := player.hp
	player.hp = minf(player.max_hp, player.hp + amount)
	var got := int(round(player.hp - before))
	if got > 0:
		world.numbers.spawn_number(player.global_position + Vector2(0, -56), got, Color("6ee07a"), get_instance_id(), false)
		ffx.motes(_center(), 8, 12.0, Color("9ff0a8"), 0.7)


## Aura "armor": a part of each hit is absorbed while the buff lasts.
func guard_hit(damage: float, from_x: float, _source: Node) -> bool:
	if armor <= 0.0 or buff_time <= 0.0:
		return false
	var dmg := maxf(1.0, damage * (1.0 - armor))
	player.hp = maxf(0.0, player.hp - dmg)
	player.hurt_invuln = 0.5
	player.velocity.x = signf(player.global_position.x - from_x) * 90.0
	player.sprite.flash = 0.06
	world.numbers.spawn_number(player.global_position + Vector2(0, -50), int(dmg), Color("ff4b3e"), player.get_instance_id(), false)
	ffx.ring(_center(), 26.0, col("light"), 0.25, 3.0)
	if player.hp <= 0.0:
		player.hp = player.max_hp
		world.on_player_down()
	return true


# --- Feld -------------------------------------------------------------------------

func _spawn_zone(x: float, w: float, life: float, tick_s: float, dmg: float, pull: float, launch: float) -> void:
	var gy := GlutHazard.ground_y(x, player.global_position.y - 20.0)
	if gy > 9000.0:
		gy = player.global_position.y
	var h := _fhazard("zone", Vector2(x, gy))
	h.width = w
	h.life = life
	h.damage = dmg
	h.params = {"tick": tick_s, "pull": pull, "launch": launch}
	world.attacks.add_child(h)
	ffx.ring(Vector2(x, gy - 6), w * 0.5, col("main"), 0.3, 3.0)


# --- Strahl -----------------------------------------------------------------------

func _strahl_tick(delta: float) -> void:
	var length := float(_p("len", 220))
	var w := float(_p("width", 14))
	var up := bool(_p("up", false))
	var dirv := Vector2(player.facing, -0.55 if up else 0.0).normalized()
	var a := _hand()
	var k := clampf(t / 0.08, 0.0, 1.0)
	var b := a + dirv * length * k
	var flick := 0.85 + 0.15 * sin(t * 50.0)
	ffx.beam(_fx_id(), a, b, w * 2.6 * flick, Color.WHITE, 0.05)
	ffx.glow(a, col("light"), w * 1.2, 0.06)
	fx.light(a.lerp(b, 0.5), col("main"), 1.5, 0.7, 0.05)
	_tick_t -= delta
	if _tick_t <= 0.0:
		_tick_t = float(_p("tick", 0.08))
		var push := float(_p("push", 20))
		var segs := 4
		var hs := {}
		for i in segs:
			var p0 := a.lerp(b, (i + 0.5) / segs)
			var half := length / segs * 0.5
			var r := Rect2(p0 - Vector2(half, w * 0.5 + 4.0), Vector2(half * 2.0, w + 8.0))
			strike_for(zug_id, r, _dmg(float(_p("damage", 3.5))), push, "light", 0.0, hs)
		ffx.shards(b, dirv.angle(), 0.6, 3, 220.0, col("light"))


# --- Schritt ----------------------------------------------------------------------

func _blink() -> void:
	var dist := float(_p("dist", 120))
	var from := player.global_position
	var to := from + Vector2(player.facing * dist, 0)
	if bool(_p("behind", true)):
		var best: Node2D = null
		var best_d := dist + 30.0
		for tg in world.get_tree().get_nodes_in_group("targets"):
			var n: Node2D = tg
			var d := absf(n.global_position.x - from.x)
			if d < best_d and signf(n.global_position.x - from.x) * player.facing >= -0.1 and absf(n.global_position.y - from.y) < 90.0:
				best = n
				best_d = d
		if best != null:
			to = Vector2(best.global_position.x + player.facing * 26.0, best.global_position.y)
	to.x = clampf(to.x, 12.0, TrainingRoom.WIDTH - 12.0)
	var gy := GlutHazard.ground_y(to.x, to.y - 30.0)
	if gy < 9000.0 and absf(gy - to.y) < 60.0:
		to.y = gy - 1.0
	ffx.burst(_fx_id(), from + Vector2(0, -22), 64.0, 0.3, 0.0, false, Color.WHITE)
	var snap := player.sprite.snapshot()
	for i in 5:
		world.afterimages.add(snap, Color(col("main"), 0.2 + i * 0.1) * Color(1.6, 1.6, 1.6, 1.0), from.lerp(to, float(i) / 5.0) - from, 0.25)
	player.global_position = to
	player.velocity = Vector2.ZERO
	if bool(_p("behind", true)):
		player.facing = -player.facing
	invuln = maxf(invuln, 0.25)
	var c := to + Vector2(0, -22)
	ffx.burst(_fx_id(), c, 72.0, 0.32, 0.0, player.facing < 0, Color.WHITE)
	ffx.ring(c, 26.0, col("light"), 0.3, 3.0)
	var r := Rect2(to.x - 34.0, to.y - 46.0, 68.0, 48.0)
	strike_for(zug_id, r, _dmg(float(_p("damage", 10))), 150.0, "heavy", 120.0, {})


# --- Regen ------------------------------------------------------------------------

func _spawn_rain() -> void:
	var n := int(_p("count", 6))
	var w := float(_p("width", 110))
	var cx := player.global_position.x + player.facing * float(_p("at", 90))
	var big := bool(_p("big", false))
	for i in n:
		var x := cx + (randf() - 0.5) * w
		var h := _fhazard("drop", Vector2(x - player.facing * 20.0, player.global_position.y - 190.0 - randf() * 50.0))
		h.vel = Vector2(player.facing * 60.0, 520.0 + randf() * 140.0)
		h.size = 1.5 if big else 0.8
		h.damage = _dmg(float(_p("damage", 6)))
		h.life = 2.0
		world.attacks.add_child(h)
	ffx.ring(Vector2(cx, player.global_position.y - 170.0), w * 0.5, col("main"), 0.4, 3.0)


# --- Wirbel -----------------------------------------------------------------------

func _wirbel_tick(delta: float) -> void:
	var rad := float(_p("radius", 40))
	var hits := int(_p("hits", 5))
	var c := _center()
	var spin := t * 18.0
	ffx.burst(_fx_id(), c, rad * 2.6, 0.06, spin, false, Color(1, 1, 1, 0.75), 1.0)
	ffx.glow(c, Color(col("main"), 0.3), rad, 0.05)
	var pull := float(_p("pull", 40))
	if pull > 0.0:
		for tg in world.get_tree().get_nodes_in_group("targets"):
			var n: Node2D = tg
			var dx := c.x - n.global_position.x
			if absf(dx) < rad + 40.0 and absf(dx) > 6.0 and absf(n.global_position.y - player.global_position.y) < 80.0:
				n.global_position.x += signf(dx) * minf(absf(dx), pull * delta)
	var due := int(t / maxf(0.001, _f(1)) * hits) + 1
	while _step < mini(due, hits):
		_step += 1
		var last := _step == hits
		var r := Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
		strike_for(zug_id, r, _dmg(float(_p("damage", 4))), 150.0 if last else 20.0, "heavy" if last else "light", 160.0 if last else 0.0, {})
		ffx.shards(c, randf() * TAU, PI, 3, 200.0, col("light"))


# --- movement & pose ----------------------------------------------------------------

func drive_velocity(v: Vector2, delta: float, on_floor: bool) -> Vector2:
	match kind:
		"sturm":
			if phase == "active" or phase == "back":
				return Vector2(player.facing * float(_p("dist", 120)) / maxf(0.01, _f(1)), 0.0)
		"sturz":
			if phase == "fall":
				return Vector2(0.0, 760.0)
			if phase == "startup":
				return Vector2(v.x * 0.9, minf(v.y + Player.GRAVITY * 0.8 * delta, 160.0))
		"konter":
			return Vector2(0.0, minf(v.y + Player.GRAVITY * delta, Player.MAX_FALL))
		"hieb":
			if phase == "active":
				var lunge := float(_p("lunge", 40))
				return Vector2(player.facing * lunge, minf(v.y + Player.GRAVITY * delta * 0.5, Player.MAX_FALL))
		"wirbel":
			if phase == "active":
				var lift := float(_p("lift", 0))
				var vy := -lift if t < _f(1) * 0.6 and lift > 0.0 else minf(v.y + Player.GRAVITY * delta * 0.4, Player.MAX_FALL)
				return Vector2(player.facing * float(_p("drift", 0)), vy)
		"saeule":
			if _ride and phase == "active":
				return Vector2(v.x * 0.9, minf(v.y + Player.GRAVITY * delta * 0.5, Player.MAX_FALL))
		"strahl":
			if phase == "active":
				return Vector2(0.0, minf(v.y + Player.GRAVITY * delta * 0.25, 60.0))
	var gx := move_toward(v.x, 0.0, (1800.0 if on_floor else 400.0) * delta)
	var fall := Player.GRAVITY * delta * (0.5 if not on_floor and phase == "active" else 1.0)
	return Vector2(gx, minf(v.y + fall, Player.MAX_FALL))


const POSES_ARMED := {
	"hieb": [["slash_wind"], ["slash_hit", "slash_side", "slash_hit"], ["slash_side"]],
	"geschoss": [["slash_wind"], ["thrust_hit"], ["thrust_hit"]],
	"sturm": [["dash_0"], ["thrust_hit"], ["land_0"]],
	"saeule": [["slash_wind"], ["upper_hit"], ["upper_hit"]],
	"sturz": [["jump_1"], ["slash_hit"], ["land_0"]],
	"konter": [["block_0"], ["block_0"], ["slash_side"]],
	"aura": [["charge_0"], ["super_0"], ["super_0"]],
	"feld": [["slash_wind"], ["slash_hit"], ["slash_hit"]],
	"strahl": [["charge_0"], ["thrust_hit"], ["thrust_hit"]],
	"schritt": [["dash_0"], ["slash_hit"], ["slash_side"]],
	"regen": [["charge_0"], ["super_0"], ["super_0"]],
	"wirbel": [["slash_wind"], ["slash_hit", "slash_side"], ["slash_side"]],
}
const POSES_UNARMED := {
	"hieb": [["jab_wind"], ["jab_hit", "cross_hit", "hook_hit"], ["hook_hit"]],
	"geschoss": [["cast_wind"], ["cast_hit"], ["cast_hit"]],
	"sturm": [["dash_0"], ["cross_hit"], ["land_0"]],
	"saeule": [["upper_wind"], ["upper_hit"], ["upper_hit"]],
	"sturz": [["jump_1"], ["lowkick_hit"], ["land_0"]],
	"konter": [["block_0"], ["block_0"], ["cross_hit"]],
	"aura": [["charge_0"], ["super_0"], ["super_0"]],
	"feld": [["cast_wind"], ["cast_hit"], ["cast_hit"]],
	"strahl": [["cast_wind"], ["cast_hit"], ["cast_hit"]],
	"schritt": [["dash_0"], ["highkick_hit"], ["highkick_hit"]],
	"regen": [["cast_wind"], ["super_0"], ["super_0"]],
	"wirbel": [["highkick_wind"], ["highkick_hit", "lowkick_hit"], ["land_0"]],
}


func creator_pose() -> String:
	if not busy():
		return ""
	if phase == "counter":
		return "slash_hit" if armed else "cross_hit"
	if phase == "fall":
		return "slash_hit" if armed else "lowkick_hit"
	if phase == "back":
		return "thrust_hit" if armed else "cross_hit"
	var table: Dictionary = POSES_ARMED if armed else POSES_UNARMED
	var lists: Array = table.get(kind, table["hieb"])
	var idx := ["startup", "active", "recovery"].find(phase)
	if idx < 0:
		idx = 1
	var list: Array = lists[idx]
	if kind in ["hieb", "wirbel"] and phase == "active":
		return str(list[maxi(0, _step - 1) % list.size()])
	var dur := _f(idx)
	var k := clampf(t / maxf(0.001, dur), 0.0, 0.999)
	return str(list[int(k * list.size())])


func pose_frame() -> int:
	if not busy():
		return 0
	match phase:
		"startup":
			return 1
		"recovery":
			return 6
	return 3
