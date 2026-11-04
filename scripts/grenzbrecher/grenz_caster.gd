class_name GrenzCaster
extends GlutCaster
## Runs the Züge of the fighting style Grenzbrecher (Ki-Kampfkunst) and owns
## its state. Same interface as GlutCaster; the rules are the style's own
## (docs/stil-grenzbrecher.md):
##  - Ki-Leiste (0..100, own HUD bar): every melee hit +8 Ki, +12 when it
##    follows a *different* Zug within 1 s (Fluss), +4 against lifted
##    targets. Normal J/K hits +6. Ki fades after 5 s without hits (to 20).
##  - Ki sammeln: on the ground hold down 0.4 s without L. +30 Ki/s, the aura
##    flames up, stones float; any button or a hit stops it and hits taken
##    meanwhile do +25 % damage.
##  - Fernangriffe (Kernstrahl, Ki-Nachschuss) cost Ki. Each one within 3 s
##    of the last costs +50 % more (Überhitzung, up to +150 %). With 50 Ki or
##    more the beam spends one extra Abschnitt (20) for +40 % damage. Under
##    20 Ki the Kernstrahl is only a weak palm push.
##  - Ki-Erschütterung: charged hits (L held, full beam, heavy finishers)
##    deal triple Haltungsschaden, at most once per 2 s per target.
##  - Grenzbruch (Meisterzug A): 10 s +50 % Ki, +25 % tempo, Fernschritt
##    without cooldown, then 1 s exhausted. Set by GrenzSuper (burst_time).

const KI_MAX := 100.0
const KI_HIT := 8.0
const KI_FLOW := 12.0
const KI_LIFTED := 4.0
const KI_NORMAL := 6.0
const KI_GATHER := 30.0
const KI_FLOOR := 20.0
const FADE_WAIT := 5.0
const FLOW_TIME := 1.0
const GATHER_HOLD := 0.4
const HEAT_TIME := 3.0
const SHOCK_CD := 2.0
const BURST_TIME := 10.0
const TELEPORT_WINDOW := 10.0

var gfx: GrenzFx
var ki := 40.0
var heat := 0              # Überhitzung stacks (0..3)
var burst_time := 0.0      # Grenzbruch
var exhaust := 0.0
var sun_super: Node = null  # GrenzSuper while the Sonnenkern charges
var _heat_t := 0.0
var _idle_t := 0.0
var _down_t := 0.0
var _since_last := 99.0
var _last_zug := ""
var _flow := false
var _charge := 0.0
var _weak := false
var _boost_spent := false
var _air_boost_used := false
var _aim := 0.0
var _ki_full_said := false
var _shock_cd: Dictionary = {}
var _teleports: Array = []
var _orbs: Array = []       # Ki-Nachschuss balls
var _hit_any := false
var _push_v := 0.0
var _push_t := 0.0
var _beam_end := Vector2.ZERO
var _evade := false
var _back_kick := false
var _beam_dmg := 0.0


func setup(p: Player, st: FightingStyle) -> void:
	super.setup(p, st)
	GlutIcons.style_id = st.id
	gfx = GrenzFx.new()
	gfx.room = world
	world.add_child(gfx)


func reset_fight() -> void:
	ki = 40.0
	heat = 0
	burst_time = 0.0
	exhaust = 0.0
	_teleports.clear()


func stage_color() -> Color:
	return style.color("white") if burst_time > 0.0 else style.color("sky")


func trail_color() -> Color:
	return style.color("white") if burst_time > 0.0 else style.color("sky")


func normal_element() -> String:
	return ""


func normal_mul() -> float:
	return 1.0


func blade_heat() -> float:
	return 0.0


func move_speed() -> float:
	if burst_time > 0.0:
		return 1.25
	if exhaust > 0.0:
		return 0.8
	return 1.0


## Unarmed creator pose for the current Zug (lists from the style json).
func creator_pose() -> String:
	if not busy():
		return ""
	if zug_id == "sammeln":
		return "charge_0"
	if phase == "counter" or phase == "kick":
		return "cross_hit"
	if phase == "fall":
		return "stomp_hit"
	if phase == "charge" or phase == "volley":
		return "charge_0" if phase == "charge" else "airpunch_hit"
	var lists: Dictionary = style.zug(zug_id).get("creator", {})
	var ph := phase if phase in ["startup", "active", "recovery"] else "active"
	var list: Array = lists.get(ph, [])
	if list.is_empty():
		return ""
	if zug_id == "steilpfad_folge" and ph == "active":
		return str(list[_step % list.size()])
	var dur := _f(["startup", "active", "recovery"].find(ph))
	var k := clampf(t / maxf(0.001, dur), 0.0, 0.999)
	return str(list[int(k * list.size())])


func gathering() -> bool:
	return zug_id == "sammeln"


func ki_segments() -> int:
	return int(ki / 20.0)


# --- Ki -----------------------------------------------------------------------------

func add_ki(amount: float) -> void:
	if amount > 0.0 and burst_time > 0.0:
		amount *= 1.5
	var before := ki
	ki = clampf(ki + amount, 0.0, KI_MAX)
	if amount > 0.0:
		_idle_t = 0.0
	if ki >= KI_MAX and before < KI_MAX:
		gfx.word(_center() + Vector2(0, -50), "KI VOLL!", style.color("white"), 16)
		gfx.ring(_center(), 34.0, style.color("sky"), 0.35, 3.0)


func spend_ki(amount: float) -> bool:
	if ki < amount:
		return false
	ki -= amount
	return true


## Ki cost of a Zug with the active alternative (ranged ones with heat).
func ki_cost(z: String) -> float:
	var a := style.alt(z)
	var c := float(a.get("ki", style.zug(z).get("ki", 0)))
	if style.zug(z).get("ranged", false):
		c *= 1.0 + 0.5 * heat
	return c


