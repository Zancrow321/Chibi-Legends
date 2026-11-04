class_name FederCaster
extends GlutCaster
## Runs the Züge of the fighting style Spannkraft (Federleib) and owns its
## state. Same interface as GlutCaster; the rules are the style's own:
##  - Spannen: Züge marked "spann" can be held (L). The limb is pulled back
##    and the tension climbs in 3 Stufen (0.2 / 0.45 / 0.75 s): more reach,
##    damage and knockback. Voll gespannt spends 1 Stufe Legendenleiste (if
##    there) for the verstärkte Fassung. Past 1.2 s the Zug snaps off alone.
##    A tensed whiff recovers longer (the limb snaps back, the figure wobbles).
##  - Rückschwung: after a hit, starting a *different* Zug within the window
##    takes the swing along: its startup is 40 % shorter and spannen climbs
##    30 % faster. 3 per sequence (Federringe), the sequence ends 1 s after
##    the last hit or when the figure is hit.
##  - Aus dem Gleichgewicht ("taumel"): voll gespannte hits make the target
##    reel for 3 s (more damage taken, brutes lose their armour). Elites then
##    ignore it for 6 s.
##  - Grenzenlos (Meisterzug C): 8 s free rules (always voll gespannt, no
##    Leiste needed, 5 Übergänge), set by FederSuper through free_time.

const STEPS := [0.2, 0.45, 0.75]
const AUTO_RELEASE := 1.2
const REACH_MUL := [1.0, 1.25, 1.5, 1.8]
const DMG_MUL := [1.0, 1.15, 1.3, 1.5]
const KB_MUL := [1.0, 1.1, 1.25, 1.45]
const WHIFF_FRAMES := [0, 6, 12, 21]
const SNAP_WINDOW := 0.3
const CHAIN_END := 1.0
const MAX_CHAIN := 3
const FREE_CHAIN := 5
const TAUMEL_TIME := 3.0
const TAUMEL_IMMUNE := 6.0
const STEP_NAMES := ["", "I", "II", "VOLL!"]

var ffx: FederFx
var tension := 0          # tension of the running Zug (0..3)
var charge := 0.0         # seconds held so far
var chain_left := MAX_CHAIN
var free_time := 0.0      # Grenzenlos
var free_max := 8.0
var _snap_t := 0.0        # Rückschwung window after a hit
var _chain_t := 0.0       # time since the last Zug hit in this sequence
var _in_chain := false
var _transfer := false    # this Zug took the swing of the last one
var _spring_next := 0     # Federkörper: next Zug starts with this tension
var _last_zug := ""
var _immune: Dictionary = {}
var _missed := true
var _follow := false
var _did_follow := false
var _skin := Color("efb48c")
var _limb_k := 0.0        # 0 = limb at rest, 1 = fully out (per Zug)
var _grab := Vector2.INF
var _counter_mode := ""
var _wob := 0.0


func setup(p: Player, st: FightingStyle) -> void:
	super.setup(p, st)
	GlutIcons.style_id = st.id
	ffx = FederFx.new()
	ffx.room = world
	world.add_child(ffx)
	_skin = _skin_from_look()


func _skin_from_look() -> Color:
	var base := Color("efb48c")
	if player.sprite.use_body and player.sprite.body != null:
		var skins: Array = CreatorCatalog.data.get("skins", [])
		var i := clampi(int(player.sprite.body.look.get("skin", 1)), 0, maxi(0, skins.size() - 1))
		if not skins.is_empty():
			var s: Dictionary = skins[i]
			var c := base
			c.s = clampf(c.s * float(s.get("sat", 1.0)), 0.0, 1.0)
			c.v = clampf(c.v * float(s.get("val", 1.0)), 0.0, 1.0)
			c.h = fposmod(c.h + float(s.get("hue", 0.0)), 1.0)
			return c
	return base


func stage_color() -> Color:
	return style.color("yellow") if tension >= 3 else style.color("coral")


func trail_color() -> Color:
	if free_time > 0.0:
		return style.color("yellow")
	return style.color("coral").lerp(style.color("yellow"), 0.4)


func normal_element() -> String:
	return ""


func normal_mul() -> float:
	return 1.0


func blade_heat() -> float:
	return 0.0


func is_free() -> bool:
	return free_time > 0.0


func max_chain() -> int:
	return FREE_CHAIN if is_free() else MAX_CHAIN


func active() -> bool:
	return busy() or _in_chain or is_free()


# --- casting -------------------------------------------------------------------

func _zug_for(dir: String) -> String:
	var z := style.zug_in(dir)
	if z == "":
		z = style.zug_in("neutral")
	return z


func cast(dir: String) -> bool:
	if player.in_super:
		return false
	var z := _zug_for(dir)
	if z == "" or cooldowns.get(z, 0.0) > 0.0:
		return false
	if busy():
		return false
	# pressed just after the last Zug ended: still takes its swing
	var swing := _snap_t > 0.0 and chain_left > 0 and z != _last_zug
	if swing:
		chain_left -= 1
		_snap_t = 0.0
		ffx.speedlines(_center(), 0.0 if player.facing > 0 else PI, 6, 36.0, style.color("white"))
		ffx.word(_center() + Vector2(-player.facing * 14.0, -40), "SCHWUNG!", style.color("sky"), 16)
	_begin(z, swing)
	return true


