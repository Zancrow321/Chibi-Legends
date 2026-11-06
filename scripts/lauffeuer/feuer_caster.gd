class_name FeuerCaster
extends GlutCaster
## Runs the Züge of the fighting style Lauffeuer (Flammenleib, unarmed) and
## owns its state. Same interface as GlutCaster; the style's own rules:
##  - Brandherde: some Züge leave a small fire on the ground (at most 3, the
##    oldest goes out; each lasts 6 s, does no damage by itself)
##  - Flammenfaust (and Meisterzüge) ignite every Brandherd they touch:
##    eruption with Brand; several eruptions on one target lose damage
##    (100 / 70 / 40 % within 1 s)
##  - Flackerfenster: Flammenleib makes the figure fire for a short window
##    (0.2 s); a dodge that was not needed leaves it open for 0.35 s
##  - J/K are fists and kicks; after a Zug hits they burn for 2 s (fire element)

const MAX_HERDE := 3
const FALLOFF := [1.0, 0.7, 0.4]
const HOT_TIME := 2.0

var herde: Array = []
var chain_n := 0  # eruptions in the current chain (bigger words, more shake)
var _chain_t := 0.0
var _outbreaks: Dictionary = {}  # target id -> [count, seconds since first]
var _hot := 0.0  # fists burn after a Zug hit
var _dodged := false
var _quick := 0.0  # Flammenleib verstärkt: next Zug starts at once
var _charge := 0.0
var _wall: Node2D = null
var _flame_t := 0.0


func setup(p: Player, st: FightingStyle) -> void:
	super.setup(p, st)
	GlutIcons.style_id = st.id


func stage_color() -> Color:
	return style.color("gold")


func trail_color() -> Color:
	return style.color("white") if _hot > 0.0 else style.color("orange")


func normal_element() -> String:
	return "feuer" if _hot > 0.0 else ""


func normal_mul() -> float:
	return 1.0


func blade_heat() -> float:
	return 0.0


func herd_count() -> int:
	return herde.size()


## Creator pose for the current Zug frame (unarmed poses from the style json).
func creator_pose() -> String:
	if not busy():
		return ""
	var lists: Dictionary = style.zug(zug_id).get("creator", {})
	var ph := phase if phase in ["startup", "active", "recovery"] else "active"
	if phase == "counter":
		return "cross_hit"
	var list: Array = lists.get(ph, [])
	if list.is_empty():
		return ""
	if zug_id == "flammenknoechel" and ph == "active":
		return str(list[_step % list.size()]) if _step > 0 else str(list[0])
	var dur := _f(["startup", "active", "recovery"].find(ph))
	var k := clampf(t / maxf(0.001, dur), 0.0, 0.999)
	return str(list[int(k * list.size())])


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
	enhanced = false
	_decided = false
	params = style.params(z, false)
	_hit_set = {}
	_reported = false
	_step = 0
	_dodged = false
	_charge = 0.0
	_x_start = player.global_position.x
	_y_start = player.global_position.y
	_age = 0.0
	cooldowns[z] = style.cooldown(z)
	player.move = {}
	if _quick > 0.0:
		_quick = 0.0
		frames[0] = 1
		fx.ring(_center(), 18.0, style.color("white"), 0.2, 2.0)
	fx.flame(_hand(), 6.0, Vector2(0, -50), 0.3)
	fx.glow(_hand(), Color(style.color("orange"), 0.7), 10.0, 0.2)
	_on_start()
	return true


func _decide_enhanced() -> void:
	_decided = true
	if not Input.is_action_pressed("special") or not (player.gauge >= 100.0 or player.infinite_aura):
		return
	if float(params.get("charge", 0.0)) > 0.0:
		return  # Geladene Faust: holding L charges instead
	if not player.infinite_aura:
		player.gauge -= 100.0
	enhanced = true
	params = style.params(zug_id, true)
	var c := _center()
	fx.ring(c, 26.0, style.color("gold"), 0.3, 3.0)
	fx.flame(c, 14.0, Vector2(0, -80), 0.4, 1.0)
	fx.word(c + Vector2(-player.facing * 18.0, -52), "VERSTÄRKT", style.color("gold"), 16, -0.05)
	world.fx.flash(0.15 * FxSettings.factor("flash"), Color(1, 0.7, 0.3))