func _use_ranged() -> void:
	heat = mini(3, heat + 1) if _heat_t > 0.0 else 0
	_heat_t = HEAT_TIME
	if heat > 0:
		gfx.word(_center() + Vector2(player.facing * 20.0, -58), "ÜBERHITZT +%d %%" % (heat * 50), style.color("orange"), 12)


func _lifted(tg: Node) -> bool:
	var og = tg.get("on_ground")
	if og != null:
		return not og
	var air = tg.get("air")  # training dummies
	return air != null and float(air) > 2.0


# --- casting -------------------------------------------------------------------

func _zug_for(dir: String) -> String:
	var z := style.zug_in(dir)
	if z == "":
		z = style.zug_in("neutral")
	return z


func cast(dir: String) -> bool:
	if player.in_super or busy():
		return false
	var z := _zug_for(dir)
	if z == "":
		return false
	if cooldowns.get(z, 0.0) > 0.0 and not (z == "fernschritt" and burst_time > 0.0):
		return false
	if z == "fernschritt":
		_teleports = _teleports.filter(func(tt): return Time.get_ticks_msec() - tt < TELEPORT_WINDOW * 1000.0)
		if ki < ki_cost(z) * (0.75 if style.active_alt.get(z, "") == "luft" else 1.0):
			_say_no("KI FEHLT")
			return false
		if _teleports.size() >= 2 and burst_time <= 0.0:
			_say_no("NOCH NICHT")
			return false
	_begin(z)
	return true


func _say_no(text: String) -> void:
	gfx.word(_center() + Vector2(0, -50), text, style.color("pale"), 13)
	Sfx.play("block", -8.0)


func _begin(z: String) -> void:
	zug_id = z
	t = 0.0
	frames = style.frames(z).duplicate()
	enhanced = false
	_decided = false
	params = style.params(z, false)
	_hit_set = {}
	_reported = false
	_step = 0
	_age = 0.0
	_hit_any = false
	_weak = false
	_boost_spent = false
	_charge = 0.0
	_aim = 0.0
	_evade = false
	_back_kick = false
	_push_t = 0.0
	_x_start = player.global_position.x
	_y_start = player.global_position.y
	_flow = _since_last < FLOW_TIME and _last_zug != "" and _last_zug != z
	var alt_cd = style.alt(z).get("cd", null)
	cooldowns[z] = float(alt_cd) if alt_cd != null else float(style.zug(z).get("cd", 1.0))
	if z == "fernschritt" and burst_time > 0.0:
		cooldowns[z] = 0.4
	player.move = {}
	phase = "startup"
	match z:
		"kernstrahl":
			phase = "charge"
			_weak = ki < ki_cost(z)
		"meteor_abschluss":
			if not player.is_on_floor():
				player.velocity.y = minf(player.velocity.y, -60.0)
		"ruhiger_gegenschlag":
			frames[1] = int(round(float(params.get("stance", 0.25)) * 60.0))
		"himmelsauftakt":
			if params.get("boost", false) and not player.is_on_floor() and not _air_boost_used and spend_ki(ki_cost(z)):
				_boost_spent = true
				_air_boost_used = true


func _decide_enhanced() -> void:
	_decided = true
	if zug_id == "kernstrahl" or zug_id == "sammeln" or zug_id == "sonnenkern_prep":
		return
	if not Input.is_action_pressed("special") or not (player.gauge >= 100.0 or player.infinite_aura):
		return
	if not player.infinite_aura:
		player.gauge -= 100.0
	_make_enhanced("VERSTÄRKT")


func _make_enhanced(label: String) -> void:
	enhanced = true
	params = style.params(zug_id, true)
	var c := _fist()
	gfx.ring(c, 30.0, style.color("gold"), 0.35, 4.0)
	gfx.gburst("schockring", c, 54.0, 0.3, randf() * TAU)
	gfx.word(c + Vector2(-player.facing * 18.0, -40), label, style.color("gold"), 18, -0.05)
	world.fx.flash(0.12 * FxSettings.factor("flash"), Color(0.75, 0.9, 1.0))


func interrupt() -> void:
	if zug_id == "sonnenkern_prep" and sun_super != null and is_instance_valid(sun_super):
		sun_super.call("abort")
	zug_id = ""
	phase = ""
	countering = false


func _end_zug() -> void:
	_last_zug = zug_id
	_since_last = 0.0
	zug_id = ""
	phase = ""
	countering = false


func _next_phase() -> void:
	t = 0.0
	match phase:
		"startup", "charge":
			phase = "active"
		"active", "fall", "counter", "kick", "volley":
			phase = "recovery"
		"recovery":
			_end_zug()


# --- geometry ---------------------------------------------------------------------

func _shoulder() -> Vector2:
	return player.global_position + Vector2(player.facing * 3.0, -27.0)


func _fist() -> Vector2:
	return player.global_position + Vector2(player.facing * 12.0, -24.0)


func _center() -> Vector2:
	return player.global_position + Vector2(0, -20)


func _fwd(d: float, y := 0.0) -> Vector2:
	return Vector2(player.facing * d, y)


func _rect_front(x0: float, w: float, y_top: float, h: float) -> Rect2:
	var x := player.global_position.x + (x0 if player.facing > 0 else -x0 - w)
	return Rect2(x, player.global_position.y + y_top, w, h)


func _targets() -> Array:
	return world.get_tree().get_nodes_in_group("targets")


# --- per frame ----------------------------------------------------------------