## Starts a Zug; `transfer` = it takes the Rückschwung of the last hit.
func _begin(z: String, transfer: bool) -> void:
	zug_id = z
	t = 0.0
	frames = style.frames(z).duplicate()
	enhanced = false
	_decided = false
	params = style.params(z, false)
	_hit_set = {}
	_reported = false
	_step = 0
	_follow = false
	_did_follow = false
	_missed = true
	_grab = Vector2.INF
	_x_start = player.global_position.x
	_y_start = player.global_position.y
	_age = 0.0
	_limb_k = 0.0
	tension = 0
	charge = 0.0
	_transfer = transfer
	var alt_cd = style.alt(z).get("cd", null)
	cooldowns[z] = float(alt_cd) if alt_cd != null else float(style.zug(z).get("cd", 1.0))
	player.move = {}
	if transfer:
		frames[0] = maxi(1, int(round(frames[0] * 0.6)))
	var spann: bool = style.zug(z).get("spann", false)
	if spann:
		phase = "charge"
		if is_free():
			tension = 3
			charge = STEPS[2]
		elif _spring_next > 0:
			tension = _spring_next
			charge = STEPS[_spring_next - 1]
		_spring_next = 0
	else:
		phase = "startup"
	_on_start()


func _decide_enhanced() -> void:
	# only for Züge without Spannen: L held = verstärkt, like everywhere
	_decided = true
	if style.zug(zug_id).get("spann", false):
		return
	if not Input.is_action_pressed("special") or not (player.gauge >= 100.0 or player.infinite_aura or is_free()):
		return
	if not player.infinite_aura and not is_free():
		player.gauge -= 100.0
	_make_enhanced("VERSTÄRKT")


func _make_enhanced(label: String) -> void:
	enhanced = true
	params = style.params(zug_id, true)
	var c := _shoulder()
	ffx.ring(c, 30.0, style.color("yellow"), 0.35, 4.0)
	ffx.burst("stossring", c, 46.0, 0.3, randf() * TAU, false, Color(1, 1, 1, 0.8))
	ffx.word(c + Vector2(-player.facing * 18.0, -40), label, style.color("yellow"), 18, -0.05)
	world.fx.flash(0.12 * FxSettings.factor("flash"), Color(1.0, 0.85, 0.5))


func interrupt() -> void:
	if player.hitstun > 0.0:
		_end_chain()
	zug_id = ""
	phase = ""
	countering = false
	tension = 0


func _end_chain() -> void:
	_in_chain = false
	chain_left = max_chain()
	_snap_t = 0.0
	_last_zug = ""


# --- geometry ---------------------------------------------------------------------

func _shoulder() -> Vector2:
	return player.global_position + Vector2(player.facing * 3.0, -27.0)


func _hip() -> Vector2:
	return player.global_position + Vector2(player.facing * 2.0, -13.0)


func _center() -> Vector2:
	return player.global_position + Vector2(0, -20)


func _fwd(d: float, y := 0.0) -> Vector2:
	return Vector2(player.facing * d, y)


func _rect_front(x0: float, w: float, y_top: float, h: float) -> Rect2:
	var x := player.global_position.x + (x0 if player.facing > 0 else -x0 - w)
	return Rect2(x, player.global_position.y + y_top, w, h)


func reach_mul() -> float:
	return REACH_MUL[tension]


# --- per frame ----------------------------------------------------------------

func tick(delta: float) -> void:
	for z in cooldowns:
		cooldowns[z] = maxf(0.0, cooldowns[z] - delta)
	invuln = maxf(0.0, invuln - delta)
	_wob = maxf(0.0, _wob - delta)
	for id in _immune.keys():
		_immune[id] -= delta
		if _immune[id] <= 0.0:
			_immune.erase(id)
	_tick_free(delta)
	if _snap_t > 0.0:
		_snap_t -= delta
	if _in_chain:
		_chain_t += delta
		if _chain_t > CHAIN_END and not busy():
			_end_chain()
	# Rückschwung: a different Zug pressed right after a hit cancels into it
	if busy() and _snap_t > 0.0 and chain_left > 0 and Input.is_action_just_pressed("special") and not player.in_super:
		var z := _zug_for(_dir_now())
		if z != "" and z != zug_id and cooldowns.get(z, 0.0) <= 0.0:
			_take_swing(z)
			return
	if not busy():
		return
	t += delta
	_age += delta
	if phase != "charge" and not _decided and _age >= 0.15:
		_decide_enhanced()
	if phase != "startup" and phase != "charge" and Input.is_action_just_pressed("special"):
		_follow = true
	if phase == "charge":
		_tick_charge(delta)
		return
	match zug_id:
		"schnappfaust":
			_tick_schnapp()
		"fegebein":
			_tick_fege()
		"katapult":
			_tick_katapult()
		"prallbauch":
			_tick_prall()
		"spannzug":
			_tick_spannzug()
		"fallbeilferse":
			_tick_fallbeil()


func _dir_now() -> String:
	if Input.is_action_pressed("move_up"):
		return "up"
	if Input.is_action_pressed("move_down"):
		return "down"
	if Input.get_axis("move_left", "move_right") != 0.0:
		return "forward"
	return "neutral"


func _take_swing(z: String) -> void:
	chain_left -= 1
	_snap_t = 0.0
	var dx := Input.get_axis("move_left", "move_right")
	if dx != 0.0:
		player.facing = 1 if dx > 0.0 else -1
	var c := _center()
	ffx.ring(c, 26.0, style.color("sky"), 0.3, 3.0)
	ffx.speedlines(c, 0.0 if player.facing > 0 else PI, 6, 36.0, style.color("white"))
	ffx.word(c + Vector2(-player.facing * 14.0, -40), "SCHWUNG!", style.color("sky"), 16)
	Sfx.play("swing_light", 2.0)
	_begin(z, true)


func _tick_free(delta: float) -> void:
	if free_time <= 0.0:
		return
	free_time -= delta
	if randf() < 0.25 and player.sprite.visible:
		var cols := [style.color("yellow"), style.color("sky"), style.color("coral")]
		ffx.motes(_center(), 1, 16.0, cols.pick_random(), 0.6)
	if free_time <= 0.0:
		free_time = 0.0
		_free_finale()


