class_name GlutCaster
extends Node2D
## Runs the Züge of the fighting style Glutatem for the player (special
## button + direction) and owns the style's state:
##  - the Zug currently playing (Einatmen / aktiv / Erholung), its cooldowns
##  - verstärkt: L held during the Einatmen costs 1 Stufe of the Legendenleiste
##  - Atemrhythmus: each *different* Zug that hits in one combo heats the
##    blade one step (Rot, Orange, Weiß); at Weiß the next Zug gets an extra
##    hit and +10 Leiste, then the blade cools down
##  - Weißglut buff (J/K +x % fire damage), Ambosshaltung counter state
## The player calls tick() every physics frame and asks for the velocity
## and the sprite pose while a Zug runs.

const COMBO_TIME := 2.2
const STAGE_NAMES := ["", "Rot", "Orange", "Weiß"]
## Blade line (hand, tip) per frame of the sword strip, foot-relative, facing right.
const BLADE := [
	[Vector2(3, -10), Vector2(18, -7)], [Vector2(6, -12), Vector2(20, -10)], [Vector2(6, -11), Vector2(19, -10)],
	[Vector2(1, -13), Vector2(18, -13)], [Vector2(2, -11), Vector2(18, -21)], [Vector2(-5, -19), Vector2(-17, -30)],
	[Vector2(-3, -18), Vector2(-17, -18)],
]
## Blade in the idle strip (held low at the hip).
const IDLE_BLADE := [Vector2(3, -10), Vector2(17, -6)]

var player: Player
var world: TrainingRoom
var style: FightingStyle
var fx: GlutFx

# current Zug
var zug_id := ""
var phase := ""  # "startup", "active", "recovery", "fall", "counter", "back"
var t := 0.0
var frames: Array = [10, 6, 20]
var params: Dictionary = {}
var enhanced := false
var _decided := false
var _bonus := false  # this activation carries the Weiß bonus
var _bonus_used := false
var _reported := false
var _hit_set: Dictionary = {}
var _step := 0
var _x_start := 0.0
var _y_start := 0.0
var _aftershock := -1.0

var cooldowns: Dictionary = {}

# Atemrhythmus
var stage := 0
var _combo_zuege: Dictionary = {}
var _combo_t := 0.0
var _stage_flash := 0.0

# Weißglut buff
var buff_time := 0.0
var buff_max := 0.0
var buff_bonus := 0.0
var _buff_burnout := false
var _buff_params: Dictionary = {}

# Ambosshaltung
var countering := false
var invuln := 0.0

var _ghost_t := 0.0
var _ember_t := 0.0
var _age := 0.0  # seconds since the current Zug started
var _last_tip := Vector2.INF


func setup(p: Player, st: FightingStyle) -> void:
	player = p
	style = st
	world = p.world
	fx = world.glut_fx
	GlutIcons.style_id = st.id
	for z in style.zug_order:
		cooldowns[z] = 0.0


func busy() -> bool:
	return zug_id != ""


func stage_color() -> Color:
	match stage:
		1:
			return style.color("red")
		2:
			return style.color("orange")
		3:
			return style.color("white")
	return style.color("ember")


## Trail colour for J/K swings: the blade's glow stage (white while Weißglut).
func trail_color() -> Color:
	if buff_time > 0.0:
		return style.color("white")
	if stage == 0:
		return Color("ff7a3d")
	return stage_color()


## J/K during Weißglut: fire element and more damage.
func normal_element() -> String:
	return "feuer" if buff_time > 0.0 else ""


func normal_mul() -> float:
	return 1.0 + buff_bonus if buff_time > 0.0 else 1.0


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
	frames = style.frames(z)
	enhanced = false
	_decided = false
	params = style.params(z, false)
	_hit_set = {}
	_reported = false
	_step = 0
	_x_start = player.global_position.x
	_y_start = player.global_position.y
	_bonus = stage >= 3
	_bonus_used = false
	_age = 0.0
	cooldowns[z] = float(style.zug(z).get("cd", 1.0))
	player.move = {}
	var mouth := _mouth()
	fx.breath(mouth, player.facing, 0.3 + stage * 0.2)
	if _bonus:
		fx.glow(_blade_mid(), style.color("white"), 22.0, 0.3)
		fx.light(_blade_mid(), Color(1, 0.9, 0.7), 2.0, 0.7, 0.3)
	_on_start()
	return true