func tick(delta: float) -> void:
	for z in cooldowns:
		cooldowns[z] = maxf(0.0, cooldowns[z] - delta)
	invuln = maxf(0.0, invuln - delta)
	_since_last += delta
	if _heat_t > 0.0:
		_heat_t -= delta
		if _heat_t <= 0.0:
			heat = 0
	for id in _shock_cd.keys():
		_shock_cd[id] -= delta
		if _shock_cd[id] <= 0.0:
			_shock_cd.erase(id)
	if player.is_on_floor():
		_air_boost_used = false
	_tick_fade(delta)
	_tick_burst(delta)
	_tick_orbs(delta)
	if not busy():
		_check_gather(delta)
		if burst_time <= 0.0:
			_idle_glow()
		return
	t += delta
	_age += delta
	if phase != "charge" and not _decided and _age >= 0.15:
		_decide_enhanced()
	match zug_id:
		"sammeln":
			_tick_gather(delta)
		"steilpfad_folge":
			_tick_folge()
		"kernstrahl":
			_tick_strahl(delta)
		"himmelsauftakt":
			_tick_auftakt()
		"ruhiger_gegenschlag":
			_tick_gegen()
		"fernschritt":
			_tick_fern()
		"meteor_abschluss":
			_tick_meteor()


func _tick_fade(delta: float) -> void:
	if gathering() or player.in_super:
		_idle_t = 0.0
		return
	_idle_t += delta
	if _idle_t > FADE_WAIT and ki > KI_FLOOR:
		ki = maxf(KI_FLOOR, ki - 5.0 * delta)


func _idle_glow() -> void:
	# a faint glow in the fist that grows with the Ki
	if ki >= 60.0 and randf() < 0.15 and player.sprite.visible:
		gfx.glow(_fist(), Color(style.color("sky"), 0.25 + ki / 400.0), 5.0 + ki / 20.0, 0.12)


func _tick_burst(delta: float) -> void:
	if exhaust > 0.0:
		exhaust -= delta
	if burst_time <= 0.0:
		return
	burst_time -= delta
	var p := player.global_position
	gfx.aura(p, 0.7, style.color("white").lerp(style.color("sky"), 0.5), 1.3)
	# glowing Ki-Bahnen on the forearms
	var arm := _fist()
	gfx.glow(arm, Color(style.color("sky"), 0.5), 7.0, 0.05)
	gfx.glow(arm + _fwd(-6, 3), Color(style.color("white"), 0.4), 4.0, 0.05)
	if randf() < 0.3:
		gfx.motes(p + Vector2(0, -24), 1, 14.0, style.color("pale"), 0.6)
	if randf() < 0.12:
		gfx.rocks(p, 1, 26.0)
	if burst_time <= 0.0:
		burst_time = 0.0
		exhaust = 1.0
		gfx.word(_center() + Vector2(0, -52), "ERSCHÖPFT", style.color("pale"), 14)
		gfx.ring(_center(), 40.0, style.color("pale"), 0.4, 2.0)


# --- Ki sammeln -------------------------------------------------------------------

func _check_gather(delta: float) -> void:
	var want: bool = player.is_on_floor() and Input.is_action_pressed("move_down") and not Input.is_action_pressed("special") \
		and player.move.is_empty() and not player.blocking and player.hitstun <= 0.0 and player.dash_timer <= 0.0 \
		and Input.get_axis("move_left", "move_right") == 0.0
	_down_t = _down_t + delta if want else 0.0
	if _down_t >= GATHER_HOLD:
		_down_t = 0.0
		zug_id = "sammeln"
		phase = "active"
		t = 0.0
		_age = 0.0
		_decided = true
		_ki_full_said = ki >= KI_MAX
		player.velocity.x = 0.0
		gfx.word(_center() + Vector2(0, -52), "HAAA…", style.color("pale"), 14)
		gfx.ring(player.global_position + Vector2(0, -4), 30.0, style.color("sky"), 0.35, 3.0)
		Sfx.play("dash", -4.0)


func _tick_gather(delta: float) -> void:
	var stop := not Input.is_action_pressed("move_down") or Input.is_action_just_pressed("special") \
		or Input.is_action_just_pressed("light") or Input.is_action_just_pressed("heavy") \
		or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("dash") or not player.is_on_floor()
	if stop:
		zug_id = ""
		phase = ""
		return
	add_ki(KI_GATHER * delta)
	var k := clampf(t / 0.6, 0.0, 1.0)
	var p := player.global_position
	gfx.aura(p, 0.45 + 0.55 * k, style.color("sky"))
	if randf() < 0.35:
		gfx.rocks(p, 1, 34.0)
	if randf() < 0.25:
		world.dust.puff(p + Vector2(randf_range(-14, 14), 0), randf_range(-1, 1), 1, 1.6, 22.0)
	if fmod(t, 0.5) < delta:
		gfx.ring(p + Vector2(0, -6), 26.0 + 10.0 * k, style.color("sky"), 0.35, 2.0)
		world.fx.shake((0.6 + ki / 60.0) * FxSettings.factor("shake"))
	if ki >= KI_MAX and not _ki_full_said:
		_ki_full_said = true
		world.fx.flash(0.12 * FxSettings.factor("flash"), Color(0.8, 0.92, 1.0))


## Taking a hit while charging Ki hurts more (+25 %); the Sonnenkern breaks.
func guard_hit(damage: float, _from_x: float, _source: Node) -> bool:
	if zug_id == "sammeln":
		player.hp = maxf(1.0, player.hp - damage * 0.25)
		gfx.word(_center() + Vector2(0, -56), "UNTERBROCHEN", style.color("orange"), 13)
	return false


# --- hits, Fluss, Erschütterung ----------------------------------------------------

func on_zug_hit(zid: String, targets: Array) -> void:
	if targets.is_empty():
		return
	_hit_any = true
	player.add_gauge(6.0 if zid == zug_id and not _reported else 1.5)
	if zid == zug_id:
		_reported = true