## End of Grenzenlos: a big landing shock all around.
func _free_finale() -> void:
	var p := player.global_position
	ffx.burst("grenzenlos", p + Vector2(0, -24), 150.0, 0.55)
	ffx.burst("stossring", p + Vector2(0, -10), 110.0, 0.4)
	ffx.ring(p + Vector2(0, -8), 90.0, style.color("yellow"), 0.45, 6.0)
	ffx.word(p + Vector2(0, -70), "WUMMS!", style.color("yellow"), 32)
	world.fx.shake(8.0 * FxSettings.factor("shake"))
	world.fx.flash(0.3 * FxSettings.factor("flash"), Color(1.0, 0.9, 0.5))
	Sfx.play("break")
	var tg := GlutHazard.strike(world, Rect2(p.x - 90, p.y - 60, 180, 64), 40.0, p.x, 260.0, "heavy", 240.0, {}, "")
	_end_chain()
	if not tg.is_empty():
		player.add_gauge(10.0)


# --- Spannen ---------------------------------------------------------------------------

func _tick_charge(delta: float) -> void:
	var speed := 1.3 if _transfer else 1.0
	charge += delta * speed
	var held := Input.is_action_pressed("special") and charge < AUTO_RELEASE and not is_free()
	var lvl := 0
	for i in STEPS.size():
		if charge >= STEPS[i]:
			lvl = i + 1
	if lvl > tension:
		tension = lvl
		var c := _shoulder()
		var col := style.color("yellow") if lvl == 3 else style.color("coral")
		ffx.ring(c + _fwd(-10), 14.0 + lvl * 6.0, col, 0.25, 2.0 + lvl)
		ffx.word(c + Vector2(-player.facing * 22.0, -34), STEP_NAMES[lvl], col, 14 + lvl * 3)
		Sfx.play("swing_light", -6.0 + lvl * 3.0)
		if lvl == 3:
			world.fx.flash(0.08 * FxSettings.factor("flash"), Color(1.0, 0.9, 0.5))
	# the limb pulled back and trembling
	var pull := 8.0 + 7.0 * tension + 3.0 * sin(Time.get_ticks_msec() * 0.08) * (tension / 3.0)
	_draw_pulled(pull)
	if randf() < 0.2 * tension:
		ffx.glow(_shoulder() + _fwd(-pull), Color(stage_color(), 0.6), 6.0 + tension * 2.0, 0.15)
	if not held:
		_release()


func _draw_pulled(pull: float) -> void:
	match zug_id:
		"schnappfaust", "katapult":
			ffx.limb(_shoulder(), _shoulder() + _fwd(-pull, 4.0 if zug_id == "schnappfaust" else 14.0), _skin, 4.0, 4.6)
		"fegebein":
			ffx.limb(_hip(), _hip() + _fwd(-pull, 6.0), _skin, 4.4, 4.0)
		"fallbeilferse":
			ffx.limb(_hip(), _hip() + Vector2(player.facing * 4.0, -24.0 - pull), _skin, 4.4, 4.0)


func _release() -> void:
	if is_free():
		tension = 3
	if tension >= 3:
		if is_free() or player.infinite_aura:
			_make_enhanced("VOLL GESPANNT!")
		elif player.gauge >= 100.0:
			player.gauge -= 100.0
			_make_enhanced("VOLL GESPANNT!")
	_decided = true
	phase = "startup"
	t = 0.0
	if tension > 0:
		frames[0] = maxi(1, int(round(frames[0] * 0.5)))
		ffx.speedlines(_shoulder(), 0.0 if player.facing > 0 else PI, 3 + tension * 2, 30.0 + tension * 10.0, style.color("white"))
		Sfx.play("swing_heavy" if tension >= 2 else "swing_light")


func _on_start() -> void:
	match zug_id:
		"fallbeilferse":
			if player.is_on_floor():
				player.velocity.y = -360.0
		"prallbauch":
			frames[1] = int(round(float(params.get("stance", 0.4)) * 60.0))
			_counter_mode = str(params.get("mode", "bounce"))
		"spannzug":
			_find_grab()


# --- hits, Rückschwung, Gleichgewicht -----------------------------------------------

func on_zug_hit(zid: String, targets: Array) -> void:
	if targets.is_empty():
		return
	_missed = false
	player.add_gauge(6.0 if zid == zug_id and not _reported else 1.5)
	if zid == zug_id:
		_reported = true
	_in_chain = true
	_chain_t = 0.0
	_last_zug = zid
	if chain_left > 0:
		_snap_t = SNAP_WINDOW
		var c := _shoulder()
		ffx.glow(c, Color(style.color("sky"), 0.8), 10.0, 0.18)


func on_normal_hit() -> void:
	if _in_chain:
		_chain_t = 0.0


## Damage with tension applied; voll gespannt makes targets reel.
func _hit(rect: Rect2, dmg: float, kb: float, profile := "", launch := 0.0, hit_set = null, from_x := INF) -> Array:
	var out: Array = []
	var fx_x := player.global_position.x if from_x == INF else from_x
	for tg in world.get_tree().get_nodes_in_group("targets"):
		if hit_set != null and hit_set.has(tg.get_instance_id()):
			continue
		if not rect.intersects(tg.get_hurt_rect()):
			continue
		if hit_set != null:
			hit_set[tg.get_instance_id()] = true
		world.deal_hit(tg, dmg * DMG_MUL[tension], "", fx_x, kb * KB_MUL[tension], profile, launch)
		out.append(tg)
	if tension >= 3:
		_taumel(out)
	on_zug_hit(zug_id, out)
	return out