func interrupt() -> void:
	if zug_id == "feuerstrom":
		player.velocity.x = 0.0
		player.sprite.modulate.a = 1.0
	_end_wall()
	zug_id = ""
	phase = ""
	countering = false


func _on_start() -> void:
	match zug_id:
		"niederschlag":
			if not player.is_on_floor():
				frames[0] = 5
		"flammenleib":
			if params.get("wall", false):
				frames[1] = 36


# --- helpers ------------------------------------------------------------------------

func _center() -> Vector2:
	return player.global_position + Vector2(0, -22)


func _hand() -> Vector2:
	return player.global_position + Vector2(player.facing * 14.0, -28.0)


func _ground_at(x: float) -> float:
	var gy := GlutHazard.ground_y(x, player.global_position.y - 4.0)
	return gy if gy < 9000.0 else player.global_position.y


## Damage factor for an eruption on this target (100 / 70 / 40 % within 1 s).
func outbreak_factor(tg: Node2D) -> float:
	var id := tg.get_instance_id()
	var e: Array = _outbreaks.get(id, [0, 0.0])
	var k: float = FALLOFF[mini(int(e[0]), FALLOFF.size() - 1)]
	_outbreaks[id] = [int(e[0]) + 1, float(e[1])]
	return k


func place_herd(x: float, y := INF) -> Brandherd:
	var gy := _ground_at(x) if y == INF else y
	while herde.size() >= MAX_HERDE:
		var old: Brandherd = herde[0]
		herde.remove_at(0)
		if is_instance_valid(old):
			old.remove()
	var h := Brandherd.new()
	h.caster = self
	h.position = Vector2(x, gy)
	herde.append(h)
	world.attacks.add_child(h)
	fx.word(Vector2(x, gy - 34), "FSSSH", style.color("orange"), 14)
	return h


func burning_ground(p: Vector2, life: float, size: float) -> void:
	var h := _hazard("krater", p)
	h.life = life
	h.size = size
	h.damage = 3.0
	world.attacks.add_child(h)


func _strike(rect: Rect2, dmg: float, kb: float, profile := "", launch := 0.0, hit_set = null) -> Array:
	var targets := GlutHazard.strike(world, rect, dmg, player.global_position.x, kb, profile, launch, hit_set)
	on_zug_hit(zug_id, targets)
	return targets


# --- per frame ----------------------------------------------------------------

func tick(delta: float) -> void:
	for z in cooldowns:
		cooldowns[z] = maxf(0.0, cooldowns[z] - delta)
	invuln = maxf(0.0, invuln - delta)
	_hot = maxf(0.0, _hot - delta)
	_quick = maxf(0.0, _quick - delta)
	_chain_t += delta
	if _chain_t > 1.0:
		chain_n = 0
	for id in _outbreaks.keys():
		_outbreaks[id][1] += delta
		if _outbreaks[id][1] > 1.0:
			_outbreaks.erase(id)
	_draw_hot_fists(delta)
	if not busy():
		return
	t += delta
	_age += delta
	if not _decided and _age >= 0.15:
		_decide_enhanced()
	match zug_id:
		"flammenknoechel":
			_tick_knoechel()
		"flammenfaust":
			_tick_faust(delta)
		"steigflamme":
			_tick_steig()
		"flammenleib":
			_tick_leib()
		"feuerstrom":
			_tick_strom()
		"niederschlag":
			_tick_nieder()


## Fists glow while they burn (after a Zug hit) and during Züge.
func _draw_hot_fists(delta: float) -> void:
	if not player.sprite.visible or player.in_super:
		return
	if _hot <= 0.0 and not busy():
		return
	_flame_t -= delta
	if _flame_t <= 0.0:
		_flame_t = 0.05
		var hand := _hand() + Vector2(randf_range(-3, 3), randf_range(-3, 3))
		fx.flame(hand, 4.0, Vector2(0, -50), 0.25, 0.95)
		if randf() < 0.3:
			fx.embers(hand, 1, 4.0, 40.0, 0.5)