func interrupt() -> void:
	if zug_id == "ambosshaltung" or zug_id == "funkenflug":
		player.velocity.x = 0.0
	zug_id = ""
	phase = ""
	countering = false


func _f(i: int) -> float:
	return float(frames[i]) / 60.0


func _mouth() -> Vector2:
	return player.global_position + Vector2(player.facing * 7.0, -38.0)


func _blade_mid() -> Vector2:
	return player.global_position + Vector2(player.facing * 10.0, -14.0)


func _front_rect(off_x: float, off_y: float, w: float, h: float) -> Rect2:
	var cx := player.global_position.x + off_x * player.facing
	return Rect2(cx - w / 2.0, player.global_position.y + off_y - h / 2.0, w, h)


# --- per frame ----------------------------------------------------------------

func tick(delta: float) -> void:
	for z in cooldowns:
		cooldowns[z] = maxf(0.0, cooldowns[z] - delta)
	invuln = maxf(0.0, invuln - delta)
	_stage_flash = maxf(0.0, _stage_flash - delta)
	if _combo_t > 0.0:
		_combo_t -= delta
		if _combo_t <= 0.0 and stage > 0:
			_cool_down()
	_tick_buff(delta)
	_draw_blade_heat()
	if _aftershock > 0.0:
		_aftershock -= delta
		if _aftershock <= 0.0:
			_spawn_waves(0.8)
	if not busy():
		return
	t += delta
	_age += delta
	if not _decided and _age >= 0.15:
		_decide_enhanced()
	match zug_id:
		"funkenschlag":
			_tick_funkenschlag()
		"schlackeregen":
			_tick_simple(Callable(self, "_schlacke_throw"))
		"weissglut":
			_tick_weissglut()
		"ambosshaltung":
			_tick_amboss()
		"funkenflug":
			_tick_funkenflug()
		"essensturz":
			_tick_essensturz()


func _decide_enhanced() -> void:
	_decided = true
	if Input.is_action_pressed("special") and (player.gauge >= 100.0 or player.infinite_aura):
		enhanced = true
		if not player.infinite_aura:
			player.gauge -= 100.0
		params = style.params(zug_id, true)
		var c := _blade_mid()
		fx.anvil(c, 14.0, 8)
		fx.ring(c, 22.0, style.color("yellow"), 0.3, 3.0)
		fx.word(c + Vector2(-player.facing * 18.0, -62), "VERSTÄRKT", style.color("yellow"), 16, -0.05)
		world.fx.flash(0.15 * FxSettings.factor("flash"), Color(1, 0.7, 0.3))


func _next_phase() -> void:
	t = 0.0
	match phase:
		"startup":
			phase = "active"
			_on_active()
		"active", "fall", "counter", "back":
			phase = "recovery"
			_on_recovery()
		"recovery":
			zug_id = ""
			phase = ""
			countering = false


## Startup -> active -> recovery by frame data; `on_active` runs once.
func _tick_simple(on_active: Callable) -> void:
	if phase == "startup" and t >= _f(0):
		_next_phase()
		on_active.call()
	elif phase == "active" and t >= _f(1):
		_next_phase()
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


func _on_start() -> void:
	match zug_id:
		"essensturz":
			if player.is_on_floor():
				player.velocity.y = -300.0
			else:
				frames = [6, frames[1], frames[2]]
		"ambosshaltung":
			frames = [frames[0], int(round(float(params.get("stance", 0.4)) * 60.0)), frames[2]]


func _on_active() -> void:
	pass


func _on_recovery() -> void:
	if zug_id == "ambosshaltung":
		countering = false


# --- hits, Atemrhythmus, Leiste -----------------------------------------------