func _taumel(targets: Array) -> void:
	for tg in targets:
		if not is_instance_valid(tg) or not (tg.get("status") is Dictionary):
			continue
		var id: int = tg.get_instance_id()
		if _immune.has(id):
			continue
		var fresh: bool = not tg.status.has("taumel")
		tg.status["taumel"] = TAUMEL_TIME
		if tg.has_method("is_elite") and tg.is_elite():
			_immune[id] = TAUMEL_TIME + TAUMEL_IMMUNE
		var c: Vector2 = tg.get_hurt_rect().get_center()
		ffx.burst("stossring", c, 70.0, 0.35, randf() * TAU)
		if fresh:
			ffx.word(c + Vector2(0, -44), "AUS DEM GLEICHGEWICHT!", style.color("yellow"), 14)
		world.fx.shake(4.0 * FxSettings.factor("shake"), player.facing)
		world.fx.freeze(0.05 * FxSettings.factor("stop"))


func _burst_hit(c: Vector2, id: String, size: float, word := "", rot := 0.0) -> void:
	var big := tension >= 2 or enhanced
	ffx.burst(id, c, size * (1.25 if big else 1.0), 0.32, rot, player.facing < 0)
	if big:
		ffx.burst("stossring", c, size * 0.8, 0.3, randf() * TAU)
	ffx.shards(c, 0.0 if player.facing > 0 else PI, 0.9, 6 + tension * 2, 260.0, style.color("yellow"))
	if word != "":
		ffx.word(c + Vector2(0, -30), word, style.color("white"), 18 + tension * 3)
	world.fx.shake((2.0 + tension * 1.5) * FxSettings.factor("shake"), player.facing)


## Whiff: tensed Züge recover longer, the limb snaps back.
func _whiff_penalty() -> void:
	if _missed and tension > 0:
		frames[2] = int(frames[2]) + WHIFF_FRAMES[tension]
		_wob = 0.3
		ffx.word(_center() + Vector2(0, -40), "BOING", style.color("sky"), 14)


# --- Schnappfaust ------------------------------------------------------------------------

func _tick_schnapp() -> void:
	var kind: String = params.get("kind", "single")
	var reach: float = float(params.get("reach", 76)) * reach_mul()
	var sh := _shoulder()
	if phase == "startup":
		_limb_k = 0.0
		ffx.limb(sh, sh + _fwd(-6.0, 3.0), _skin, 4.0, 4.6)
		if t >= _f(0):
			_next_phase()
			Sfx.play("swing_heavy" if kind == "double" else "swing_light")
	elif phase == "active":
		if kind == "barrage":
			_tick_barrage(reach)
			return
		var out_t := maxf(0.04, _f(1) * 0.55)
		_limb_k = clampf(t / out_t, 0.0, 1.0)
		var tip := sh + _fwd(reach * _limb_k, 2.0)
		var tint := Color(style.color("steel"), 0.45) if kind == "double" and enhanced else Color(0, 0, 0, 0)
		ffx.limb(sh, tip, _skin, 4.0, 5.0 if kind != "double" else 6.0, tint)
		if kind == "double":
			ffx.limb(sh + Vector2(0, 5), tip + Vector2(0, 6), _skin.darkened(0.08), 3.6, 5.5, tint)
		if _step == 0 and _limb_k >= 1.0:
			_step = 1
			var h := 30.0 if kind == "double" else 22.0
			var rect := Rect2(tip.x - (12.0 if player.facing > 0 else 0.0) - 6.0, tip.y - h / 2.0, 30.0, h)
			rect = rect.merge(Rect2(minf(sh.x, tip.x), sh.y - 6, absf(tip.x - sh.x), 12))  # the whole arm hits
			var dmg := float(params.get("damage", 10))
			var tg := _hit(rect, dmg, 220.0 if kind == "double" else 110.0, "heavy" if kind == "double" or tension >= 2 else "light", 0.0, _hit_set)
			ffx.streak("schnappfaust", sh, tip + _fwd(10), 18.0 + tension * 4.0, 0.16)
			if not tg.is_empty():
				_burst_hit(tip + _fwd(8), "schnappfaust" if kind != "double" else "stossring", 56.0 + (20.0 if kind == "double" else 0.0),
					"WUMMS!" if kind == "double" else "SCHNAPP!")
		if t >= _f(1):
			_next_phase()
	elif phase == "recovery":
		if _step == 1:
			_step = 2
			_whiff_penalty()
		var back := clampf(1.0 - t / maxf(0.05, _f(2) * 0.6), 0.0, 1.0)
		var tip2 := sh + _fwd(reach * back, 2.0)
		if back > 0.0:
			ffx.limb(sh, tip2, _skin, 4.0, 5.0)
		# verstärkt: the fist snaps a second time on the way back
		if params.get("double", false) and kind == "single" and _step == 2 and back < 0.5:
			_step = 3
			var r2 := Rect2(minf(sh.x, tip2.x) - 8, sh.y - 12, absf(tip2.x - sh.x) + 16, 24)
			var tg2 := _hit(r2, 7.0, 60.0, "light", 0.0, {}, player.global_position.x + player.facing * (reach + 30.0))
			if not tg2.is_empty():
				_burst_hit(tip2, "schnappfaust", 40.0, "SCHNAPP!")
		if t >= _f(2):
			_next_phase()