# --- hits -----------------------------------------------------------------------

func on_zug_hit(zid: String, targets: Array) -> void:
	if targets.is_empty():
		return
	if zid == "herd":
		_chain_t = 0.0
		player.add_gauge(3.0)
		return
	player.add_gauge(6.0 if zid == zug_id and not _reported else 1.5)
	if zid == zug_id:
		_reported = true
	_hot = HOT_TIME


func on_normal_hit() -> void:
	if _hot > 0.0:
		_hot = maxf(_hot, 0.6)


# --- Flammenknöchel ---------------------------------------------------------------

func _tick_knoechel() -> void:
	var dmg: Array = params.get("damage", [5, 5, 11])
	var n := dmg.size()
	var reach: float = float(params.get("reach", 34))
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
	elif phase == "active":
		var due := int(t / maxf(0.001, _f(1)) * n) + 1
		while _step < mini(due, n):
			var i := _step
			_step += 1
			var last := _step == n
			var wide: bool = last and params.get("wide", false)
			var w := reach + (24.0 if wide else 0.0)
			var h := 54.0 if wide else 26.0
			var rect := Rect2(player.global_position.x if player.facing > 0 else player.global_position.x - w, player.global_position.y - 30 - h / 2.0, w, h)
			var tg := _strike(rect, float(dmg[i]), 150.0 if last else 30.0, "heavy" if last else "light", 0.0, {})
			var fist := player.global_position + Vector2(player.facing * (reach * 0.7), -30.0)
			if last:
				FeuerStrip.spawn(world.attacks, "steigflamme" if wide else "ausbruch", fist + Vector2(0, 18), {"anchor": "bottom", "size": 0.8 if wide else 0.7, "hdr": 1.2, "speed": 1.6, "flip": player.facing < 0})
				fx.glow(fist, Color(style.color("gold"), 0.9), 18.0, 0.25)
				fx.sparks(fist, 0.0 if player.facing > 0 else PI, 0.6, 12, 260.0, 0.4)
				fx.word(fist + Vector2(0, -26), "FWOOSH!", style.color("gold"), 20)
				world.fx.shake(3.0 * FxSettings.factor("shake"), player.facing)
				Sfx.play("swing_heavy")
				Sfx.play("lauf_attack", -4.0)
				if params.get("herd", false):
					place_herd(player.global_position.x + player.facing * (reach + 6.0))
			else:
				fx.flame(fist, 5.0, Vector2(player.facing * 60.0, -20), 0.2)
				fx.glow(fist, Color(style.color("orange"), 0.7), 9.0, 0.12)
				Sfx.play("swing_light")
				Sfx.play("lauf_attack", -8.0)
			if not tg.is_empty() and last:
				world.fx.freeze(0.04 * FxSettings.factor("stop"))
		if t >= _f(1):
			_next_phase()
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


# --- Flammenfaust --------------------------------------------------------------------

func _tick_faust(delta: float) -> void:
	var charge_max: float = float(params.get("charge", 0.0))
	if phase == "startup":
		var hold := charge_max > 0.0 and Input.is_action_pressed("special") and _charge < charge_max
		if hold and t >= _f(0) * 0.5:
			_charge += delta
			t = _f(0) * 0.5  # stay in the wind-up while charging
			if fmod(_charge, 0.06) < delta:
				fx.flame(_hand() + Vector2(randf_range(-4, 4), 0), 5.0 + _charge * 8.0, Vector2(0, -60), 0.3)
				fx.glow(_hand(), Color(GlutFx.heat(0.4 + _charge), 0.6), 8.0 + _charge * 14.0, 0.1)
			fx.light(_hand(), Color(1.0, 0.6, 0.3), 1.0 + _charge * 2.0, 0.5, 0.05)
			return
		if t >= _f(0):
			_next_phase()
			_throw_fist()
	elif phase == "active" and t >= _f(1):
		_next_phase()
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