func on_normal_hit() -> void:
	add_ki(KI_FLOW if (_since_last < FLOW_TIME and _last_zug != "") else KI_NORMAL)


## Melee or Ki hit in a rect. `melee` gives Ki, `shock` = Ki-Erschütterung.
func _hit(rect: Rect2, dmg: float, kb: float, profile := "", launch := 0.0, hit_set = null, melee := true, shock := false) -> Array:
	var lifted: Array = []
	for tg in _targets():
		if rect.intersects(tg.get_hurt_rect()) and _lifted(tg):
			lifted.append(tg)
	var out := GlutHazard.strike(world, rect, dmg, player.global_position.x, kb, profile, launch, hit_set, "")
	if out.is_empty():
		return out
	if melee:
		add_ki(KI_FLOW if _flow else KI_HIT)
	for tg in out:
		if tg in lifted:
			add_ki(KI_LIFTED)
	if shock:
		_shock(out, dmg)
	on_zug_hit(zug_id, out)
	return out


func _shock(targets: Array, dmg: float) -> void:
	for tg in targets:
		if not is_instance_valid(tg):
			continue
		var id: int = tg.get_instance_id()
		if _shock_cd.has(id):
			continue
		_shock_cd[id] = SHOCK_CD
		var c: Vector2 = tg.get_hurt_rect().get_center()
		if tg.has_method("posture_hit"):
			tg.posture_hit(dmg * 3.0, player.global_position.x)
		gfx.gburst("schockring", c, 90.0, 0.4, randf() * TAU)
		gfx.ring(c, 46.0, style.color("sky"), 0.4, 4.0)
		gfx.ring(c, 28.0, style.color("white"), 0.3, 2.0)
		gfx.word(c + Vector2(0, -46), "ERSCHÜTTERT!", style.color("sky"), 15)
		world.fx.shake(5.0 * FxSettings.factor("shake"), player.facing)
		world.fx.freeze(0.06 * FxSettings.factor("stop"))


func _kimpact(c: Vector2, size: float, word := "", id := "faust", col := Color.WHITE) -> void:
	var big := enhanced or size > 60.0
	gfx.gburst(id, c, size * (1.2 if big else 1.0), 0.3, randf_range(-0.3, 0.3), player.facing < 0, col)
	gfx.shards(c, 0.0 if player.facing > 0 else PI, 1.0, 6, 240.0, style.color("gold"))
	gfx.glow(c, Color(style.color("sky"), 0.5), size * 0.4, 0.15)
	if word != "":
		gfx.word(c + Vector2(0, -30), word, style.color("white"), 18 if not big else 22)
	world.fx.shake((2.0 if not big else 4.0) * FxSettings.factor("shake"), player.facing)


# --- Steilpfad-Folge ------------------------------------------------------------------

func _tick_folge() -> void:
	var n := int(params.get("hits", 3)) + 1
	var reach := float(params.get("reach", 30))
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
	elif phase == "active":
		var dur := _f(1)
		var due := mini(n, int(t / dur * n + 0.5))
		while _step < due:
			_step += 1
			var last := _step == n
			if float(params.get("advance", 0)) > 0.0:
				_push_v = float(params.advance) / 0.08
				_push_t = 0.08
			if not last:
				var up := -30.0 + (_step % 2) * 6.0
				var rect := _rect_front(4.0, reach + 6.0, up - 4.0, 18.0)
				var tg := _hit(rect, float(params.get("damage", 4.8)), 50.0, "light", 0.0, {})
				var tip := player.global_position + _fwd(reach, up + 6.0)
				gfx.speedlines(tip, 0.0 if player.facing > 0 else PI, 2, 18.0, style.color("white"), 0.1)
				Sfx.play("swing_light", -4.0)
				if not tg.is_empty():
					_kimpact(tip, 34.0, "BAM" if _step % 2 == 1 else "")
			else:
				var heavy: bool = params.get("heel", false) or params.get("heavy_finish", false)
				var rect2 := _rect_front(0.0, reach + 18.0, -40.0, 40.0)
				var tg2 := _hit(rect2, float(params.get("finish", 9.6)), 200.0 if heavy else 150.0, "heavy", 80.0 if heavy else 0.0, {}, true, heavy)
				var c := player.global_position + Vector2(0, -22)
				gfx.arc(c, 22.0, -PI * 0.9 if player.facing > 0 else -PI * 0.1, PI * 0.2 if player.facing > 0 else PI * 1.2, 9.0, style.color("sky"), 0.25)
				gfx.gburst("tritt", c + _fwd(14), 70.0, 0.3, 0.0, player.facing < 0)
				Sfx.play("swing_heavy")
				if not tg2.is_empty():
					_kimpact(c + _fwd(reach + 6), 56.0, "KRAASH!" if heavy else "BAM!")
		if t >= dur:
			_next_phase()
	elif phase == "recovery":
		if t >= _f(2):
			_next_phase()


# --- Kernstrahl -------------------------------------------------------------------------