func _tick_barrage(reach: float) -> void:
	var sh := _shoulder()
	var n := int(params.get("hits", 8)) + tension * 3
	var dur := _f(1) * (1.0 + 0.4 * tension)
	for i in 3:
		var k := randf()
		var tip := sh + _fwd(reach * (0.5 + 0.5 * k), randf_range(-12, 10))
		ffx.limb(sh + Vector2(0, randf_range(-2, 3)), tip, _skin, 3.2, 4.2)
	if randf() < 0.5:
		ffx.burst("prasselfaust", sh + _fwd(reach * 0.75, -2), 46.0 + tension * 8.0, 0.14, randf_range(-0.3, 0.3), player.facing < 0, Color(1, 1, 1, 0.7), 0.7)
	var due := int(t / maxf(0.01, dur) * n)
	while _step < mini(due, n):
		_step += 1
		var rect := _rect_front(4.0, reach + 12.0, -44.0, 40.0)
		var tg := _hit(rect, float(params.get("damage", 2.2)), 30.0 if _step < n else 160.0, "light" if _step < n else "heavy", 0.0, {})
		if not tg.is_empty():
			Sfx.play("hit_light", -6.0)
			if _step % 3 == 0:
				ffx.word(sh + _fwd(reach * 0.6, -30 + randf_range(-8, 8)), "PRASSEL", style.color("yellow"), 13)
	if t >= dur:
		_step = 1
		_next_phase()


# --- Fegebein ------------------------------------------------------------------------------

func _tick_fege() -> void:
	var kind: String = params.get("kind", "sweep")
	var reach: float = float(params.get("reach", 84)) * reach_mul()
	var hip := _hip()
	if phase == "startup":
		ffx.limb(hip, hip + _fwd(-8.0, 6.0), _skin, 4.4, 4.0)
		if t >= _f(0):
			_next_phase()
			Sfx.play("swing_heavy")
	elif phase == "active":
		var k := clampf(t / _f(1), 0.0, 1.0)
		var foot: Vector2
		if kind == "spear":
			foot = hip + _fwd(reach * minf(1.0, k * 2.0), 2.0)
			ffx.limb(hip + Vector2(0, -3), foot + Vector2(0, -3), _skin, 4.2, 4.4)
			ffx.limb(hip + Vector2(0, 3), foot + Vector2(0, 4), _skin.darkened(0.08), 4.2, 4.4)
		else:
			# the leg swings from high in front down to the floor and through
			var a := lerpf(-0.9, 0.35, k)
			foot = hip + Vector2(cos(a) * player.facing, sin(a)) * reach
			foot.y = minf(foot.y, player.global_position.y - 2.0)
			ffx.limb(hip, foot, _skin, 4.6, 4.4)
		if _step == 0 and k >= (0.5 if kind == "spear" else 0.35):
			_step = 1
			var rect := _rect_front(0.0, reach + 10.0, -34.0 if kind != "spear" else -22.0, 36.0 if kind != "spear" else 18.0)
			var from_x := INF
			if params.get("pull", false):
				from_x = player.global_position.x + player.facing * (reach * 0.5 + 40.0)
			var tg := _hit(rect, float(params.get("damage", 11)), 70.0 if params.get("pull", false) else 150.0, "heavy", 0.0, _hit_set, from_x)
			var mid := hip + _fwd(reach * 0.6, -4)
			ffx.burst("fegebein", mid, reach * 1.2, 0.3, 0.0, player.facing < 0)
			ffx.speedlines(mid, 0.0 if player.facing > 0 else PI, 5, 34.0, style.color("sky"))
			if not tg.is_empty():
				_burst_hit(tg[0].get_hurt_rect().get_center(), "stossring", 44.0, "WUSCH!")
		# verstärkt: a second sweep back that knocks down
		if params.get("twice", false) and _step == 1 and k >= 0.95:
			_step = 2
			var rect2 := _rect_front(0.0, reach + 10.0, -30.0, 32.0)
			ffx.burst("fegebein", hip + _fwd(reach * 0.55, -2), reach * 1.25, 0.3, PI, player.facing > 0, Color(1, 1, 1, 0.9))
			var tg2 := _hit(rect2, 8.0, 60.0, "heavy", 260.0, {})
			if not tg2.is_empty():
				_burst_hit(tg2[0].get_hurt_rect().get_center(), "stossring", 50.0, "UMGEFEGT!")
		if t >= _f(1):
			_next_phase()
	elif phase == "recovery":
		if _step >= 1 and _step < 9:
			_step = 9
			_whiff_penalty()
		var back := clampf(1.0 - t / maxf(0.05, _f(2) * 0.5), 0.0, 1.0)
		if back > 0.0:
			ffx.limb(hip, hip + _fwd(reach * 0.9 * back, 6.0), _skin, 4.4, 4.0)
		if t >= _f(2):
			_next_phase()


# --- Katapult ----------------------------------------------------------------------------------