func _throw_fist() -> void:
	var k := clampf(_charge / maxf(0.01, float(params.get("charge", 0.0))), 0.0, 1.0) if float(params.get("charge", 0.0)) > 0.0 else 0.0
	var g := FeuerGeschoss.new()
	g.caster = self
	g.zug_id = zug_id
	g.kind = "faust"
	g.size = float(params.get("scale", 1.0)) * (1.0 + 0.35 * k)
	g.vel = Vector2(player.facing * float(params.get("speed", 520)), 0.0)
	g.dist = float(params.get("dist", 300))
	g.damage = lerpf(float(params.get("damage", 16)), 28.0, k)
	g.pierce = params.get("pierce", false)
	g.kb = 160.0 + 120.0 * k
	g.global_position = _hand() + Vector2(player.facing * 10.0, 2.0)
	world.attacks.add_child(g)
	fx.anvil(_hand(), 14.0 + 8.0 * k, 8)
	fx.ring(_hand(), 18.0, style.color("gold"), 0.25, 3.0)
	fx.word(_hand() + Vector2(player.facing * 20.0, -30), "FWOOSH!", style.color("gold"), 22 + int(k * 8.0))
	world.fx.shake((3.0 + 4.0 * k) * FxSettings.factor("shake"), player.facing)
	world.fx.punch(0.03 + 0.04 * k)
	Sfx.play("swing_heavy", 2.0)
	Sfx.play("lauf_attack", -4.0)


# --- Steigflamme -----------------------------------------------------------------------

func _tick_steig() -> void:
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
			var x := player.global_position.x + player.facing * float(params.get("at", 40))
			var gy := _ground_at(x)
			var boost := 1.0
			for h in herde.duplicate():
				if is_instance_valid(h) and absf(h.global_position.x - x) < 30.0:
					boost = 2.0
					x = h.global_position.x
					h.remove()
					fx.word(Vector2(x, gy - 120), "DOPPELT!", style.color("white"), 20)
					break
			var w: float = float(params.get("width", 30)) * (1.0 + 0.3 * (boost - 1.0))
			FeuerStrip.spawn(world.attacks, "steigflamme", Vector2(x, gy + 4), {"anchor": "bottom", "size": 1.3 * boost * maxf(1.0, w / 30.0), "hdr": 1.3})
			fx.light(Vector2(x, gy - 50), Color(1.0, 0.6, 0.3), 2.4, 0.9, 0.4)
			fx.sparks(Vector2(x, gy - 10), -PI / 2.0, 0.4, 16, 380.0 * boost, 0.7)
			fx.word(Vector2(x, gy - 70 * boost), "FWOOSH!", style.color("gold"), 22)
			world.fx.shake(4.0 * FxSettings.factor("shake"))
			var rect := Rect2(x - w, gy - 100.0 * boost, w * 2.0, 100.0 * boost)
			var launch: float = float(params.get("launch", 360)) * (1.0 if boost <= 1.0 else 1.5)
			var tg := _strike(rect, float(params.get("damage", 12)), 30.0, "heavy", launch, _hit_set)
			if params.get("burn", false):
				for e in tg:
					if e.get("status") is Dictionary:
						e.status["brand"] = 4.0
			if params.get("ride", false):
				player.velocity = Vector2(player.facing * 60.0, -480.0)
			Sfx.play("swing_heavy")
			Sfx.play("lauf_attack", -4.0)
	elif phase == "active" and t >= _f(1):
		_next_phase()
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


# --- Flammenleib ---------------------------------------------------------------------------