func _tick_strahl(delta: float) -> void:
	var cmax := float(params.get("charge", 0.8))
	var fist := player.global_position + _fwd(-4.0, -27.0)
	if phase == "charge":
		_charge += delta
		var k := clampf(_charge / cmax, 0.0, 1.0)
		if not _weak:
			gfx.orb(fist, 3.0 + 6.0 * k, style.color("sky"))
			if randf() < 0.5:
				var from := fist + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(18, 34)
				gfx.glow(from, Color(style.color("pale"), 0.6), 3.0, 0.12, (fist - from) * 6.0)
			if k >= 1.0 and _step == 0:
				_step = 1
				gfx.ring(fist, 20.0, style.color("white"), 0.25, 2.0)
				gfx.word(fist + Vector2(-player.facing * 16.0, -26), "VOLL", style.color("white"), 14)
		var held := Input.is_action_pressed("special") and _charge < cmax + 0.05
		var min_t := _f(0)
		if _charge >= min_t and (not held or _charge >= cmax):
			_fire(k)
		return
	if phase == "active":
		if _weak:
			if t >= _f(1) * 0.5:
				_next_phase()
			return
		var dur := _f(1)
		var v := 0.0
		if Input.is_action_pressed("move_up"):
			v = -1.0
		elif Input.is_action_pressed("move_down"):
			v = 1.0
		_aim = clampf(_aim + v * delta * 0.9, -0.26, 0.26)
		var palm := player.global_position + _fwd(14.0, -24.0)
		var dir := Vector2(player.facing, 0).rotated(_aim * player.facing)
		var length := float(params.get("length", 320))
		var w := float(params.get("width", 16)) * (1.25 if enhanced else 1.0)
		var grow := clampf(t / 0.06, 0.0, 1.0)
		var end := palm + dir * length * grow
		if not params.get("pierce", false):
			var hit_d := _first_on_line(palm, dir, length, w)
			if hit_d >= 0.0:
				end = palm + dir * minf(length * grow, hit_d + 8.0)
		_beam_end = end
		gfx.beam(palm, end, w, 1.0 if grow >= 1.0 else grow)
		if randf() < 0.6:
			gfx.shards(palm, dir.angle(), 0.7, 2, 220.0, style.color("pale"))
		if randf() < 0.4:
			gfx.gburst("kern", end, w * 4.0, 0.12, randf() * TAU)
		# 3 ticks of damage along the line
		var due := mini(3, int(t / dur * 3.0 + 0.34))
		while _step < due:
			_step += 1
			var last := _step == 3
			var tg := _beam_hit(palm, end, w, _beam_dmg / 3.0, 260.0 if last else 40.0, "heavy" if last else "light", enhanced and last)
			if not tg.is_empty() and last:
				_kimpact(end, 70.0, "ZWOOM!", "kern")
			world.fx.shake((2.0 + w * 0.12) * FxSettings.factor("shake"), player.facing)
		if t >= dur:
			_next_phase()
	elif phase == "recovery":
		if t >= _f(2):
			_next_phase()


func _fire(k: float) -> void:
	phase = "active"
	t = 0.0
	_step = 0
	if _weak:
		var r := _rect_front(4.0, 26.0, -36.0, 26.0)
		var tg := _hit(r, 5.0, 120.0, "light", 0.0, {}, false)
		gfx.gburst("kern", _fist() + _fwd(10), 30.0, 0.2)
		gfx.word(_center() + Vector2(0, -50), "KI FEHLT", style.color("pale"), 13)
		Sfx.play("swing_light")
		if not tg.is_empty():
			_kimpact(_fist() + _fwd(16), 26.0, "")
		return
	var full := k >= 1.0
	if full and Input.is_action_pressed("special") and (player.gauge >= 100.0 or player.infinite_aura):
		if not player.infinite_aura:
			player.gauge -= 100.0
		_make_enhanced("VOLL GELADEN!")
		params = style.params(zug_id, true)
	_use_ranged()
	var cost := ki_cost(zug_id)
	var dmg := lerpf(float(params.get("min_dmg", 12)), float(params.get("max_dmg", 24)), k)
	if ki >= 50.0 and ki >= cost + 20.0:
		cost += 20.0
		dmg *= 1.4
		gfx.word(_center() + Vector2(-player.facing * 10.0, -64), "KI-VERSTÄRKT!", style.color("sky"), 15)
	spend_ki(minf(cost, ki))
	_beam_dmg = dmg
	var palm := player.global_position + _fwd(14.0, -24.0)
	gfx.gburst("kern", palm, 60.0 + 30.0 * k, 0.3)
	gfx.ring(palm, 26.0, style.color("white"), 0.25, 3.0)
	world.fx.flash((0.1 + 0.15 * k) * FxSettings.factor("flash"), Color(0.75, 0.9, 1.0))
	if full:
		world.fx.flash(0.3 * FxSettings.factor("flash"), Color(0.9, 0.97, 1.0))
		world.fx.punch(0.04)
	world.fx.freeze(0.03 * FxSettings.factor("stop"))
	Sfx.play("break" if full else "swing_heavy")
	if int(params.get("recoil", 0)) > 0:
		_push_v = -260.0
		_push_t = 0.16
		if not player.is_on_floor():
			player.velocity.y = -200.0


## Distance along the beam to the first target, or -1.
func _first_on_line(a: Vector2, dir: Vector2, length: float, w: float) -> float:
	var best := -1.0
	var d := 0.0
	while d <= length:
		var p := a + dir * d
		var r := Rect2(p - Vector2(8, w * 0.5), Vector2(16, w))
		for tg in _targets():
			if r.intersects(tg.get_hurt_rect()):
				return d
		d += 12.0
	return best


func _beam_hit(a: Vector2, b: Vector2, w: float, dmg: float, kb: float, profile: String, shock: bool) -> Array:
	var hs := {}
	var out: Array = []
	var dir := (b - a).normalized()
	var d := 0.0
	var length := a.distance_to(b)
	while d <= length:
		var p := a + dir * d
		var r := Rect2(p - Vector2(10, w * 0.6), Vector2(20, w * 1.2))
		out.append_array(_hit(r, dmg, kb, profile, 0.0, hs, false, shock))
		d += 16.0
	return out


# --- Himmelsauftakt -----------------------------------------------------------------------