func _tick_katapult() -> void:
	var hook: bool = params.get("hook", false)
	var sh := _shoulder()
	if phase == "startup":
		if hook:
			ffx.limb(sh, sh + _fwd(4.0, 10.0), _skin, 4.0, 4.6)
		else:
			# grabs the floor behind and stretches
			ffx.limb(sh, player.global_position + _fwd(-18.0 - 6.0 * tension, 0.0), _skin, 4.0, 4.4)
		if t >= _f(0):
			_next_phase()
			Sfx.play("swing_heavy")
			if not hook:
				var vx := float(params.get("vx", 260)) * (1.0 + 0.15 * tension)
				var vy := float(params.get("vy", -520)) * (1.0 + 0.12 * tension)
				player.velocity = Vector2(player.facing * vx, vy)
				ffx.burst("katapult", player.global_position + _fwd(-6, -18), 70.0 + tension * 12.0, 0.35, -PI / 4.0 if player.facing > 0 else PI / 4.0, player.facing < 0)
				ffx.ring(player.global_position + Vector2(0, -4), 22.0, style.color("sky"), 0.3, 3.0)
				ffx.word(player.global_position + Vector2(0, -50), "BOING!", style.color("sky"), 20)
	elif phase == "active":
		var launch := float(params.get("launch", 360)) * (1.0 + 0.1 * tension)
		if hook:
			var k := clampf(t / (_f(1) * 0.5), 0.0, 1.0)
			var reach := 80.0 * reach_mul()
			var tip := sh + Vector2(player.facing * 6.0, -reach * k)
			ffx.limb(sh, tip, _skin, 4.2, 5.2)
			if _step == 0 and k >= 1.0:
				_step = 1
				var rect := Rect2(tip.x - 18, tip.y - 6, 36, reach + 6)
				var tg := _hit(rect, float(params.get("damage", 14)), 60.0, "heavy", launch, _hit_set)
				ffx.burst("katapult", tip + Vector2(0, 20), 70.0, 0.3, -PI / 2.0)
				if not tg.is_empty():
					_burst_hit(tip, "stossring", 52.0, "HIMMELSHAKEN!")
		else:
			ffx.limb(sh, sh + Vector2(player.facing * 14.0, -20.0), _skin, 4.2, 5.0)
			if randf() < 0.6:
				player.world.afterimages.add(player.sprite.snapshot(), Color(1.6, 1.1, 0.6, 0.45))
			var rect := Rect2(player.global_position.x - 16 + player.facing * 10.0, player.global_position.y - 52, 32, 56)
			var tg := _hit(rect, float(params.get("damage", 10)), 40.0, "heavy", launch, _hit_set)
			if not tg.is_empty() and _step == 0:
				_step = 1
				_burst_hit(tg[0].get_hurt_rect().get_center(), "katapult", 60.0, "WUMMS!", -PI / 4.0)
			# verstärkt: a finisher at the top of the flight
			if params.get("finisher", false) and _step < 2 and player.velocity.y >= -40.0:
				_step = 2
				var top := sh + _fwd(46.0, -10.0)
				ffx.limb(sh, top, _skin, 4.4, 5.6)
				var tg2 := _hit(Rect2(top.x - 26, top.y - 30, 52, 50), 9.0, 80.0, "heavy", 300.0, {})
				ffx.burst("stossring", top, 64.0, 0.3)
				if not tg2.is_empty():
					ffx.word(top + Vector2(0, -26), "NOCH HÖHER!", style.color("yellow"), 18)
		if t >= _f(1):
			_next_phase()
	elif phase == "recovery":
		if _step < 9:
			_step = 9
			_whiff_penalty()
		if t >= _f(2):
			_next_phase()


# --- Prallbauch --------------------------------------------------------------------------------

func _tick_prall() -> void:
	var c := _center() + Vector2(0, 2)
	if phase == "startup":
		ffx.ball(c, lerpf(8.0, 18.0, clampf(t / _f(0), 0.0, 1.0)), _skin)
		if t >= _f(0):
			_next_phase()
			countering = true
			Sfx.play("land", 4.0)
			ffx.word(c + Vector2(0, -36), "PLOPP", style.color("sky"), 14)
	elif phase == "active":
		var perfect: float = float(params.get("perfect", 0.15))
		countering = t <= float(params.get("stance", 0.4))
		var pulse := 1.0 + 0.06 * sin(t * 30.0)
		if _counter_mode == "guard":
			ffx.limb(_shoulder(), _shoulder() + _fwd(10, 6), _skin, 5.0, 5.0, Color(style.color("steel"), 0.6))
			ffx.glow(_shoulder() + _fwd(10, 6), Color(style.color("steel"), 0.4), 16.0, 0.05)
		else:
			ffx.ball(c, 19.0 * pulse, _skin)
			if t <= perfect:
				ffx.glow(c, Color(style.color("sky"), 0.25), 26.0, 0.05)
		if t >= _f(1):
			countering = false
			_next_phase()
	elif phase == "counter":
		if _counter_mode != "guard":
			ffx.ball(c, lerpf(24.0, 10.0, clampf(t / 0.2, 0.0, 1.0)), _skin)
		if t >= 0.28:
			_next_phase()
	elif phase == "recovery":
		if _counter_mode != "guard":
			ffx.ball(c, lerpf(14.0, 6.0, clampf(t / maxf(0.05, _f(2)), 0.0, 1.0)), _skin)
		if t >= _f(2) * 0.8:
			_next_phase()


func try_counter(from_x: float, projectile: Node = null) -> bool:
	if zug_id != "prallbauch" or phase != "active":
		return false
	var c := _center()
	var perfect := t <= float(params.get("perfect", 0.15))
	if _counter_mode == "guard":
		# Willensdeckung: holds everything, no counter
		invuln = 0.25
		ffx.burst("eisenwille", _shoulder() + _fwd(12, 4), 70.0, 0.3)
		ffx.word(c + Vector2(0, -40), "EISENWILLE", style.color("steel"), 16)
		world.fx.freeze(0.05 * FxSettings.factor("stop"))
		Sfx.play("block")
		if projectile != null and projectile.has_method("burn"):
			projectile.burn()
		return true
	var sharp: bool = projectile != null and projectile.get("sharp") == true
	if sharp:
		return false  # blades and special energy go through the belly
	countering = false
	invuln = 0.4
	phase = "counter"
	t = 0.0
	_hit_set = {}
	player.facing = 1 if from_x >= player.global_position.x else -1
	ffx.burst("prallbauch", c, 90.0, 0.35)
	ffx.ring(c, 40.0, style.color("sky"), 0.35, 4.0)
	ffx.word(c + Vector2(0, -46), "BOING!", style.color("white"), 28)
	world.fx.flash(0.15 * FxSettings.factor("flash"), Color(0.75, 0.9, 1.0))
	world.fx.freeze(0.08 * FxSettings.factor("stop"))
	world.fx.shake(4.0 * FxSettings.factor("shake"))
	Sfx.play("land", 6.0)
	player.add_gauge(12.0)
	if projectile != null and projectile.has_method("burn"):
		if _counter_mode == "reflect" and perfect and projectile.has_method("reflect"):
			projectile.reflect()
		else:
			projectile.burn()
	var dmg: float = float(params.get("counter_damage", 8))
	if _counter_mode == "spring":
		player.velocity = Vector2(-player.facing * 220.0, -260.0)
		_spring_next = 2
		ffx.word(c + Vector2(0, -64), "SPANNUNG II", style.color("coral"), 14)
	if dmg > 0.0:
		var rect := Rect2(c.x - 40, c.y - 30, 80, 60)
		var tg := _hit(rect, dmg * (1.6 if perfect else 1.0), 260.0, "heavy", 60.0, _hit_set)
		if params.get("wave", false):
			ffx.burst("stossring", c, 130.0, 0.4)
			GlutHazard.strike(world, Rect2(c.x - 70, c.y - 40, 140, 80), 6.0, c.x, 200.0, "heavy", 0.0, _hit_set, "")
		if not tg.is_empty():
			ffx.word(c + Vector2(0, -64), "ZURÜCK!", style.color("yellow"), 18)
	return true