func _tick_leib() -> void:
	if params.get("wall", false):
		_tick_schirm()
		return
	var window: float = float(params.get("window", 0.2))
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
			countering = true
			fx.flame(_center(), 16.0, Vector2(0, -60), 0.35, 1.0)
			fx.word(_center() + Vector2(0, -40), "FSSSH", style.color("orange"), 18)
	elif phase == "active":
		countering = t <= window
		_ghost_t -= get_physics_process_delta_time()
		if _ghost_t <= 0.0:
			_ghost_t = 0.03
			player.world.afterimages.add(player.sprite.snapshot(), Color(1.0, 0.45, 0.15, 0.6) * Color(1.8, 1.8, 1.8, 1.0))
			fx.flame(_center() + Vector2(randf_range(-8, 8), randf_range(-12, 12)), 7.0, Vector2(0, -60), 0.3)
		player.sprite.modulate.a = 0.35 if countering else 1.0
		if t >= _f(1):
			countering = false
			player.sprite.modulate.a = 1.0
			if not _dodged:
				frames[2] = int(frames[2]) + int(round(float(params.get("punish", 0.35)) * 60.0))
				fx.smoke(_center(), 10.0, Vector2(0, -20), 0.8)
			_next_phase()
	elif phase == "counter":
		if t >= 0.12:
			phase = "recovery"
			t = 0.0
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


func try_counter(from_x: float, projectile: Node = null) -> bool:
	if zug_id != "flammenleib":
		return false
	if params.get("wall", false):
		if phase == "active" and signf(from_x - player.global_position.x) == float(player.facing) and projectile != null:
			if projectile.has_method("burn"):
				projectile.burn()
			fx.word(_center() + Vector2(player.facing * 30.0, -30), "FSSSH!", style.color("gold"), 18)
			return true
		return false
	if not countering:
		return false
	countering = false
	_dodged = true
	invuln = 0.25
	player.sprite.modulate.a = 1.0
	phase = "counter"
	t = 0.0
	var old := player.global_position
	fx.flame(old + Vector2(0, -20), 18.0, Vector2(0, -90), 0.45, 1.0)
	fx.ring(old + Vector2(0, -20), 30.0, style.color("gold"), 0.35, 4.0)
	fx.word(old + Vector2(0, -60), "FLACKERN!", style.color("white"), 24)
	world.fx.flash(0.18 * FxSettings.factor("flash"), Color(1.0, 0.75, 0.4))
	world.fx.freeze(0.08 * FxSettings.factor("stop"))
	player.add_gauge(12.0)
	if params.get("herd", false):
		place_herd(old.x, _ground_at(old.x))
	if enhanced or params.get("quick", false):
		_quick = 0.5
	if projectile != null and projectile.has_method("burn"):
		projectile.burn()
	return true


## Feuerschirm: a short wall of fire in front that burns light projectiles.
func _tick_schirm() -> void:
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
			var x := player.global_position.x + player.facing * 22.0
			_wall = FeuerStrip.spawn(world.attacks, "feuerschirm", Vector2(x, _ground_at(x) + 4), {"anchor": "bottom", "size": 1.1, "hdr": 1.3, "speed": 0.55})
			fx.word(Vector2(x, player.global_position.y - 90), "FWOOSH!", style.color("gold"), 20)
	elif phase == "active":
		var x2 := player.global_position.x + player.facing * 22.0
		var r := Rect2(x2 - 12, player.global_position.y - 96, 24, 98)
		for pr in world.get_tree().get_nodes_in_group("enemy_projectiles"):
			if pr is Node2D and r.has_point(pr.global_position) and pr.has_method("burn"):
				pr.burn()
				fx.glow(pr.global_position, Color(1, 0.8, 0.4, 0.9), 14.0, 0.2)
		if fmod(t, 0.2) < get_physics_process_delta_time():
			_strike(r, 3.0, 80.0, "light", 0.0, {})
		fx.light(Vector2(x2, player.global_position.y - 40), Color(1.0, 0.6, 0.3), 1.4, 0.7, 0.05)
		if t >= _f(1):
			_end_wall()
			_next_phase()
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


func _end_wall() -> void:
	if _wall != null and is_instance_valid(_wall):
		_wall.queue_free()
	_wall = null


# --- Feuerstrom ------------------------------------------------------------------------------