## Called by hazards and by the Zug code when a Zug hits.
func on_zug_hit(zid: String, targets: Array) -> void:
	if targets.is_empty():
		return
	player.add_gauge(6.0 if zid == zug_id and not _reported else 1.5)
	_combo_t = COMBO_TIME
	if zid == zug_id and _bonus and not _bonus_used:
		_bonus_used = true
		_bonus = false
		var tg: Node2D = targets[0]
		var c: Vector2 = tg.get_hurt_rect().get_center()
		world.deal_hit(tg, 8.0, "feuer", player.global_position.x, 160.0, "heavy")
		player.add_gauge(10.0)
		fx.anvil(c, 22.0, 10)
		fx.ring(c, 28.0, style.color("white"), 0.35, 5.0)
		fx.word(c + Vector2(0, -40), "WEISSGLUT!", style.color("white"), 24)
		_cool_down()
		return
	if zid == zug_id and _reported:
		return
	if zid == zug_id:
		_reported = true
	if _combo_zuege.has(zid) or stage >= 3:
		return
	_combo_zuege[zid] = true
	_set_stage(stage + 1)


func _set_stage(s: int) -> void:
	stage = clampi(s, 0, 3)
	_stage_flash = 0.3
	_combo_t = COMBO_TIME
	var c := _blade_mid()
	var col := stage_color()
	fx.glow(c, Color(col, 0.7), 9.0 + stage * 4.0, 0.3)
	fx.sparks(c, -PI / 2.0, 1.4, 6 + stage * 4, 160.0, 0.4)
	fx.light(c, col, 1.2 + stage * 0.5, 0.6, 0.3)
	if stage == 3:
		fx.word(c + Vector2(-player.facing * 16.0, -52), "WEISS!", col, 22)
		fx.ring(c, 22.0, col, 0.35, 4.0)


func _cool_down() -> void:
	stage = 0
	_combo_zuege.clear()
	_combo_t = 0.0


## Ordinary J/K hits keep the combo (and the glow) alive.
func on_normal_hit() -> void:
	if stage > 0:
		_combo_t = COMBO_TIME


func _strike(rect: Rect2, dmg: float, kb: float, profile := "", launch := 0.0, hit_set = null) -> Array:
	var targets := GlutHazard.strike(world, rect, dmg, player.global_position.x, kb, profile, launch, hit_set)
	on_zug_hit(zug_id, targets)
	return targets


func _hazard(kind: String, pos: Vector2) -> GlutHazard:
	var h := GlutHazard.new()
	h.world = world
	h.fx = fx
	h.caster = self
	h.zug_id = zug_id
	h.kind = kind
	h.params = params
	h.global_position = pos
	return h


# --- blade heat & Weißglut ------------------------------------------------------

## How hot the blade glows right now (0 = cold, 1 = white-hot).
func blade_heat() -> float:
	if buff_time > 0.0:
		return 1.0
	if zug_id == "weissglut" and phase == "startup":
		return clampf(t / _f(0), 0.0, 1.0)
	if stage > 0:
		return 0.35 + stage * 0.2
	if busy():
		return 0.3
	return 0.0


## Hand and tip of the blade in the world, matching the sprite frame shown.
func blade_now() -> Array:
	var real := player.sprite.blade_line()  # creator weapon at the hand anchor
	if not real.is_empty():
		return real
	var b: Array = IDLE_BLADE
	match player.sprite.state:
		"attack":
			b = BLADE[clampi(player.sprite.attack_frame, 0, BLADE.size() - 1)]
		"dash":
			b = BLADE[3]
		"cast", "hurt":
			b = BLADE[6]
	var hand: Vector2 = b[0]
	var tip: Vector2 = b[1]
	var pos := player.global_position
	return [pos + Vector2(hand.x * player.facing, hand.y), pos + Vector2(tip.x * player.facing, tip.y)]