func _tick_auftakt() -> void:
	var kind: String = params.get("kind", "upper")
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
			Sfx.play("swing_heavy")
			var rise := float(params.get("rise", 260))
			if _boost_spent:
				rise = 380.0
				gfx.gburst("aura", player.global_position + Vector2(0, -16), 70.0, 0.3)
				gfx.word(_center() + Vector2(0, -50), "KI-AUFTRIEB!", style.color("sky"), 15)
			player.velocity.y = -rise
			gfx.ring(player.global_position, 24.0, style.color("sky"), 0.3, 3.0)
			world.dust.puff(player.global_position, 0.0, 4, 2.0, 30.0)
	elif phase == "active":
		var w := float(params.get("w", 34))
		var rect: Rect2
		if kind == "spin":
			rect = Rect2(player.global_position.x - w * 0.5, player.global_position.y - 70, w, 56)
		else:
			rect = _rect_front(0.0, w, -64.0, 54.0)
		var launch := float(params.get("launch", 380)) * float(params.get("launch_mul", 1.0))
		var hs = _hit_set
		if params.get("single", false) and _hit_any:
			hs = null
		if hs != null:
			var tg := _hit(rect, float(params.get("damage", 10.4)), 40.0, "heavy", launch, hs, true, enhanced)
			if not tg.is_empty() and _step == 0:
				_step = 1
				_kimpact(tg[0].get_hurt_rect().get_center(), 52.0, "BAM!")
		if randf() < 0.6:
			world.afterimages.add(player.sprite.snapshot(), Color(0.7, 1.2, 1.8, 0.45))
		if kind == "spin":
			gfx.arc(_center() + Vector2(0, -10), 28.0, -PI, 0.0, 9.0, style.color("sky"), 0.2)
		else:
			gfx.speedlines(_fist(), -PI / 2.0, 1, 26.0, style.color("white"), 0.12)
		if t >= _f(1):
			_next_phase()
	elif phase == "recovery":
		# Sprung within 0.4 s after a hit: the air kick follows
		if _hit_any and t < 0.4 and Input.is_action_just_pressed("jump"):
			phase = "kick"
			t = 0.0
			_step = 0
			player.velocity.y = -300.0
			return
		if t >= _f(2):
			_next_phase()
	elif phase == "kick":
		if _step == 0 and t >= 0.1:
			_step = 1
			var tg2 := _hit(_rect_front(0.0, 40.0, -46.0, 40.0), float(params.get("kick", 7.2)), 160.0, "heavy", 200.0, {})
			gfx.gburst("tritt", _center() + _fwd(18), 64.0, 0.28, -0.4 * player.facing, player.facing < 0)
			Sfx.play("swing_heavy")
			if not tg2.is_empty():
				_kimpact(_center() + _fwd(30), 46.0, "WHAM!")
		if t >= 0.25:
			_next_phase()


# --- Ruhiger Gegenschlag ---------------------------------------------------------------

func _tick_gegen() -> void:
	var c := _center()
	var mode: String = params.get("mode", "parry")
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
			countering = true
			gfx.word(c + Vector2(0, -44), "…", style.color("pale"), 16)
	elif phase == "active":
		countering = true
		gfx.glow(_fist(), Color(style.color("sky"), 0.35), 12.0, 0.05)
		gfx.ring(c, 18.0, Color(style.color("pale"), 0.5), 0.06, 1.0)
		var end := _f(1)
		if mode == "ki_guard" and Input.is_action_pressed("special") and t < 1.0:
			# Ki-Deckung: 10 Ki per 0.2 s keeps the stance up
			if fmod(t, 0.2) < get_physics_process_delta_time() and t > 0.05:
				if not spend_ki(10.0):
					end = 0.0
			gfx.aura(player.global_position, 0.4, style.color("sky"), 0.7)
			end = maxf(end, t + 0.02) if ki >= 10.0 else end
		if t >= end:
			countering = false
			frames[2] = int(frames[2]) + 18  # missed timing: open
			_next_phase()
	elif phase == "counter":
		if _evade:
			if Input.is_action_just_pressed("special") and not _back_kick and t < 0.4:
				_back_kick = true
				player.facing = -player.facing if _step == 1 else player.facing
				var tg := _hit(_rect_front(0.0, 40.0, -44.0, 40.0), 12.0, 200.0, "heavy", 60.0, {}, true, enhanced)
				gfx.gburst("tritt", _center() + _fwd(16), 66.0, 0.3, 0.0, player.facing < 0)
				if not tg.is_empty():
					_kimpact(_center() + _fwd(26), 50.0, "BAM!")
			if t >= 0.45:
				_next_phase()
		elif t >= 0.3:
			_next_phase()
	elif phase == "recovery":
		if t >= _f(2):
			_next_phase()


func try_counter(from_x: float, projectile: Node = null) -> bool:
	if zug_id != "ruhiger_gegenschlag" or phase != "active":
		return false
	var c := _center()
	var mode: String = params.get("mode", "parry")
	countering = false
	phase = "counter"
	t = 0.0
	_step = 0
	player.facing = 1 if from_x >= player.global_position.x else -1
	if projectile != null and projectile.has_method("burn"):
		projectile.burn()
	add_ki(15.0)
	player.add_gauge(10.0)
	world.fx.freeze(0.08 * FxSettings.factor("stop"))
	if mode == "evade":
		_evade = true
		_step = 1
		invuln = 0.45
		# slip through the attack to the other side
		player.global_position.x = clampf(from_x + player.facing * 26.0, 10.0, TrainingRoom.WIDTH - 10.0)
		world.afterimages.add(player.sprite.snapshot(), Color(0.7, 1.2, 1.8, 0.6))
		gfx.word(c + Vector2(0, -46), "WUSCH", style.color("pale"), 16)
		Sfx.play("dash")
		return true
	invuln = 0.4
	gfx.gburst("schockring", _fist() + _fwd(6), 70.0, 0.3)
	gfx.ring(c, 36.0, style.color("white"), 0.3, 3.0)
	gfx.word(c + Vector2(0, -46), "ABGELENKT!", style.color("white"), 18)
	world.fx.flash(0.15 * FxSettings.factor("flash"), Color(0.8, 0.92, 1.0))
	Sfx.play("block")
	var dmg := float(params.get("counter_damage", 14.4))
	var tg := _hit(_rect_front(0.0, 42.0, -44.0, 44.0), dmg, 240.0, "heavy", 40.0, {}, true, enhanced)
	if not tg.is_empty():
		_kimpact(_fist() + _fwd(20), 60.0, "KONTER!")
	return true