func _tick_strom() -> void:
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
			_x_start = player.global_position.x
			if params.get("herd", false):
				place_herd(_x_start)
			if params.get("curve", false):
				player.velocity.y = -300.0
			fx.anvil(_center(), 14.0, 6)
			fx.word(_center() + Vector2(0, -36), "FWOOSH!", style.color("gold"), 22)
			Sfx.play("swing_heavy")
			Sfx.play("lauf_attack", -4.0)
	elif phase == "active":
		player.sprite.modulate.a = 0.25
		_ghost_t -= get_physics_process_delta_time()
		if _ghost_t <= 0.0:
			_ghost_t = 0.03
			FeuerStrip.spawn(world.attacks, "feuerstrom", _center(), {"size": 0.9, "hdr": 1.3, "loop": true, "life": 0.12, "fade": 0.1, "flip": player.facing < 0})
			fx.flame(_center() - Vector2(player.facing * 14.0, 0), 8.0, Vector2(-player.facing * 50.0, -30), 0.3)
		fx.light(_center(), Color(1.0, 0.6, 0.3), 1.8, 0.6, 0.05)
		var body := Rect2(player.global_position + Vector2(-16, -44), Vector2(32, 46))
		_strike(body, float(params.get("damage", 7)), 90.0, "light", 60.0, _hit_set)
		if t >= _f(1) or player.is_on_wall():
			player.sprite.modulate.a = 1.0
			fx.flame(_center(), 14.0, Vector2(0, -60), 0.35)
			if params.get("trail", false):
				_leave_trail()
			_next_phase()
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


func _leave_trail() -> void:
	var x1 := player.global_position.x
	if absf(x1 - _x_start) < 8.0 or not player.is_on_floor():
		return
	var h := _hazard("spur", Vector2((x1 + _x_start) * 0.5, player.global_position.y))
	h.x0 = _x_start
	h.x1 = x1
	h.life = 1.0
	h.damage = 3.0
	h.element = "feuer"
	world.attacks.add_child(h)


# --- Glühender Niederschlag ---------------------------------------------------------------------

func _tick_nieder() -> void:
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
			if player.is_on_floor() and not params.get("dive", false):
				_ground_blast()
			elif params.get("dive", false):
				phase = "fall"
				t = 0.0
				_hit_set = {}
				if player.is_on_floor():
					player.velocity.y = -360.0
			else:
				_shoot_down()
	elif phase == "fall":
		_ghost_t -= get_physics_process_delta_time()
		if _ghost_t <= 0.0:
			_ghost_t = 0.03
			player.world.afterimages.add(player.sprite.snapshot(), Color(1.0, 0.5, 0.2, 0.5) * Color(1.6, 1.6, 1.6, 1.0))
			fx.flame(_center(), 9.0, Vector2(0, -80), 0.3)
		var r := Rect2(player.global_position + Vector2(-18, -36), Vector2(36, 40))
		_strike(r, float(params.get("damage", 14)), 60.0, "heavy", -200.0, _hit_set)
		if player.is_on_floor() and t > 0.05:
			_dive_land()
			_next_phase()
		elif t > 1.0:
			_next_phase()
	elif phase == "active" and t >= _f(1):
		_next_phase()
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


func _shoot_down() -> void:
	var fan := int(params.get("fan", 0))
	var n := maxi(1, fan)
	for i in n:
		var a := PI / 4.0
		if n > 1:
			a = lerpf(0.35, 1.25, float(i) / (n - 1))
		var g := FeuerGeschoss.new()
		g.caster = self
		g.zug_id = zug_id
		g.kind = "stoss"
		var speed := 300.0 if params.get("herd", false) else 520.0
		g.vel = Vector2(cos(a) * player.facing, sin(a)) * speed
		g.dist = 600.0
		g.size = 0.7 if n > 1 else 1.0
		g.damage = float(params.get("damage", 14))
		g.ignites = false
		g.pierce = false
		g.herd_on_land = params.get("herd", false)
		g.ground_burn = params.get("ground_burn", false)
		g.global_position = _hand()
		world.attacks.add_child(g)
	fx.anvil(_hand(), 12.0, 6)
	fx.word(_hand() + Vector2(0, -26), "FWOOSH!", style.color("gold"), 20)
	Sfx.play("swing_heavy")
	Sfx.play("lauf_attack", -4.0)
	player.velocity.y = minf(player.velocity.y, -120.0)