# --- Spannzug -----------------------------------------------------------------------------------

func _find_grab() -> void:
	var rng: float = float(params.get("grab", 170))
	_grab = Vector2.INF
	if rng <= 0.0:
		return
	var best := rng
	for tg in world.get_tree().get_nodes_in_group("targets"):
		var c: Vector2 = tg.get_hurt_rect().get_center()
		var dx: float = (c.x - player.global_position.x) * player.facing
		if dx > 10.0 and dx < best and absf(c.y - player.global_position.y + 20.0) < 70.0:
			best = dx
			_grab = c


func _tick_spannzug() -> void:
	var sh := _shoulder()
	var steam: bool = params.get("steam", false)
	if phase == "startup":
		if steam:
			ffx.steam(_center(), 2, 8.0)
		elif _grab != Vector2.INF:
			var k := clampf(t / _f(0), 0.0, 1.0)
			ffx.limb(sh, sh.lerp(_grab, k), _skin, 3.8, 4.6)
		else:
			ffx.limb(sh, player.global_position + _fwd(-10, 0), _skin, 3.8, 4.2)
		if t >= _f(0):
			_next_phase()
			_x_start = player.global_position.x
			Sfx.play("dash")
			if steam:
				ffx.steam(_center(), 6, 12.0)
				ffx.burst("dampfhagel", _center() + _fwd(-14), 60.0, 0.35, 0.0, player.facing < 0, Color(1, 1, 1, 0.7))
				ffx.word(_center() + Vector2(0, -40), "ZISCH!", style.color("steam"), 16)
			elif _grab != Vector2.INF:
				ffx.word(_grab + Vector2(0, -30), "SCHNAPP!", style.color("coral"), 16)
				ffx.burst("spannzug", sh.lerp(_grab, 0.5), 70.0, 0.3, 0.0, player.facing < 0)
			else:
				player.velocity.y = -260.0
				ffx.burst("katapult", player.global_position + Vector2(0, -8), 46.0, 0.3, -PI / 2.0)
	elif phase == "active":
		if _grab != Vector2.INF and not steam:
			ffx.limb(sh, _grab, _skin, 3.6, 4.6)
		if steam:
			ffx.steam(_center() + _fwd(-10), 1, 6.0)
		_ghost_t -= get_physics_process_delta_time()
		if _ghost_t <= 0.0:
			_ghost_t = 0.035
			player.world.afterimages.add(player.sprite.snapshot(), Color(1.6, 1.0, 0.6, 0.5) if not steam else Color(1.6, 1.6, 1.6, 0.5))
		ffx.speedlines(_center(), PI if player.facing > 0 else 0.0, 1, 30.0, style.color("white"), 0.12)
		if _follow and not _did_follow:
			_fly_punch()
		var arrived: bool = _grab != Vector2.INF and absf(player.global_position.x - _grab.x) < 18.0 and not params.get("swing", false)
		if t >= _f(1) or player.is_on_wall() or arrived:
			if params.get("swing", false) and _grab != Vector2.INF:
				player.facing = -player.facing
			if params.get("bounce", false) and _grab != Vector2.INF:
				player.velocity = Vector2(-player.facing * 160.0, -280.0)
				_spring_next = 2
				ffx.word(_center() + Vector2(0, -40), "PRALL!", style.color("sky"), 16)
			if not _did_follow and (_grab != Vector2.INF or steam):
				_fly_punch()
			_next_phase()
	elif phase == "recovery":
		if t >= _f(2):
			_next_phase()


func _fly_punch() -> void:
	_did_follow = true
	_follow = false
	var sh := _shoulder()
	var tip := sh + _fwd(44.0, 2.0)
	ffx.limb(sh, tip, _skin, 4.2, 5.4)
	var tg := _hit(_rect_front(0.0, 56.0, -44.0, 44.0), float(params.get("damage", 9)), 150.0, "heavy", 0.0, _hit_set)
	if not tg.is_empty():
		_burst_hit(tip, "schnappfaust", 50.0, "WUMMS!")


# --- Fallbeilferse ------------------------------------------------------------------------------