func _draw_blade_heat() -> void:
	var heatv := blade_heat()
	if heatv <= 0.0 or not player.sprite.visible or player.in_super:
		_last_tip = Vector2.INF
		return
	var line := blade_now()
	var a: Vector2 = line[0]
	var e: Vector2 = line[1]
	var flick := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.03)
	var col := GlutFx.heat(heatv)
	fx.glow_line(a.lerp(e, 0.25), e, Color(col, 0.9 * flick), 2.0 + heatv * 1.5)
	if _stage_flash > 0.0:
		fx.glow_line(a, e, Color(1, 1, 1, _stage_flash * 2.0), 4.0)
	# swing smear: the hot tip leaves a streak while it moves fast
	if _last_tip != Vector2.INF and _last_tip.distance_to(e) > 5.0 and _last_tip.distance_to(e) < 60.0:
		fx.glow(e, Color(col, 0.55), 4.0 + heatv * 3.0, 0.14, Vector2.ZERO, 0.3)
		fx.glow(_last_tip.lerp(e, 0.5), Color(col, 0.45), 3.0 + heatv * 3.0, 0.12, Vector2.ZERO, 0.3)
		if randf() < 0.5:
			fx.sparks(e, (e - _last_tip).angle(), 0.5, 1, 120.0, 0.3)
	_last_tip = e


func _tick_buff(delta: float) -> void:
	if buff_time <= 0.0:
		return
	buff_time -= delta
	_ember_t -= delta
	if _ember_t <= 0.0:
		_ember_t = 0.06
		fx.embers(_blade_mid(), 1, 6.0, 30.0, 0.7)
		if randf() < 0.3:
			fx.glow(_blade_mid(), GlutFx.heat(0.9), 10.0, 0.2)
	if buff_time <= 0.0:
		buff_time = 0.0
		if _buff_burnout:
			var r: float = _buff_params.get("burnout_radius", 50)
			var c := player.global_position + Vector2(0, -22)
			fx.anvil(c, r * 0.7, 10)
			fx.ring(c, r, style.color("orange"), 0.4, 7.0)
			fx.sparks(c, 0.0, PI, 36, 320.0, 0.6)
			fx.word(c + Vector2(0, -40), "PUFF!", style.color("yellow"), 26)
			world.fx.shake(5.0 * FxSettings.factor("shake"))
			var hs := {}
			var targets := GlutHazard.strike(world, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), float(_buff_params.get("burnout_damage", 18)), c.x, 180.0, "heavy", 120.0, hs)
			if targets.size() > 0:
				player.add_gauge(6.0)
		else:
			fx.smoke(_blade_mid(), 10.0, Vector2(0, -20), 1.0)


# --- Funkenschlag ---------------------------------------------------------------

func _tick_funkenschlag() -> void:
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
			var sides: Array = params.get("sides", [1])
			for s in sides:
				var side: float = float(s) * player.facing
				var o := player.global_position + Vector2(side * 16.0, -16.0)
				fx.anvil(o, 14.0, 8)
				fx.cone(o, side, float(params.len) + 10.0, 0.4, 0.26)
				for i in 3:
					fx.smoke(o + Vector2(side * 10.0, 0), 8.0, Vector2(side * 30.0, -20), 0.9)
				if float(params.get("shield", 0.0)) > 0.0:
					var h := _hazard("schild", o)
					h.dir = side
					h.life = float(params.shield)
					world.attacks.add_child(h)
			fx.word(player.global_position + Vector2(player.facing * 44.0, -46), "KLONG!", style.color("yellow"), 24)
			world.fx.shake(3.0 * FxSettings.factor("shake"), player.facing)
	elif phase == "active":
		var hits: int = int(params.get("hits", 4))
		var due := int(t / maxf(0.001, _f(1)) * hits) + 1
		while _step < mini(due, hits):
			_step += 1
			var last := _step == hits
			var sides2: Array = params.get("sides", [1])
			for s in sides2:
				var side2: float = float(s) * player.facing
				var length: float = params.len
				var ox := player.global_position.x + side2 * 12.0
				var r := Rect2(ox if side2 > 0.0 else ox - length, player.global_position.y - 40, length, 38)
				_strike(r, float(params.damage), 140.0 if last else 30.0, "heavy" if last else "light", 0.0, {})
				fx.sparks(Vector2(ox, player.global_position.y - 16), 0.0 if side2 > 0.0 else PI, 0.35, 5, length * 6.0, 0.35, 300.0)
		if t >= _f(1):
			_next_phase()
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