func _ground_blast() -> void:
	var x := player.global_position.x + player.facing * 30.0
	var gy := _ground_at(x)
	FeuerStrip.spawn(world.attacks, "einschlag", Vector2(x, gy + 8), {"anchor": "bottom", "size": 0.8, "hdr": 1.3})
	fx.ring(Vector2(x, gy - 4), 26.0, style.color("orange"), 0.3, 4.0)
	fx.word(Vector2(x, gy - 50), "BOOM!", style.color("gold"), 22)
	world.fx.shake(5.0 * FxSettings.factor("shake"))
	var tg := _strike(Rect2(x - 30, gy - 34, 60, 36), float(params.get("damage", 14)), 120.0, "heavy", 200.0, _hit_set)
	if tg.is_empty():
		frames[2] = int(frames[2]) + 18
	if params.get("herd", false):
		place_herd(x, gy)
	if params.get("ground_burn", false):
		burning_ground(Vector2(x, gy), 1.5, 26.0)


func _dive_land() -> void:
	var p := player.global_position
	FeuerStrip.spawn(world.attacks, "einschlag", p + Vector2(0, 8), {"anchor": "bottom", "size": 0.9, "hdr": 1.35})
	fx.ring(p + Vector2(0, -4), 34.0, style.color("orange"), 0.35, 5.0)
	fx.word(p + Vector2(0, -56), "BOOM!", style.color("gold"), 26)
	world.fx.shake(6.0 * FxSettings.factor("shake"))
	world.fx.punch(0.04)
	var hs := {}
	var tg := GlutHazard.strike(world, Rect2(p.x - 34, p.y - 30, 68, 32), float(params.get("damage", 14)) * 0.6, p.x, 140.0, "heavy", 160.0, hs)
	on_zug_hit(zug_id, tg)
	if tg.is_empty() and _hit_set.is_empty():
		frames[2] = int(frames[2]) + 18
	if params.get("ground_burn", false):
		burning_ground(p, 1.5, 26.0)


# --- movement ------------------------------------------------------------------------

func drive_velocity(v: Vector2, delta: float, on_floor: bool) -> Vector2:
	match zug_id:
		"feuerstrom":
			if phase == "active":
				var vy := minf(v.y + Player.GRAVITY * delta * 0.3, Player.MAX_FALL) if params.get("curve", false) else 0.0
				return Vector2(player.facing * float(params.get("dist", 120)) / maxf(0.01, _f(1)), vy)
			return Vector2(move_toward(v.x, 0.0, 2400.0 * delta), minf(v.y + Player.GRAVITY * delta * (0.3 if phase == "startup" else 1.0), Player.MAX_FALL))
		"flammenleib":
			if params.get("wall", false):
				return Vector2(0.0, minf(v.y + Player.GRAVITY * delta, Player.MAX_FALL))
			if phase == "active":
				return Vector2(player.facing * float(params.get("dist", 46)) / maxf(0.01, _f(1)), 0.0)
			if phase == "counter":
				return Vector2(player.facing * 60.0, minf(v.y + Player.GRAVITY * delta, Player.MAX_FALL))
		"niederschlag":
			if phase == "fall":
				return Vector2(player.facing * 260.0, 700.0)
			if phase == "startup" and not on_floor:
				return Vector2(v.x * 0.9, minf(v.y + Player.GRAVITY * 0.6 * delta, 120.0))
		"steigflamme":
			if params.get("ride", false) and phase != "startup":
				return Vector2(v.x, minf(v.y + Player.GRAVITY * delta, Player.MAX_FALL))
	return super.drive_velocity(v, delta, on_floor)