# --- Fernschritt ------------------------------------------------------------------------

func _tick_fern() -> void:
	var c := _center()
	if phase == "startup":
		# eyes closed, fist into the palm, a Ki thread to the target
		if randf() < 0.5:
			var from := c + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(16, 30)
			gfx.glow(from, Color(style.color("pale"), 0.6), 2.5, 0.12, (c - from) * 5.0)
		var tg = _pick_target()
		if tg != null:
			gfx.mark(tg.get_hurt_rect().get_center(), clampf(t / _f(0), 0.0, 1.0))
		if t >= _f(0):
			_teleport(tg)
			_next_phase()
	elif phase == "active":
		if t >= _f(1):
			_next_phase()
	elif phase == "recovery":
		if t >= _f(2):
			_next_phase()


func _pick_target():
	var mode: String = params.get("mode", "front")
	var rng := float(params.get("range", 320))
	var best = null
	var best_d := rng
	for tg in _targets():
		var tc: Vector2 = tg.get_hurt_rect().get_center()
		var d := tc.distance_to(_center())
		if mode == "air" and not _lifted(tg):
			d += 200.0
		elif signf(tc.x - player.global_position.x) != float(player.facing):
			d += 60.0  # prefer what is in front
		if d < best_d:
			best_d = d
			best = tg
	return best


func _teleport(tg) -> void:
	var mode: String = params.get("mode", "front")
	var from := player.global_position
	var cost := ki_cost(zug_id)
	if mode == "air" and tg != null and _lifted(tg):
		cost = 20.0 + 7.5
	if not spend_ki(minf(cost, ki)):
		return
	_teleports.append(Time.get_ticks_msec())
	var to := from + _fwd(90.0)
	if mode == "retreat":
		var near = _pick_target()
		var away := -float(player.facing)
		if near != null:
			away = -signf(near.global_position.x - from.x)
		to = from + Vector2(away * 160.0, 0)
	elif tg != null:
		var tp: Vector2 = tg.global_position
		var side := signf(from.x - tp.x)
		if side == 0.0:
			side = -player.facing
		if mode == "behind":
			side = -side
		to = Vector2(tp.x + side * 26.0, from.y)
		if mode == "air":
			to = Vector2(tp.x + side * 22.0, tg.get_hurt_rect().get_center().y + 18.0)
	to.x = clampf(to.x, 12.0, TrainingRoom.WIDTH - 12.0)
	world.afterimages.add(player.sprite.snapshot(), Color(0.7, 1.2, 1.8, 0.7))
	gfx.gburst("fernschritt", from + Vector2(0, -20), 70.0, 0.35)
	gfx.ring(from + Vector2(0, -20), 30.0, style.color("sky"), 0.3, 2.5)
	player.global_position = to
	if mode == "air":
		player.velocity = Vector2.ZERO
	if tg != null and mode != "retreat":
		player.facing = 1 if tg.global_position.x >= to.x else -1
	gfx.gburst("fernschritt", to + Vector2(0, -20), 80.0, 0.35)
	gfx.ring(to + Vector2(0, -20), 36.0, style.color("white"), 0.35, 3.0)
	gfx.speedlines(to + Vector2(0, -20), randf() * TAU, 6, 30.0, style.color("pale"))
	gfx.word(to + Vector2(0, -56), "ZWOOM", style.color("sky"), 15)
	Sfx.play("dash", 2.0)
	if enhanced and tg != null and mode != "retreat":
		var hit := _hit(_rect_front(0.0, 40.0, -44.0, 44.0), 11.2, 180.0, "heavy", 0.0, {}, true, true)
		if not hit.is_empty():
			_kimpact(_fist() + _fwd(16), 56.0, "BAM!")


# --- Meteor-Abschluss -------------------------------------------------------------------