# --- Schlackeregen -----------------------------------------------------------------

func _schlacke_throw() -> void:
	var n: int = int(params.get("count", 3))
	var big: bool = params.get("big", false)
	var tip := player.global_position + Vector2(player.facing * 10.0, -34.0)
	fx.anvil(tip, 10.0, 6)
	fx.sparks(tip, -PI / 2.0, 0.8, 16, 260.0, 0.5)
	fx.word(tip + Vector2(0, -24), "ZISCH!", style.color("orange"), 22)
	for i in n:
		var k := 0.5 if n == 1 else float(i) / (n - 1)
		var h := _hazard("brocken", tip)
		h.vel = Vector2(player.facing * lerpf(50.0, 190.0, k), -lerpf(340.0, 250.0, k))
		h.damage = float(params.get("damage", 8))
		h.size = 5.0 if big else 3.6
		h.life = 3.0
		world.attacks.add_child(h)


# --- Weißglut ----------------------------------------------------------------------

func _tick_weissglut() -> void:
	if phase == "startup":
		var k := clampf(t / _f(0), 0.0, 1.0)
		_ember_t -= get_physics_process_delta_time()
		if _ember_t <= 0.0:
			_ember_t = 0.04
			fx.embers(_blade_mid(), 2, 8.0, 40.0, 0.7)
			fx.glow(_blade_mid(), GlutFx.heat(k), 8.0 + k * 14.0, 0.15)
			if randf() < 0.4:
				fx.smoke(_blade_mid() + Vector2(0, -6), 6.0, Vector2(0, -26), 0.9)
		fx.light(_blade_mid(), GlutFx.heat(k), 0.6 + k * 1.6, 0.4 + k * 0.4, 0.05)
		if t >= _f(0):
			_next_phase()
			var r := _front_rect(24, -26, 50, 34)
			_strike(r, float(params.get("damage", 14)), 160.0, "heavy")
			var c := player.global_position + Vector2(player.facing * 24.0, -24.0)
			fx.anvil(c, 20.0, 9)
			fx.ring(c, 26.0, style.color("white"), 0.3, 4.0)
			fx.sparks(c, 0.0 if player.facing > 0 else PI, 0.9, 20, 300.0, 0.5)
			fx.word(c + Vector2(0, -30), "GLUT!", style.color("white"), 26)
			world.fx.shake(4.0 * FxSettings.factor("shake"), player.facing)
			buff_time = float(params.get("buff", 5.0))
			buff_max = buff_time
			buff_bonus = float(params.get("bonus", 0.2))
			_buff_burnout = params.get("burnout", false)
			_buff_params = params.duplicate()
	elif phase == "active" and t >= _f(1):
		_next_phase()
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


# --- Ambosshaltung ----------------------------------------------------------------

func _tick_amboss() -> void:
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
			countering = true
			fx.ring(player.global_position + Vector2(0, -22), 22.0, style.color("orange"), 0.25, 3.0)
	elif phase == "active":
		var c := player.global_position + Vector2(0, -22)
		var pulse := 0.5 + 0.5 * sin(t * 30.0)
		fx.glow(c, Color(GlutFx.heat(0.55), 0.35 + 0.25 * pulse), 22.0, 0.05, Vector2.ZERO, 1.0)
		fx.light(c, Color(1.0, 0.55, 0.3), 0.8 + 0.4 * pulse, 0.45, 0.05)
		if randf() < 0.3:
			fx.sparks(player.global_position + Vector2(randf_range(-10, 10), -2), -PI / 2.0, 0.6, 1, 90.0, 0.3)
		if t >= _f(1):
			countering = false
			_next_phase()
	elif phase == "counter":
		if _step == 0 and t >= 0.08:
			_step = 1
			var r := _front_rect(26, -26, 64, 42)
			_strike(r, float(params.get("counter_damage", 20)), 260.0, "heavy", 120.0, _hit_set)
			var c2 := player.global_position + Vector2(player.facing * 26.0, -24.0)
			fx.cone(c2 - Vector2(player.facing * 10.0, 0), player.facing, 50.0, 0.5, 0.22)
		if t >= 0.3:
			_next_phase()
	elif phase == "recovery" and t >= _f(2) * 0.6:
		_next_phase()