func _tick_fallbeil() -> void:
	var kind: String = params.get("kind", "axe")
	var hip := _hip()
	if phase == "startup":
		var lift := 26.0 + 10.0 * tension
		ffx.limb(hip, hip + Vector2(player.facing * 6.0, -lift - 10.0), _skin, 4.6, 4.4)
		if kind == "spin" and randf() < 0.5:
			ffx.speedlines(_center(), randf() * TAU, 1, 24.0, style.color("sky"), 0.12)
		if t >= _f(0):
			phase = "fall"
			t = 0.0
			_hit_set = {}
			Sfx.play("swing_heavy")
	elif phase == "fall":
		_ghost_t -= get_physics_process_delta_time()
		if _ghost_t <= 0.0:
			_ghost_t = 0.035
			player.world.afterimages.add(player.sprite.snapshot(), Color(1.6, 1.2, 0.6, 0.45))
		var foot := hip + _fwd(16.0, 10.0)
		ffx.limb(hip, foot, _skin, 4.6, 4.6)
		if kind == "stomp":
			ffx.limb(hip + _fwd(-3, 0), foot + _fwd(-6, 2), _skin.darkened(0.08), 4.4, 4.6)
		if kind == "spin":
			if fmod(t, 0.1) < get_physics_process_delta_time():
				_hit_set = {}
				ffx.burst("fegebein", _center(), 70.0, 0.15, randf() * TAU, randf() < 0.5, Color(1, 1, 1, 0.7))
			var r0 := Rect2(player.global_position.x - 34, player.global_position.y - 44, 68, 48)
			_hit(r0, float(params.get("damage", 4)), 60.0, "light", 0.0, _hit_set)
		if player.is_on_floor() and t > 0.02:
			_land()
			_next_phase()
			if _missed:
				frames[2] = int(frames[2]) + 6 + WHIFF_FRAMES[tension]  # the foot sticks in the floor
				ffx.word(_center() + Vector2(0, -40), "STECKT!", style.color("sky"), 14)
		elif t > 1.0:
			_next_phase()
	elif phase == "recovery":
		if t < 0.12:
			ffx.limb(hip, player.global_position + _fwd(18.0, 0.0), _skin, 4.6, 4.6)
		if t >= _f(2):
			_next_phase()


func _land() -> void:
	var kind: String = params.get("kind", "axe")
	var p := player.global_position
	var foot := p + _fwd(18.0, 0.0)
	var w := 46.0 if kind == "stomp" else (90.0 if kind == "spin" else 66.0)
	var dmg := float(params.get("damage", 15)) * (0.6 if kind == "spin" else 1.0)
	var tg := _hit(Rect2(foot.x - w / 2.0, p.y - 40, w, 44), dmg, 200.0, "heavy", 120.0 if params.get("toss", false) else 0.0, _hit_set)
	var size := 90.0 + 16.0 * tension
	ffx.burst("fallbeil", foot + Vector2(0, -size * 0.38), size, 0.4)
	ffx.burst("stossring", foot + Vector2(0, -6), size * 0.7, 0.3)
	ffx.ring(foot + Vector2(0, -2), 40.0 + tension * 8.0, style.color("yellow"), 0.3, 4.0)
	ffx.shards(foot, -PI / 2.0, 1.2, 12, 260.0, style.color("yellow"))
	ffx.word(p + Vector2(0, -60), "WUMMS!", style.color("white"), 24 + tension * 3)
	world.fx.shake((5.0 + tension) * FxSettings.factor("shake"))
	world.fx.punch(0.03)
	Sfx.play("break" if tension >= 2 or enhanced else "land", 4.0)
	if params.get("toss", false):
		# verstärkt: small enemies to both sides fly up
		for d in [-1.0, 1.0]:
			var r := Rect2(foot.x + (0.0 if d > 0 else -110.0), p.y - 30, 110, 32)
			GlutHazard.strike(world, r, 5.0, foot.x, 120.0, "heavy", 300.0, _hit_set, "")
	if not tg.is_empty():
		player.add_gauge(2.0)


# --- movement & pose for the player --------------------------------------------

func drive_velocity(v: Vector2, delta: float, on_floor: bool) -> Vector2:
	var g := minf(v.y + Player.GRAVITY * delta, Player.MAX_FALL)
	if phase == "charge":
		var dx := Input.get_axis("move_left", "move_right")
		if dx != 0.0 and on_floor:
			player.facing = 1 if dx > 0.0 else -1
		return Vector2(dx * Player.RUN_SPEED * 0.4 if on_floor else v.x * 0.95, minf(v.y + Player.GRAVITY * 0.6 * delta, Player.MAX_FALL))
	match zug_id:
		"katapult":
			if phase == "active" and not params.get("hook", false):
				return Vector2(v.x, minf(v.y + Player.GRAVITY * 0.85 * delta, Player.MAX_FALL))
		"spannzug":
			if phase == "active":
				var steam: bool = params.get("steam", false)
				var dist: float = float(params.get("dist", 70))
				if _grab != Vector2.INF and not steam:
					var to := _grab.x - player.global_position.x
					if params.get("swing", false):
						var arc := sin(clampf(t / _f(1), 0.0, 1.0) * PI)
						return Vector2(player.facing * (absf(to) + 70.0) / maxf(0.05, _f(1)) * 1.2, -180.0 * arc)
					return Vector2(signf(to) * maxf(380.0, absf(to) / maxf(0.05, _f(1))), -40.0)
				return Vector2(player.facing * dist / maxf(0.05, _f(1)) * (1.0 if steam else 1.0), g if not steam else 0.0)
		"fallbeilferse":
			if phase == "fall":
				var kind: String = params.get("kind", "axe")
				return Vector2(player.facing * (60.0 if kind == "spin" else 30.0), float(params.get("fall", 760)))
			if phase == "startup":
				return Vector2(v.x * 0.9, minf(v.y + Player.GRAVITY * 0.7 * delta, 140.0))
		"prallbauch":
			if phase == "counter" and _counter_mode == "spring":
				return Vector2(v.x, g)
			return Vector2(0.0, g)
	if _wob > 0.0:
		return Vector2(sin(_wob * 60.0) * 30.0, g)
	return super.drive_velocity(v, delta, on_floor)


func pose_frame() -> int:
	if phase == "charge":
		return 1
	return super.pose_frame()