func _tick_meteor() -> void:
	var kind: String = params.get("kind", "hammer")
	if phase == "startup":
		if not player.is_on_floor():
			gfx.glow(player.global_position + Vector2(0, -40), Color(style.color("sky"), 0.4), 10.0, 0.05)
		if t >= _f(0):
			_next_phase()
			Sfx.play("swing_heavy")
			_step = 10 if not player.is_on_floor() else 0
	elif phase == "active":
		if _step == 10:
			# air: double-fist hammer down
			_step = 11
			var heavy: bool = params.get("heavy_finish", false) or enhanced
			var rect := _rect_front(-6.0, 44.0, -24.0, 50.0)
			var tg := _hit(rect, float(params.get("damage", 13.6)), 60.0, "heavy", -float(params.get("slam", 620)), {}, true, heavy)
			gfx.gburst("meteor", player.global_position + _fwd(16, 4), 90.0, 0.35, 0.0, player.facing > 0)
			gfx.speedlines(player.global_position + _fwd(16), PI / 2.0, 5, 40.0, style.color("pale"))
			if not tg.is_empty():
				_kimpact(tg[0].get_hurt_rect().get_center(), 70.0, "KRAASH!", "meteor")
				if params.get("wave", false):
					var gp: Vector2 = tg[0].global_position
					gfx.gburst("schockring", gp + Vector2(0, -10), 120.0, 0.4)
					GlutHazard.strike(world, Rect2(gp.x - 60, gp.y - 40, 120, 44), 6.0, gp.x, 160.0, "heavy", 120.0, _hit_set, "")
			if kind == "follow":
				phase = "fall"
				t = 0.0
				return
			if kind == "volley" and spend_ki(ki_cost(zug_id)):
				_use_ranged()
				phase = "volley"
				t = 0.0
				_step = 20
				return
		elif _step == 0:
			# ground: low sweep that trips
			_step = 1
			var tg2 := _hit(_rect_front(0.0, 46.0, -14.0, 16.0), float(params.get("sweep", 7.2)), 90.0, "heavy", 160.0, {}, true, enhanced)
			gfx.arc(player.global_position + Vector2(0, -6), 26.0, PI if player.facing > 0 else 0.0, PI * 0.1 if player.facing > 0 else PI * 0.9, 7.0, style.color("sky"), 0.22)
			world.dust.puff(player.global_position + _fwd(20), player.facing, 4, 2.0, 30.0)
			if not tg2.is_empty():
				_kimpact(tg2[0].get_hurt_rect().get_center(), 40.0, "FEGER!")
		if t >= _f(1):
			_next_phase()
	elif phase == "fall":
		if randf() < 0.6:
			world.afterimages.add(player.sprite.snapshot(), Color(0.7, 1.2, 1.8, 0.45))
		if player.is_on_floor():
			gfx.gburst("schockring", player.global_position + Vector2(0, -8), 90.0, 0.35)
			world.dust.land(player.global_position, 1.0)
			world.fx.shake(5.0 * FxSettings.factor("shake"))
			gfx.word(player.global_position + Vector2(0, -50), "WUMM!", style.color("white"), 18)
			_next_phase()
		elif t > 1.2:
			_next_phase()
	elif phase == "volley":
		if _step < 23 and t >= (_step - 20) * 0.12:
			_step += 1
			_spawn_orb(player.global_position + _fwd(10, -18), Vector2(player.facing * 150.0, 260.0).rotated(randf_range(-0.15, 0.15)))
		if t >= 0.45:
			_next_phase()
	elif phase == "recovery":
		if t >= _f(2):
			_next_phase()


func _spawn_orb(pos: Vector2, vel: Vector2) -> void:
	_orbs.append({"pos": pos, "vel": vel, "life": 0.8, "hs": {}})
	gfx.gburst("kern", pos, 28.0, 0.15)
	Sfx.play("swing_light", -2.0)


func _tick_orbs(delta: float) -> void:
	for o in _orbs:
		o.life -= delta
		o.pos += o.vel * delta
		gfx.orb(o.pos, 4.5, style.color("sky"))
		var r := Rect2(o.pos - Vector2(7, 7), Vector2(14, 14))
		var tg := GlutHazard.strike(world, r, float(params.get("orb", 3.2)) if zug_id == "meteor_abschluss" else 3.2, o.pos.x - 10.0, 60.0, "light", 0.0, o.hs, "")
		if not tg.is_empty() or o.pos.y > GlutHazard.ground_y(o.pos.x, o.pos.y - 20.0):
			o.life = 0.0
			gfx.gburst("kern", o.pos, 46.0, 0.25)
			gfx.ring(o.pos, 18.0, style.color("sky"), 0.25, 2.0)
			on_zug_hit("meteor_abschluss", tg)
	_orbs = _orbs.filter(func(o): return o.life > 0.0)


# --- movement & pose for the player --------------------------------------------

func drive_velocity(v: Vector2, delta: float, on_floor: bool) -> Vector2:
	var g := minf(v.y + Player.GRAVITY * delta, Player.MAX_FALL)
	if _push_t > 0.0:
		_push_t -= delta
		return Vector2(player.facing * _push_v, g if not on_floor else v.y)
	match zug_id:
		"sammeln", "sonnenkern_prep":
			return Vector2(0.0, g)
		"kernstrahl":
			if phase == "charge":
				return Vector2(move_toward(v.x, 0.0, 1600.0 * delta), minf(v.y + Player.GRAVITY * 0.5 * delta, Player.MAX_FALL))
			if phase == "active":
				return Vector2(0.0, 0.0 if not on_floor else g)
		"himmelsauftakt":
			if phase == "active" or phase == "kick":
				return Vector2(player.facing * 40.0, minf(v.y + Player.GRAVITY * 0.8 * delta, Player.MAX_FALL))
		"ruhiger_gegenschlag":
			return Vector2(0.0, g)
		"fernschritt":
			if params.get("mode", "") == "air" and phase != "startup":
				return Vector2(0.0, minf(v.y + Player.GRAVITY * 0.3 * delta, 60.0))
			return Vector2(0.0, g if phase != "startup" else minf(v.y + Player.GRAVITY * 0.4 * delta, 80.0))
		"meteor_abschluss":
			if phase == "fall":
				return Vector2(player.facing * 20.0, 700.0)
			if phase == "volley":
				return Vector2(0.0, 0.0)
			if phase == "startup" and not on_floor:
				return Vector2(v.x * 0.9, minf(v.y + Player.GRAVITY * 0.5 * delta, 60.0))
	return super.drive_velocity(v, delta, on_floor)


func pose_frame() -> int:
	match zug_id:
		"sammeln":
			return 6
		"sonnenkern_prep":
			return 5
		"kernstrahl":
			return 1 if phase == "charge" else (3 if phase == "active" else 6)
	if phase == "kick":
		return 4
	if phase == "fall" or phase == "volley":
		return 4
	return super.pose_frame()