## The player was hit (or a projectile reached him). Returns true when the
## Ambosshaltung caught it.
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
	fx.anvil(c, 24.0, 12)
	fx.ring(c, 30.0, style.color("yellow"), 0.4, 5.0)
	fx.sparks(c, -PI / 2.0, PI, 30, 320.0, 0.7)
	fx.word(c + Vector2(0, -44), "KONTER!", style.color("white"), 28)
	world.fx.flash(0.22 * FxSettings.factor("flash"), Color(1, 0.8, 0.5))
	world.fx.freeze(0.12 * FxSettings.factor("stop"))
	world.fx.shake(6.0 * FxSettings.factor("shake"))
	world.fx.punch(0.06)
	player.add_gauge(15.0)
	if params.get("white", false):
		_set_stage(3)
	if projectile != null and params.get("reflect", false) and projectile.has_method("reflect"):
		projectile.reflect(player)
	elif projectile != null and projectile.has_method("burn"):
		projectile.burn()
	return true


# --- Funkenflug ----------------------------------------------------------------------

func _tick_funkenflug() -> void:
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
			_x_start = player.global_position.x
			fx.anvil(player.global_position + Vector2(-player.facing * 4.0, -20.0), 14.0, 6)
			fx.word(player.global_position + Vector2(0, -50), "FWUMM!", style.color("orange"), 24)
	elif phase == "active" or phase == "back":
		_ghost_t -= get_physics_process_delta_time()
		if _ghost_t <= 0.0:
			_ghost_t = 0.025
			player.world.afterimages.add(player.sprite.snapshot(), Color(1.0, 0.45, 0.15, 0.7) * Color(1.6, 1.6, 1.6, 1.0))
			fx.sparks(player.global_position + Vector2(0, -20), PI if player.facing > 0 else 0.0, 0.5, 3, 160.0, 0.35)
			fx.flame(player.global_position + Vector2(-player.facing * 6.0, -18.0), 7.0, Vector2(-player.facing * 40.0, -30), 0.3)
		fx.light(player.global_position + Vector2(0, -20), Color(1.0, 0.6, 0.3), 1.6, 0.55, 0.05)
		var body := Rect2(player.global_position + Vector2(-16, -46), Vector2(32, 48))
		_strike(body, float(params.get("damage", 12)), 120.0, "heavy", 90.0, _hit_set)
		if t >= _f(1) or player.is_on_wall():
			_leave_trail()
			if phase == "active" and params.get("back", false):
				phase = "back"
				t = 0.0
				_hit_set = {}
				player.facing = -player.facing
				_x_start = player.global_position.x
			else:
				_next_phase()
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


func _leave_trail() -> void:
	var x1 := player.global_position.x
	if absf(x1 - _x_start) < 8.0 or not player.is_on_floor():
		return
	var gy := player.global_position.y
	var h := _hazard("spur", Vector2((x1 + _x_start) * 0.5, gy))
	h.x0 = _x_start
	h.x1 = x1
	h.life = float(params.get("trail", 1.0))
	h.damage = float(params.get("trail_damage", 3))
	h.element = "feuer" if params.get("burn", false) else ""
	world.attacks.add_child(h)


# --- Essensturz --------------------------------------------------------------------

func _tick_essensturz() -> void:
	if phase == "startup":
		if t >= _f(0):
			phase = "fall"
			t = 0.0
			_hit_set = {}
			fx.glow(_blade_mid(), style.color("yellow"), 16.0, 0.2)
	elif phase == "fall":
		_ghost_t -= get_physics_process_delta_time()
		if _ghost_t <= 0.0:
			_ghost_t = 0.03
			player.world.afterimages.add(player.sprite.snapshot(), Color(1.0, 0.5, 0.2, 0.5) * Color(1.6, 1.6, 1.6, 1.0))
			fx.flame(player.global_position + Vector2(player.facing * 10.0, -6.0), 6.0, Vector2(0, -80), 0.25)
		var r := Rect2(player.global_position + Vector2(-16, -20), Vector2(32 + 0.0, 26))
		_strike(r, float(params.get("damage", 12)), 40.0, "heavy", -260.0, _hit_set)
		if player.is_on_floor() and t > 0.02:
			_impact()
			_next_phase()
		elif t > 0.9:
			_next_phase()
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


func _impact() -> void:
	var p := player.global_position
	fx.fountain(p + Vector2(player.facing * 8.0, 0), 34, 340.0)
	fx.anvil(p + Vector2(player.facing * 8.0, -6), 18.0, 9)
	fx.ring(p + Vector2(0, -4), 40.0, style.color("orange"), 0.35, 5.0)
	for i in 6:
		fx.smoke(p + Vector2(randf_range(-20, 20), -6), randf_range(9, 15), Vector2(randf_range(-30, 30), -20), 1.3)
	fx.word(p + Vector2(0, -56), "DONG!", style.color("yellow"), 30)
	world.fx.shake(7.0 * FxSettings.factor("shake"))
	world.fx.punch(0.04)
	world.fx.freeze(0.05 * FxSettings.factor("stop"))
	_spawn_waves(1.0)
	if params.get("aftershock", false):
		_aftershock = 0.4
	var crater: float = params.get("crater", 0.0)
	if crater > 0.0:
		var h := _hazard("krater", p)
		h.life = crater
		h.size = 22.0
		h.damage = 3.0
		world.attacks.add_child(h)


func _spawn_waves(strength: float) -> void:
	var p := player.global_position
	for d in [-1.0, 1.0]:
		var h := _hazard("welle", p + Vector2(d * 6.0, 0))
		h.dir = d
		h.damage = float(params.get("wave_damage", 10)) * strength
		h.life = 1.2
		world.attacks.add_child(h)


# --- movement & pose for the player --------------------------------------------

## Velocity while a Zug runs (the player still applies gravity where asked).
func drive_velocity(v: Vector2, delta: float, on_floor: bool) -> Vector2:
	match zug_id:
		"funkenflug":
			if phase == "active" or phase == "back":
				return Vector2(player.facing * float(params.get("dist", 110)) / _f(1), 0.0)
			return Vector2(move_toward(v.x, 0.0, 2400.0 * delta), minf(v.y + Player.GRAVITY * delta * (0.3 if phase == "startup" else 1.0), Player.MAX_FALL))
		"essensturz":
			if phase == "fall":
				return Vector2(0.0, 760.0)
			if phase == "startup":
				return Vector2(v.x * 0.9, minf(v.y + Player.GRAVITY * 0.8 * delta, 120.0))
		"ambosshaltung":
			return Vector2(0.0, minf(v.y + Player.GRAVITY * delta, Player.MAX_FALL))
	var gx := move_toward(v.x, 0.0, (1800.0 if on_floor else 400.0) * delta)
	var fall := Player.GRAVITY * delta * (0.5 if not on_floor and phase == "active" else 1.0)
	return Vector2(gx, minf(v.y + fall, Player.MAX_FALL))


func pose_frame() -> int:
	if not busy():
		return 0
	if phase == "counter":
		return 3 if t < 0.14 else 4
	if phase == "fall":
		return 4
	if phase == "back":
		return 3
	var pose: Dictionary = style.zug(zug_id).get("pose", {})
	var ph := phase if phase in ["startup", "active", "recovery"] else "active"
	var list: Array = pose.get(ph, [3])
	var dur := _f(["startup", "active", "recovery"].find(ph))
	var k := clampf(t / maxf(0.001, dur), 0.0, 0.999)
	return int(list[int(k * list.size())])
