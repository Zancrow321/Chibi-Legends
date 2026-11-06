class_name WirbelCaster
extends GlutCaster
## Runs the Züge of the fighting style Wirbelwille and owns its state. Same
## interface as GlutCaster; the rules are the style's own:
##  - Teamwork-Marken: each *different* Zug that hits gives 1 mark (max 3).
##    After 6 s without a hit they drop by one every 2 s.
##  - Windschatten: verstärkte Züge marked "klon" (L held) spend 1 mark and
##    a wind clone joins with an extra attack. At most 2 clones; they vanish
##    after their attack, when an enemy hits them, or after 3 s. Clone hits
##    do 50 % damage and extend a stun at most once per combo.
##  - Winddruck: verstärkte Windzüge ("wind") put "winddruck" on the target
##    for 3 s: +40 % Haltungsschaden. Elites ignore it for 6 s afterwards.
##  - Wind + Feuerfläche: a wind hit makes a burning surface (Glutatem's
##    trail or crater) 50 % wider, once per surface, no chain reaction.
##  - Orkanmantel (Meisterzug C, WirbelSuper): 8 s storm cloak, set via
##    mantle_time: more reach, no clones, a wind burst at the end.

const MAX_MARKS := 3
const MAX_CLONES := 2
const MARK_IDLE := 6.0
const MARK_DROP := 2.0
const CLONE_DMG := 0.5
const CLONE_STUN_EXTRA := 0.3
const COMBO_GAP := 1.2
const WIND_TIME := 3.0
const WIND_IMMUNE := 6.0
const WIND_POSTURE := 1.4
const MANTLE_REACH := 1.6
const MANTLE_ZUEGE := ["wirbelansturm", "kreiselfaust", "wirbelsturz"]

var wfx: WirbelFx
var marks := 0
var clones: Array = []
var mantle_time := 0.0
var mantle_max := 8.0

var _mark_idle := 0.0
var _last_mark_zug := ""
var _combo_gap := 0.0
var _clone_stun_used := false
var _clone_mark := false     # this activation spent a mark for a clone
var _immune: Dictionary = {}
var _missed := true
var _follow := false
var _did_follow := false
var _pose := "idle"
var _fist_t := 0.0
var _target = null
var _guard_t := 0.0          # Fadenwehr / early guard: damage cut left
var _guard_cut := 0.0


func setup(p: Player, st: FightingStyle) -> void:
	super.setup(p, st)
	GlutIcons.style_id = st.id
	wfx = WirbelFx.new()
	wfx.room = world
	world.add_child(wfx)


func stage_color() -> Color:
	return style.color("gold") if marks >= MAX_MARKS else style.color("turq")


func trail_color() -> Color:
	return style.color("gold") if mantle_time > 0.0 else style.color("ice")


func normal_element() -> String:
	return "wind" if mantle_time > 0.0 else ""


func normal_mul() -> float:
	return 1.15 if mantle_time > 0.0 else 1.0


func blade_heat() -> float:
	return 0.0


func reset_fight() -> void:
	marks = 0
	for c in clones.duplicate():
		if is_instance_valid(c):
			c.vanish()
	clones.clear()


const STATE_POSE := {"jump": "jump_0", "fall": "fall_0", "dash": "dash_0", "idle": "idle_0"}


## Creator pose for the figure while a Zug runs (Player asks every frame).
func creator_pose() -> String:
	if not busy():
		return ""
	return STATE_POSE.get(_pose, _pose)


func _c(k: String) -> Color:
	return style.color(k)


# --- geometry ---------------------------------------------------------------------

func _center() -> Vector2:
	return player.global_position + Vector2(0, -20)


func _fist() -> Vector2:
	return player.global_position + Vector2(player.facing * 12.0, -22.0)


func _fwd(d: float, y := 0.0) -> Vector2:
	return Vector2(player.facing * d, y)


func _rect_front(x0: float, w: float, y_top: float, h: float) -> Rect2:
	var x := player.global_position.x + (x0 if player.facing > 0 else -x0 - w)
	return Rect2(x, player.global_position.y + y_top, w, h)


func _reach() -> float:
	return MANTLE_REACH if mantle_time > 0.0 and zug_id in MANTLE_ZUEGE else 1.0


func _targets() -> Array:
	return world.get_tree().get_nodes_in_group("targets")


## Nearest target in front (or anywhere when `any`) within `max_d`.
func _nearest(max_d: float, any := false) -> Node2D:
	var best: Node2D = null
	var best_d := max_d
	for tg in _targets():
		var dx: float = tg.global_position.x - player.global_position.x
		if not any and dx * player.facing < -8.0:
			continue
		var d: float = absf(dx) + absf(tg.global_position.y - player.global_position.y) * 0.5
		if d < best_d:
			best = tg
			best_d = d
	return best


# --- casting -------------------------------------------------------------------

func cast(dir: String) -> bool:
	if player.in_super or busy():
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
	_clone_mark = false
	params = style.params(z, false)
	_hit_set = {}
	_reported = false
	_step = 0
	_follow = false
	_did_follow = false
	_missed = true
	_x_start = player.global_position.x
	_y_start = player.global_position.y
	_age = 0.0
	_fist_t = 0.0
	_target = null
	var alt_cd = style.alt(z).get("cd", null)
	cooldowns[z] = style.cooldown(z, alt_cd)
	player.move = {}
	wfx.gust(_center(), PI if player.facing > 0 else 0.0, 3, 24.0)
	_on_start()
	return true


func _decide_enhanced() -> void:
	_decided = true
	if not player.ctl.is_action_pressed("special") or not (player.gauge >= 100.0 or player.infinite_aura):
		return
	if not player.infinite_aura:
		player.gauge -= 100.0
	enhanced = true
	params = style.params(zug_id, true)
	var c := _center()
	wfx.ring(c, 30.0, _c("gold"), 0.35, 4.0)
	wfx.anim("windschatten_entstehen", c, 60.0, -1.0, 0.0, false, Color(1, 1, 1, 0.7), 2.0)
	wfx.word(c + Vector2(-player.facing * 18.0, -44), "VERSTÄRKT", _c("gold"), 16, -0.05)
	world.fx.flash(0.12 * FxSettings.factor("flash"), Color(0.7, 1.0, 1.0))
	if style.zug(zug_id).get("klon", false) and marks > 0 and mantle_time <= 0.0:
		marks -= 1
		_clone_mark = true
		wfx.word(c + Vector2(player.facing * 22.0, -60), "GEMEINSAM!", _c("ice"), 18)
		Sfx.play("swing_light", 2.0)
	_on_enhanced()


func interrupt() -> void:
	zug_id = ""
	phase = ""
	countering = false
	_guard_t = 0.0


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


func _on_start() -> void:
	match zug_id:
		"wirbelansturm":
			_pose = "jab_wind"
		"kreiselfaust":
			_pose = "charge_0"
			Sfx.play("swing_light", -4.0)
		"klon_aufsteiger":
			_pose = "cast_wind"
			_target = _nearest(110.0)
		"wechselhuelle":
			_pose = "block_0"
			frames[1] = int(round(float(params.get("stance", 0.4)) * 60.0))
		"klonschleuder":
			_pose = "cast_wind"
			_spawn_thrower()
		"wirbelsturz":
			_pose = "charge_0"
			if player.is_on_floor():
				player.velocity.y = -380.0


func _on_enhanced() -> void:
	match zug_id:
		"kreiselfaust":
			if _clone_mark and params.get("hold_clone", false) and not params.get("handover", false):
				_spawn_holder()


func _on_active() -> void:
	match zug_id:
		"wechselhuelle":
			countering = str(params.get("mode", "swap")) != "net"
			_guard_t = 0.0
			if str(params.get("mode", "")) == "net":
				_guard_t = _f(1)
				_guard_cut = 0.7
				wfx.anim("fadenwehr", _center() + _fwd(14), 64.0, _f(1) + 0.1, 0.0, false, Color(1, 1, 1, 0.9), 1.4)
			wfx.ring(_center(), 22.0, _c("turq"), 0.25, 3.0)


func _on_recovery() -> void:
	if zug_id == "wechselhuelle":
		countering = false
		_guard_t = 0.0


# --- per frame ----------------------------------------------------------------

func tick(delta: float) -> void:
	for z in cooldowns:
		cooldowns[z] = maxf(0.0, cooldowns[z] - delta)
	invuln = maxf(0.0, invuln - delta)
	_guard_t = maxf(0.0, _guard_t - delta)
	for id in _immune.keys():
		_immune[id] -= delta
		if _immune[id] <= 0.0:
			_immune.erase(id)
	clones = clones.filter(func(c): return is_instance_valid(c) and not c.gone)
	_tick_marks(delta)
	_tick_mantle(delta)
	if not busy():
		return
	t += delta
	_age += delta
	if not _decided and _age >= 0.12:
		_decide_enhanced()
	if phase != "startup" and player.ctl.is_action_just_pressed("special"):
		_follow = true
	match zug_id:
		"wirbelansturm":
			_tick_ansturm()
		"kreiselfaust":
			_tick_kreisel()
		"klon_aufsteiger":
			_tick_aufsteiger()
		"wechselhuelle":
			_tick_huelle()
		"klonschleuder":
			_tick_schleuder()
		"wirbelsturz":
			_tick_sturz()


func _tick_marks(delta: float) -> void:
	_combo_gap += delta
	if _combo_gap > COMBO_GAP:
		_clone_stun_used = false
	if marks <= 0:
		_mark_idle = 0.0
		return
	_mark_idle += delta
	if _mark_idle >= MARK_IDLE + MARK_DROP:
		_mark_idle = MARK_IDLE
		marks -= 1
		if marks == 0:
			_last_mark_zug = ""


func _tick_mantle(delta: float) -> void:
	if mantle_time <= 0.0:
		return
	mantle_time -= delta
	var c := _center()
	var k := Time.get_ticks_msec() * 0.001
	wfx.hold("orkanmantel", c + Vector2(0, -6), 78.0, k, 0.0, player.facing < 0, Color(1, 1, 1, 0.85))
	# two storm arms: bundled wind strands from the shoulders
	for side: float in [-1.0, 1.0]:
		var sh := player.global_position + Vector2(side * 6.0, -30.0)
		var reach := 26.0 + 8.0 * sin(k * 5.0 + side)
		var tip := sh + Vector2(player.facing * reach, 4.0 + side * 6.0)
		if busy() and phase == "active":
			tip = sh + Vector2(player.facing * reach * 1.8, side * 4.0)
		var mid := sh.lerp(tip, 0.5) + Vector2(0, -8.0 - 4.0 * sin(k * 7.0 + side))
		for i in 3:
			var o := Vector2(0, (i - 1) * 2.0)
			wfx.thread(sh + o, mid + o, _c("storm"), 2.4)
			wfx.thread(mid + o, tip + o, _c("ice"), 1.8)
		if randf() < 0.3:
			wfx.glow(tip, Color(_c("gold"), 0.6), 6.0, 0.15)
	if randf() < 0.25:
		wfx.motes(c, 1, 16.0, _c("gold"), 0.5)
	fx.light(c, Color(0.6, 1.0, 1.0), 1.4, 0.6, 0.05)
	if mantle_time <= 0.0:
		mantle_time = 0.0
		_mantle_end()


## End of the Orkanmantel: the storm bursts around the figure.
func _mantle_end() -> void:
	var p := player.global_position + Vector2(0, -22)
	wfx.anim("orkanmantel_ausbruch", p, 200.0)
	wfx.ring(p, 90.0, _c("ice"), 0.45, 6.0)
	wfx.word(p + Vector2(0, -60), "WUUSCH!", _c("gold"), 30)
	world.fx.shake(8.0 * FxSettings.factor("shake"))
	world.fx.flash(0.3 * FxSettings.factor("flash"), Color(0.8, 1.0, 1.0))
	Sfx.play("break")
	for tg in _targets():
		if tg.get_hurt_rect().get_center().distance_to(p) < 92.0:
			world.deal_hit(tg, 28.0, "wind", p.x, 300.0, "heavy", 160.0)
			_posture(tg, 20.0)
			player.add_gauge(2.0)


# --- hits, marks, Winddruck ---------------------------------------------------------

## The figure's own Zug hit: gauge, marks (different Züge only).
func on_zug_hit(zid: String, targets: Array) -> void:
	if targets.is_empty():
		return
	_missed = false
	_combo_gap = 0.0
	_mark_idle = 0.0
	if zid == zug_id and _reported:
		return
	if zid == zug_id:
		_reported = true
	player.add_gauge(6.0)
	if zid != _last_mark_zug and marks < MAX_MARKS:
		marks += 1
		_last_mark_zug = zid
		var c := player.global_position + Vector2(-12 + marks * 8, -56)
		wfx.ring(c, 10.0, stage_color(), 0.3, 2.0)
		wfx.glow(c, Color(stage_color(), 0.8), 8.0, 0.3)
		if marks == MAX_MARKS:
			wfx.word(c + Vector2(0, -12), "BEREIT!", _c("gold"), 16)
	elif zid != _last_mark_zug:
		_last_mark_zug = zid


func on_kunai_hit(targets: Array) -> void:
	on_zug_hit(zug_id, targets)


func on_normal_hit() -> void:
	_combo_gap = 0.0
	if marks > 0:
		_mark_idle = 0.0


## Damage of the figure. Wind hits grow fire surfaces; verstärkte Windzüge
## put Winddruck on the target.
func _hit(rect: Rect2, dmg: float, kb: float, profile := "", launch := 0.0, hit_set = null, element := "", posture := 0.0) -> Array:
	var out: Array = []
	for tg in _targets():
		if hit_set != null and hit_set.has(tg.get_instance_id()):
			continue
		if not rect.intersects(tg.get_hurt_rect()):
			continue
		if hit_set != null:
			hit_set[tg.get_instance_id()] = true
		world.deal_hit(tg, dmg, element, player.global_position.x, kb, profile, launch)
		out.append(tg)
		if posture > 0.0:
			_posture(tg, posture)
	if element == "wind":
		_grow_fire(rect)
		if enhanced and style.zug(zug_id).get("wind", false):
			_winddruck(out, dmg)
	on_zug_hit(zug_id, out)
	return out


## Hit by a Windschatten: half damage, the stun is extended once per combo.
func _clone_hit(clone: WindClone, rect: Rect2, dmg: float, kb: float, launch := 0.0, hit_set = null, full := false) -> Array:
	var out: Array = []
	var d := dmg * (1.0 if full else CLONE_DMG)
	for tg in _targets():
		if hit_set != null and hit_set.has(tg.get_instance_id()):
			continue
		if not rect.intersects(tg.get_hurt_rect()):
			continue
		if hit_set != null:
			hit_set[tg.get_instance_id()] = true
		if _clone_stun_used and launch == 0.0:
			world.deal_dot(tg, d, "wind")
			world.fx.jitter(tg, 1.5)
		else:
			world.deal_hit(tg, d, "", clone.global_position.x, kb, "light" if kb < 120.0 else "heavy", launch)
			_clone_stun_used = true
		out.append(tg)
		var c: Vector2 = tg.get_hurt_rect().get_center()
		wfx.shards(c, 0.0 if clone.facing > 0 else PI, 0.9, 5, 220.0, _c("ice"))
		wfx.anim("kreiselfaust_treffer", c, 52.0, -1.0, randf() * TAU, clone.facing < 0, Color(0.8, 1.0, 1.0, 0.7), 1.5)
	if not out.is_empty():
		_combo_gap = 0.0
		player.add_gauge(1.5)
		world.fx.shake(2.0 * FxSettings.factor("shake"), clone.facing)
	return out


func _posture(tg, amount: float) -> void:
	if not tg.has_method("posture_hit"):
		return
	var k := WIND_POSTURE if tg.get("status") is Dictionary and tg.status.has("winddruck") else 1.0
	tg.posture_hit(amount * k, player.global_position.x)


func _winddruck(targets: Array, dmg: float) -> void:
	for tg in targets:
		if not is_instance_valid(tg) or not (tg.get("status") is Dictionary):
			continue
		var id: int = tg.get_instance_id()
		if _immune.has(id):
			continue
		var fresh: bool = not tg.status.has("winddruck")
		tg.status["winddruck"] = WIND_TIME
		if tg.has_method("is_elite") and tg.is_elite():
			_immune[id] = WIND_TIME + WIND_IMMUNE
		_posture(tg, dmg * 1.5)
		var c: Vector2 = tg.get_hurt_rect().get_center()
		wfx.anim("windstoss", c, 90.0, -1.0, 0.0, player.facing < 0, Color(1, 1, 1, 0.8), 1.4)
		if fresh:
			wfx.word(c + Vector2(0, -42), "WINDDRUCK!", _c("ice"), 15)


## Wind meets a burning surface: it grows once (50 % wider), no chain.
func _grow_fire(rect: Rect2) -> void:
	var area := rect.grow(20.0)
	for h in world.attacks.get_children():
		if not (h is GlutHazard) or h.has_meta("wind_grown"):
			continue
		var gh := h as GlutHazard
		if gh.kind != "spur" and gh.kind != "krater":
			continue
		var hr := Rect2(minf(gh.x0, gh.x1) - 4.0, gh.global_position.y - 20.0, absf(gh.x1 - gh.x0) + 8.0, 24.0) if gh.kind == "spur" else Rect2(gh.global_position - Vector2(gh.size, gh.size), Vector2(gh.size, gh.size) * 2.0)
		if not area.intersects(hr):
			continue
		gh.set_meta("wind_grown", true)
		if gh.kind == "spur":
			var w := absf(gh.x1 - gh.x0) * 0.25
			if gh.x1 >= gh.x0:
				gh.x0 -= w
				gh.x1 += w
			else:
				gh.x0 += w
				gh.x1 -= w
		else:
			gh.size *= 1.5
		gh.life += 1.0
		gh.damage *= 1.2
		var c := hr.get_center()
		wfx.word(c + Vector2(0, -26), "FAUCH!", _c("orange"), 16)
		wfx.gust(c, -PI / 2.0, 6, 30.0, _c("orange"))


# --- Windschatten -----------------------------------------------------------------

## Spawns a clone at `pos` facing `dir`; the oldest goes when 2 are out.
func spawn_clone(pos: Vector2, dir: int, steps: Array, lure := false, gravity := false) -> WindClone:
	if mantle_time > 0.0:
		return null
	while clones.size() >= MAX_CLONES:
		var old: WindClone = clones.pop_front()
		if is_instance_valid(old):
			old.vanish()
	var c := WindClone.new()
	c.caster = self
	c.world = world
	c.wfx = wfx
	c.facing = dir
	c.steps = steps
	c.lure = lure
	c.gravity = gravity
	c.global_position = pos
	world.add_child(c)
	clones.append(c)
	return c


func clone_gone(c: WindClone) -> void:
	clones.erase(c)


func clone_count() -> int:
	return clones.size()


## Steps for "dash to x, strike, vanish" (most clone attacks).
func _clone_strike_steps(to: Vector2, delay: float, pose_wind: String, pose_hit: String, rect_w: float, dmg: float, kb: float, launch := 0.0, full := false) -> Array:
	var hs := {}
	return [
		[0.0, func(c: WindClone): c.pose(pose_wind, "startup")],
		[delay, func(c: WindClone):
			c.pose("dash")
			c.vel = Vector2((to.x - c.global_position.x) / 0.1, (to.y - c.global_position.y) / 0.1)],
		[delay + 0.1, func(c: WindClone):
			c.vel = Vector2.ZERO
			c.pose(pose_hit)
			var r := Rect2(c.global_position.x + (0.0 if c.facing > 0 else -rect_w), c.global_position.y - 40.0, rect_w, 40.0)
			_clone_hit(c, r, dmg, kb, launch, hs, full)
			wfx.gust(c.global_position + Vector2(c.facing * 10.0, -22), 0.0 if c.facing > 0 else PI, 4, 30.0)],
		[delay + 0.32, func(c: WindClone): c.vanish()],
	]


# --- Wirbelansturm ---------------------------------------------------------------

func _tick_ansturm() -> void:
	var dmgs: Array = params.get("damage", [5, 5, 10])
	var n := dmgs.size()
	var sweep: bool = str(params.get("kind", "combo")) == "sweep"
	var reach: float = float(params.get("reach", 34)) * _reach()
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
	elif phase == "active":
		while _step < n and t >= _f(1) * float(_step) / n:
			var i := _step
			_step += 1
			var last := i == n - 1
			var poses := ["jab_hit", "cross_hit", "highkick_hit"] if not sweep else ["jab_hit", "lowkick_hit"]
			_pose = poses[mini(i, poses.size() - 1)]
			var r := _rect_front(4, reach + (8.0 if last else 0.0), -40 if not (sweep and last) else -18, 40 if not (sweep and last) else 20)
			var hit := _hit(r, float(dmgs[i]), 200.0 if last else 40.0, "heavy" if last else "light", (-200.0 if sweep and last else 0.0), {}, "", float(params.get("posture", 0)) if last else 0.0)
			player.velocity.x = player.facing * (80.0 if not last else 40.0)
			var tip := player.global_position + _fwd(reach * 0.7, -24 if not (sweep and last) else -8)
			if not hit.is_empty() or randf() < 0.6:
				wfx.anim("windstoss", tip, 44.0 + (24.0 if last else 0.0), -1.0, 0.0, player.facing < 0, Color(1, 1, 1, 0.75), 2.0)
			if last:
				wfx.ring(tip, 20.0, _c("ice"), 0.25, 3.0)
				wfx.word(tip + Vector2(0, -30), "BAM!", _c("white"), 20)
				world.fx.shake(3.0 * FxSettings.factor("shake"), player.facing)
				Sfx.play("swing_heavy")
				if mantle_time > 0.0:
					wfx.anim("kreiselfaust_treffer", tip + _fwd(20), 70.0, -1.0, 0.0, player.facing < 0)
			else:
				Sfx.play("swing_light")
			if i == 0 and params.get("side_clone", false):
				_side_clone()
		if t >= _f(1):
			if enhanced and _clone_mark and params.get("clone_finish", false):
				_finish_clone()
			_next_phase()
	elif phase == "recovery":
		_pose = "jab_wind"
		if t >= _f(2):
			_next_phase()


## Doppelter Auftakt: a clone comes in from the far side of the target.
func _side_clone() -> void:
	var tg := _nearest(120.0)
	var tx := player.global_position.x + player.facing * 60.0 if tg == null else tg.global_position.x
	var from := Vector2(tx + player.facing * 50.0, player.global_position.y)
	var to := Vector2(tx + player.facing * 14.0, player.global_position.y)
	var hits := 2 if _clone_mark else 1
	var steps := _clone_strike_steps(to, 0.25, "jab_wind", "highkick_hit", 34.0, 10.0, 160.0)
	if hits == 2:
		var hs2 := {}
		steps.insert(3, [0.5, func(c: WindClone):
			c.pose("hook_hit")
			var r := Rect2(c.global_position.x + (0.0 if c.facing > 0 else -34.0), c.global_position.y - 40.0, 34.0, 40.0)
			_clone_hit(c, r, 10.0, 180.0, 0.0, hs2)])
		steps[steps.size() - 1][0] = 0.72
	spawn_clone(from, -player.facing, steps)


## Verstärkt with a mark: a clone jumps over the figure and double-kicks.
func _finish_clone() -> void:
	var start := player.global_position + _fwd(-14)
	var land := player.global_position + _fwd(reach_front())
	var hs := {}
	spawn_clone(start, player.facing, [
		[0.0, func(c: WindClone):
			c.pose("jump")
			c.vel = Vector2((land.x - start.x) / 0.24, -260.0)],
		[0.12, func(c: WindClone): c.vel.y = 260.0],
		[0.24, func(c: WindClone):
			c.vel = Vector2.ZERO
			c.global_position.y = land.y
			c.pose("airkick_hit")
			var r := Rect2(c.global_position.x + (0.0 if c.facing > 0 else -38.0), c.global_position.y - 44.0, 38.0, 44.0)
			_clone_hit(c, r, 10.0, 60.0, 0.0, hs)
			wfx.word(c.global_position + Vector2(0, -50), "DOPPEL!", _c("ice"), 16)],
		[0.36, func(c: WindClone):
			c.pose("highkick_hit")
			var r2 := Rect2(c.global_position.x + (0.0 if c.facing > 0 else -38.0), c.global_position.y - 44.0, 38.0, 44.0)
			_clone_hit(c, r2, 10.0, 220.0, 120.0, {})
			wfx.anim("windstoss", c.global_position + Vector2(c.facing * 24.0, -24), 70.0, -1.0, 0.0, c.facing < 0)],
		[0.6, func(c: WindClone): c.vanish()],
	])


func reach_front() -> float:
	return 30.0 * _reach()


# --- Kreiselfaust ----------------------------------------------------------------

func _kreisel_size() -> float:
	return 30.0 * float(params.get("size", 1.0)) * _reach()


func _tick_kreisel() -> void:
	var size := _kreisel_size()
	var fist := player.global_position + _fwd(16.0, -14.0)
	if phase == "startup":
		_pose = "charge_0"
		var k := clampf(t / maxf(0.01, _f(0)), 0.0, 1.0)
		_fist_t += get_physics_process_delta_time() * (0.5 + 1.5 * k)
		wfx.hold("kreiselfaust", fist, size * (0.4 + 0.6 * k), _fist_t * 1.6)
		wfx.glow(fist, Color(_c("turq"), 0.25 + 0.35 * k), size * 0.4, 0.05)
		if randf() < 0.4 * k:
			wfx.motes(fist, 1, size * 0.2, _c("gold"), 0.4)
			wfx.thread(fist + Vector2(randf_range(-20, 20), randf_range(-20, 20)), fist, _c("turq"), 0.8)
		fx.light(fist, Color(0.5, 1.0, 1.0), 0.6 + 1.2 * k, 0.5, 0.05)
		if params.get("handover", false) and _step == 0 and t >= _f(0) * 0.6:
			_step = 1
			_handover_clone()
		if t >= _f(0):
			if params.get("handover", false) and _step == 1 and not _handover_ok():
				# the clone missed: break off
				frames[2] = 10
				phase = "active"
				_next_phase()
				wfx.word(_center() + Vector2(0, -40), "ZURÜCK!", _c("ice"), 14)
				return
			_next_phase()
			_x_start = player.global_position.x
			wfx.gust(fist, 0.0 if player.facing > 0 else PI, 6, 40.0)
			Sfx.play("dash")
	elif phase == "active":
		_pose = "dashpunch_hit"
		_fist_t += get_physics_process_delta_time() * 3.0
		var tip := player.global_position + _fwd(20.0, -14.0)
		wfx.hold("kreiselfaust", tip, size, _fist_t * 2.0)
		if randf() < 0.6:
			world.afterimages.add(player.sprite.snapshot(), Color(0.35, 0.9, 1.0, 0.55), Vector2.ZERO, 0.16)
		var area: float = float(params.get("area", 1.0)) * _reach()
		var r := _rect_front(6, 30.0 * area + 6.0, -30.0 - 6.0 * area, 26.0 + 12.0 * area)
		var hit := _hit(r, float(params.get("damage", 16)), 280.0, "heavy", 60.0, _hit_set, "wind")
		if not hit.is_empty() and _step < 10:
			_step = 10
			_kreisel_impact(hit[0].get_hurt_rect().get_center(), size)
		if t >= _f(1) or player.is_on_wall():
			if _missed:
				frames[2] = int(frames[2]) + 27
				wfx.word(_center() + Vector2(0, -40), "DANEBEN…", _c("storm"), 14)
			for c in clones:
				if is_instance_valid(c) and c.has_meta("holder"):
					c.vanish()
			_next_phase()
	elif phase == "recovery":
		_pose = "dashpunch_hit" if t < _f(2) * 0.4 else "jab_wind"
		if t >= _f(2):
			_next_phase()


func _kreisel_impact(c: Vector2, size: float) -> void:
	var big := enhanced or float(params.get("size", 1.0)) > 1.2 or mantle_time > 0.0
	wfx.anim("kreiselfaust_treffer", c, size * (4.0 if big else 3.0), -1.0, 0.0, player.facing < 0)
	wfx.ring(c, size * 1.4, _c("ice"), 0.35, 5.0)
	wfx.ring(c, size * 0.9, _c("gold"), 0.25, 3.0)
	wfx.shards(c, 0.0 if player.facing > 0 else PI, 1.1, 14, 340.0, _c("ice"))
	wfx.gust(c, 0.0 if player.facing > 0 else PI, 10, 60.0)
	wfx.word(c + Vector2(0, -40), "WHIRR!", _c("white"), 26 if big else 20)
	world.fx.flash((0.25 if big else 0.15) * FxSettings.factor("flash"), Color(0.75, 1.0, 1.0))
	world.fx.shake((7.0 if big else 4.0) * FxSettings.factor("shake"), player.facing)
	world.fx.freeze((0.09 if big else 0.05) * FxSettings.factor("stop"))
	world.fx.punch(0.05 if big else 0.03)
	Sfx.play("break" if big else "hit_heavy")


## Verstärkt with a mark: a clone runs ahead and holds the target.
func _spawn_holder() -> void:
	var tg = _nearest(140.0)
	if tg == null:
		return
	var to := Vector2(tg.global_position.x - player.facing * 10.0, tg.global_position.y)
	var c := spawn_clone(player.global_position + _fwd(8), player.facing, [
		[0.0, func(cl: WindClone):
			cl.pose("dash")
			cl.vel = Vector2((to.x - cl.global_position.x) / 0.12, 0.0)],
		[0.12, func(cl: WindClone):
			cl.vel = Vector2.ZERO
			cl.pose("grab_0")
			if is_instance_valid(tg):
				tg.take_hit(10.0, cl.global_position.x)
				if tg.get("vel") != null:
					tg.vel = Vector2.ZERO
				wfx.word(tg.head_position() + Vector2(0, -6), "GEPACKT!", _c("ice"), 14)],
		[0.3, func(cl: WindClone):
			if is_instance_valid(tg) and tg.get("vel") != null:
				tg.vel = Vector2.ZERO],
		[1.2, func(cl: WindClone): cl.vanish()],
	])
	if c != null:
		c.set_meta("holder", true)


## Klon-Übergabe: a clone starts the thrust, the figure follows.
var _handover_clone_ref: WindClone = null
var _handover_hit := false


func _handover_clone() -> void:
	_handover_hit = false
	var hs := {}
	var size := _kreisel_size()
	_handover_clone_ref = spawn_clone(player.global_position + _fwd(6), player.facing, [
		[0.0, func(cl: WindClone):
			cl.pose("dashpunch_hit")
			cl.vel = Vector2(cl.facing * 420.0, 0.0)],
		[0.02, func(cl: WindClone): pass],
	])
	if _handover_clone_ref == null:
		_handover_hit = true
		return
	var cl := _handover_clone_ref
	# the clone hits during its run (checked every frame by a small step chain)
	for i in 10:
		cl.steps.append([0.03 + i * 0.025, func(c: WindClone):
			wfx.hold("kreiselfaust", c.global_position + Vector2(c.facing * 18.0, -14.0), size * 0.8, Time.get_ticks_msec() * 0.004)
			if _handover_hit:
				return
			var r := Rect2(c.global_position.x + (0.0 if c.facing > 0 else -30.0), c.global_position.y - 34.0, 30.0, 30.0)
			if not _clone_hit(c, r, float(params.get("damage", 16)), 120.0, 0.0, hs).is_empty():
				_handover_hit = true
				c.vel = Vector2.ZERO])
	cl.steps.append([0.32, func(c: WindClone): c.vanish()])


func _handover_ok() -> bool:
	return _handover_hit or _nearest(80.0) != null


# --- Klon-Aufsteiger -------------------------------------------------------------

func _tick_aufsteiger() -> void:
	if phase == "startup":
		_pose = "cast_wind"
		if params.get("kunai", false) and _step == 0:
			_step = 1
			_throw_kunai(_fist(), Vector2(player.facing * 420.0, -60.0), 5.0, true)
			_pose = "jab_hit"
		if t >= _f(0):
			_next_phase()
			_aufsteiger_clone()
	elif phase == "active":
		if _step < 20 and t >= 0.12:
			_step = 20
			player.velocity.y = float(params.get("jump", -470))
			player.velocity.x = player.facing * 60.0
			_pose = "jump"
			wfx.gust(player.global_position, -PI / 2.0, 5, 30.0)
		if _step >= 20 and _follow and not _did_follow:
			_did_follow = true
			_pose = "airkick_hit"
			var r := Rect2(player.global_position + Vector2(-20 + player.facing * 6.0, -60), Vector2(40, 50))
			var hit := _hit(r, float(params.get("air_damage", 9)), 160.0, "heavy", 80.0, {})
			wfx.anim("windstoss", player.global_position + _fwd(16, -30), 60.0, -1.0, -0.5 * player.facing, player.facing < 0)
			if not hit.is_empty():
				wfx.word(player.global_position + Vector2(0, -64), "HOCH!", _c("ice"), 18)
		if t >= _f(1):
			_next_phase()
	elif phase == "recovery":
		_pose = "fall"
		if t >= _f(2):
			_next_phase()


func _aufsteiger_clone() -> void:
	var tg = _target if is_instance_valid(_target) else null
	var tx: float = player.global_position.x + player.facing * 34.0
	if tg != null:
		tx = tg.global_position.x - player.facing * 12.0
	var at := Vector2(tx, player.global_position.y)
	var kicks := int(params.get("kicks", 1))
	var launch := float(params.get("launch", 380))
	var hs := {}
	var steps: Array = [
		[0.0, func(c: WindClone): c.pose("highkick_wind", "startup")],
	]
	for i in kicks:
		var last := i == kicks - 1
		steps.append([0.06 + i * 0.12, func(c: WindClone):
			c.pose("upper_hit" if last else "highkick_hit")
			var r := Rect2(c.global_position.x + (-6.0 if c.facing > 0 else -34.0), c.global_position.y - 50.0, 40.0, 50.0)
			var hit := _clone_hit(c, r, float(params.get("damage", 6)), 60.0, launch if last else 120.0, hs if not last else {}, true)
			wfx.anim("windstoss", c.global_position + Vector2(c.facing * 12.0, -36), 64.0, -1.0, -PI / 2.0 + 0.3 * c.facing, false, Color(1, 1, 1, 0.8), 1.6)
			if not hit.is_empty():
				on_zug_hit(zug_id, hit)
				if last:
					wfx.word(c.global_position + Vector2(0, -60), "HOPP!", _c("ice"), 18)])
	steps.append([0.06 + kicks * 0.12 + 0.2, func(c: WindClone): c.vanish()])
	# the core clone of this Zug costs no mark but counts towards the limit
	var saved := mantle_time
	mantle_time = 0.0
	spawn_clone(at, player.facing, steps)
	mantle_time = saved
	if enhanced and _clone_mark and params.get("second_clone", false):
		var hs2 := {}
		spawn_clone(at + Vector2(-player.facing * 16.0, 0), player.facing, [
			[0.0, func(c: WindClone): c.pose("jump")],
			[0.25, func(c: WindClone): c.vel = Vector2(c.facing * 20.0, -520.0)],
			[0.42, func(c: WindClone):
				c.vel = Vector2.ZERO
				c.pose("airkick_hit")
				var r := Rect2(c.global_position.x - 20.0, c.global_position.y - 60.0, 44.0, 60.0)
				_clone_hit(c, r, 12.0, 120.0, 260.0, hs2)],
			[0.62, func(c: WindClone): c.vanish()],
		])


# --- Wechselhülle --------------------------------------------------------------------

func _tick_huelle() -> void:
	if phase == "startup":
		_pose = "block_0"
		if t >= _f(0):
			_next_phase()
	elif phase == "active":
		_pose = "block_0"
		var c := _center()
		var pulse := 0.5 + 0.5 * sin(t * 30.0)
		if str(params.get("mode", "")) != "net":
			wfx.glow(c, Color(_c("turq"), 0.2 + 0.2 * pulse), 20.0, 0.05)
			wfx.thread(c + Vector2(-12, -14), c + Vector2(12, 14), Color(_c("turq"), 0.5), 0.8)
		# after the first 0.15 s only the damage cut remains (too early)
		if countering and t > 0.15:
			countering = false
			_guard_t = _f(1) - t
			_guard_cut = 0.6
		if t >= _f(1):
			_next_phase()
	elif phase == "counter":
		_pose = "hook_hit" if t < 0.16 else "highkick_hit"
		if _step == 0 and t >= 0.08:
			_step = 1
			var r := _rect_front(-4, 46, -42, 44)
			var hit := _hit(r, float(params.get("counter_damage", 12)), 260.0, "heavy", 120.0, _hit_set, "wind" if enhanced else "")
			if enhanced and params.get("wind_press", false):
				_winddruck(hit, 12.0)
			wfx.anim("kreiselfaust_treffer", player.global_position + _fwd(24, -24), 80.0, -1.0, 0.0, player.facing < 0)
		if t >= 0.3:
			_next_phase()
	elif phase == "recovery":
		_pose = "jab_wind"
		if t >= _f(2) * 0.6:
			_next_phase()


func try_counter(from_x: float, projectile: Node = null) -> bool:
	if not countering:
		return false
	countering = false
	var mode := str(params.get("mode", "swap"))
	var old := player.global_position
	var side := 1.0 if from_x >= old.x else -1.0
	invuln = 0.45
	_hit_set = {}
	_step = 0
	world.fx.flash(0.2 * FxSettings.factor("flash"), Color(0.8, 1.0, 1.0))
	world.fx.freeze(0.1 * FxSettings.factor("stop"))
	world.fx.punch(0.05)
	player.add_gauge(12.0)
	match mode:
		"lure":
			# a clone stays behind as bait, the figure hops back
			var saved := mantle_time
			mantle_time = 0.0
			spawn_clone(old, int(side), [[0.0, func(c: WindClone): c.pose("block_0")], [1.0, func(c: WindClone): c.vanish()]], true)
			mantle_time = saved
			player.global_position.x -= side * 44.0
			player.facing = int(side)
			if marks < MAX_MARKS:
				marks += 1
			wfx.word(old + Vector2(0, -60), "HIER!", _c("ice"), 18)
			phase = "recovery"
			t = _f(2) * 0.4
			return true
		"side":
			player.global_position.x -= side * 30.0
			player.facing = int(side)
			invuln = 0.15 + 0.3
			wfx.gust(old + Vector2(0, -20), PI if side > 0 else 0.0, 6, 30.0)
			wfx.word(old + Vector2(0, -56), "HUSCH!", _c("ice"), 18)
		_:
			# Strohpuppe stays, the figure stands behind the attacker
			wfx.anim("strohpuppe", old + Vector2(0, -36), 46.0)
			wfx.anim("poff", old + Vector2(0, -22), 50.0)
			wfx.word(old + Vector2(0, -64), "POFF!", _c("white"), 20)
			var nx := from_x + side * 22.0
			player.global_position.x = nx
			player.facing = -int(side)
			wfx.anim("windschatten_entstehen", player.global_position + Vector2(0, -22), 60.0, -1.0, 0.0, false, Color.WHITE, 2.0)
			wfx.word(player.global_position + Vector2(0, -62), "HINTER DIR!", _c("gold"), 18)
	phase = "counter"
	t = 0.0
	if projectile != null and projectile.has_method("burn"):
		projectile.burn()
	return true


## Fadenwehr and the too-early guard: part of the damage is caught.
func guard_hit(damage: float, _from_x: float, _source: Node) -> bool:
	if zug_id != "wechselhuelle" or phase != "active" or _guard_t <= 0.0:
		return false
	var dmg := maxf(1.0, damage * (1.0 - _guard_cut))
	player.hp = maxf(1.0, player.hp - dmg)
	world.numbers.spawn_number(player.global_position + Vector2(0, -50), int(dmg), Color("9fe8ff"), player.get_instance_id(), false)
	wfx.shards(_center() + _fwd(10), PI if player.facing > 0 else 0.0, 1.0, 8, 200.0, _c("turq"))
	wfx.word(_center() + Vector2(0, -40), "GEHALTEN", _c("turq"), 14)
	Sfx.play("hit_light")
	return true


# --- Klonschleuder -------------------------------------------------------------------

var _thrower: WindClone = null


func _spawn_thrower() -> void:
	_thrower = null
	if params.get("decoy", false):
		return
	var saved := mantle_time
	mantle_time = 0.0
	_thrower = spawn_clone(player.global_position + _fwd(-12), player.facing, [
		[0.0, func(c: WindClone): c.pose("grab_0")],
		[_f(0), func(c: WindClone): c.pose("throw_0")],
		[_f(0) + 0.3, func(c: WindClone): c.vanish()],
	])
	mantle_time = saved


func _tick_schleuder() -> void:
	var dist: float = float(params.get("dist", 120))
	if phase == "startup":
		_pose = "grab_0" if not params.get("decoy", false) else "cast_wind"
		if t >= _f(0):
			_next_phase()
			wfx.word(_center() + Vector2(0, -44), "HAU RUCK!", _c("ice"), 16)
			wfx.gust(_center(), 0.0 if player.facing > 0 else PI, 8, 50.0)
			Sfx.play("dash")
			if params.get("decoy", false):
				_decoy_throw(dist)
			elif enhanced and _clone_mark and params.get("catch_clone", false):
				_catch_clone(dist)
	elif phase == "active":
		if params.get("decoy", false):
			_pose = "cast_hit"
		else:
			_pose = "dash" if not _did_follow else "airkick_hit"
			if randf() < 0.7:
				world.afterimages.add(player.sprite.snapshot(), Color(0.35, 0.9, 1.0, 0.5), Vector2.ZERO, 0.14)
			if _follow and not _did_follow:
				_did_follow = true
				wfx.word(_center() + Vector2(0, -44), "TRITT!", _c("white"), 18)
			if _did_follow:
				var r := _rect_front(-2, 34, -40, 40)
				var hit := _hit(r, float(params.get("damage", 11)), 240.0, "heavy", 100.0, _hit_set)
				if not hit.is_empty() and _step < 5:
					_step = 5
					var c: Vector2 = hit[0].get_hurt_rect().get_center()
					wfx.anim("kreiselfaust_treffer", c, 80.0, -1.0, 0.0, player.facing < 0)
					world.fx.shake(4.0 * FxSettings.factor("shake"), player.facing)
		if t >= _f(1) or player.is_on_wall():
			_next_phase()
	elif phase == "recovery":
		_pose = "land_0" if player.is_on_floor() else "fall"
		if t >= _f(2):
			_next_phase()


func _catch_clone(dist: float) -> void:
	var tg := _nearest(dist * 1.6)
	var at := player.global_position + _fwd(dist)
	if tg != null:
		at = Vector2(tg.global_position.x + player.facing * 16.0, tg.global_position.y)
	var hs := {}
	spawn_clone(at, -player.facing, [
		[0.0, func(c: WindClone): c.pose("jab_wind", "startup")],
		[_f(1) * 0.6, func(c: WindClone):
			c.pose("cross_hit")
			var r := Rect2(c.global_position.x + (0.0 if c.facing > 0 else -34.0), c.global_position.y - 40.0, 34.0, 40.0)
			_clone_hit(c, r, 12.0, 160.0, 0.0, hs)
			wfx.word(c.global_position + Vector2(0, -50), "GEFANGEN!", _c("ice"), 14)],
		[_f(1) * 0.6 + 0.3, func(c: WindClone): c.vanish()],
	])


## Täuschungswurf: a clone is thrown, the real figure stays back.
func _decoy_throw(dist: float) -> void:
	var hs := {}
	var dur := _f(1)
	var vy := float(params.get("vy", -120))
	var saved := mantle_time
	mantle_time = 0.0
	var c := spawn_clone(player.global_position + _fwd(6), player.facing, [
		[0.0, func(cl: WindClone):
			cl.pose("airkick_hit")
			cl.vel = Vector2(cl.facing * dist / maxf(0.05, dur), vy)],
	], false, true)
	mantle_time = saved
	if c == null:
		return
	for i in 8:
		c.steps.append([0.02 + i * dur / 8.0, func(cl: WindClone):
			var r := Rect2(cl.global_position.x - 16.0, cl.global_position.y - 40.0, 32.0, 40.0)
			for tg in _clone_hit(cl, r, 12.0, 60.0, 0.0, hs):
				tg.take_hit(140.0, cl.global_position.x)
				wfx.word(tg.head_position() + Vector2(0, -8), "HEREINGELEGT!", _c("gold"), 13)])
	c.steps.append([dur + 0.25, func(cl: WindClone): cl.vanish()])


# --- Wirbelsturz ---------------------------------------------------------------------

func _tick_sturz() -> void:
	var size := _kreisel_size() * 0.8
	var fist := player.global_position + _fwd(12.0, -6.0)
	if phase == "startup":
		_pose = "charge_0"
		var k := clampf(t / maxf(0.01, _f(0)), 0.0, 1.0)
		_fist_t += get_physics_process_delta_time() * 2.0
		if params.get("kunai_fan", 0) == 0:
			wfx.hold("kreiselfaust", fist, size * (0.5 + 0.5 * k), _fist_t)
		if t >= _f(0):
			if int(params.get("kunai_fan", 0)) > 0:
				phase = "startup"
				_next_phase()
				_kunai_fan(int(params.kunai_fan))
				return
			phase = "fall"
			t = 0.0
			_hit_set = {}
			wfx.gust(_center(), PI / 2.0, 6, 40.0)
			Sfx.play("dash")
			if params.get("follow_clone", false):
				_follow_clone()
	elif phase == "fall":
		_pose = "dashpunch_hit"
		_fist_t += get_physics_process_delta_time() * 3.0
		wfx.hold("kreiselfaust", player.global_position + _fwd(14.0, -4.0), size, _fist_t)
		if randf() < 0.7:
			world.afterimages.add(player.sprite.snapshot(), Color(0.35, 0.9, 1.0, 0.5), Vector2.ZERO, 0.14)
		var r := Rect2(player.global_position + Vector2(-18 + player.facing * 8.0, -28), Vector2(36, 32))
		_hit(r, float(params.get("damage", 18)), 60.0, "heavy", -260.0, _hit_set, "wind")
		if player.is_on_floor() and t > 0.02:
			_sturz_impact()
			_next_phase()
		elif t > 1.0:
			_next_phase()
	elif phase == "active":
		_pose = "airpunch_hit"
		if t >= _f(1):
			_next_phase()
	elif phase == "recovery":
		_pose = "land_0"
		if t >= _f(2):
			_next_phase()


func _sturz_impact() -> void:
	var p := player.global_position
	var big := enhanced or mantle_time > 0.0
	var gust := float(params.get("gust", 5))
	wfx.anim("wirbelsturz_aufprall", p + Vector2(0, -16), 120.0 if not big else 170.0)
	wfx.ring(p + Vector2(0, -4), 50.0 if not big else 80.0, _c("ice"), 0.35, 5.0)
	wfx.word(p + Vector2(0, -60), "WUMMS!", _c("white"), 28 if big else 22)
	world.fx.shake((6.0 if not big else 10.0) * FxSettings.factor("shake"))
	world.fx.punch(0.04)
	world.fx.freeze(0.05 * FxSettings.factor("stop"))
	world.fx.flash((0.12 if not big else 0.25) * FxSettings.factor("flash"), Color(0.8, 1.0, 1.0))
	Sfx.play("break" if big else "hit_heavy")
	if gust > 0.0:
		var w := 60.0 * (1.5 if big else 1.0) * _reach()
		for d in [-1.0, 1.0]:
			wfx.anim("windstoss", p + Vector2(d * w * 0.5, -14), w * 1.4, -1.0, 0.0, d < 0.0)
			var r := Rect2(p.x + (0.0 if d > 0 else -w), p.y - 30, w, 30)
			_hit(r, gust, 180.0, "heavy", 120.0, _hit_set, "wind")
	if _missed:
		frames[2] = int(frames[2]) + 24
		wfx.word(p + Vector2(0, -36), "AUTSCH", _c("storm"), 13)


func _follow_clone() -> void:
	var start := player.global_position + _fwd(-18, -30)
	var hs := {}
	var full := _clone_mark
	var size := _kreisel_size()
	spawn_clone(start, player.facing, [
		[0.0, func(c: WindClone): c.pose("charge_0")],
		[0.2, func(c: WindClone):
			c.pose("dashpunch_hit")
			c.vel = Vector2(c.facing * float(params.get("vx", 220)), float(params.get("fall", 700)))
			c.gravity = false],
		[0.22, func(c: WindClone): pass],
		[1.2, func(c: WindClone): c.vanish()],
	])
	var c: WindClone = clones.back() if not clones.is_empty() else null
	if c == null:
		return
	for i in 14:
		c.steps.insert(c.steps.size() - 1, [0.24 + i * 0.03, func(cl: WindClone):
			if full:
				wfx.hold("kreiselfaust", cl.global_position + Vector2(cl.facing * 14.0, -4.0), size * 0.8, Time.get_ticks_msec() * 0.004)
			var r := Rect2(cl.global_position.x - 18.0, cl.global_position.y - 30.0, 36.0, 32.0)
			if not _clone_hit(cl, r, 18.0 if full else 9.0, 160.0, 0.0, hs).is_empty():
				wfx.word(cl.global_position + Vector2(0, -50), "NACHSCHLAG!", _c("ice"), 14)
			var gy := GlutHazard.ground_y(cl.global_position.x, cl.global_position.y - 4.0)
			if cl.global_position.y >= gy - 1.0:
				cl.global_position.y = gy
				cl.vel = Vector2.ZERO
				wfx.anim("wirbelsturz_aufprall", cl.global_position + Vector2(0, -14), 80.0, -1.0, 0.0, false, Color(0.8, 1.0, 1.0, 0.7))
				cl.vanish()])


func _kunai_fan(n: int) -> void:
	_pose = "airpunch_hit"
	var base := PI / 2.0 - player.facing * 0.7
	for i in n:
		var a := base + player.facing * (-0.45 + 0.9 * float(i) / maxf(1.0, n - 1.0))
		_throw_kunai(_fist(), Vector2(cos(a), sin(a)) * 440.0, float(params.get("damage", 4)), false)
	wfx.word(_center() + Vector2(0, -44), "SCHWIRR!", _c("ice"), 18)
	Sfx.play("swing_light", 3.0)
	player.velocity.y = -120.0


func _throw_kunai(from: Vector2, v: Vector2, dmg: float, hold_target: bool) -> void:
	var k := KunaiShot.new()
	k.caster = self
	k.world = world
	k.wfx = wfx
	k.vel = v
	k.damage = dmg
	k.hold = hold_target
	k.global_position = from
	world.attacks.add_child(k)
	wfx.gust(from, v.angle(), 3, 20.0)


# --- movement & pose for the player --------------------------------------------

func drive_velocity(v: Vector2, delta: float, on_floor: bool) -> Vector2:
	var g := minf(v.y + Player.GRAVITY * delta, Player.MAX_FALL)
	match zug_id:
		"kreiselfaust":
			if phase == "active":
				return Vector2(player.facing * float(params.get("dist", 60)) * _reach() / maxf(0.05, _f(1)), 0.0)
			if phase == "startup":
				return Vector2(move_toward(v.x, 0.0, 2400.0 * delta), minf(v.y + Player.GRAVITY * 0.4 * delta, 120.0))
		"klonschleuder":
			if phase == "active" and not params.get("decoy", false):
				var dist := float(params.get("dist", 120))
				var vy := float(params.get("vy", -120))
				if t < 0.02:
					return Vector2(player.facing * dist / maxf(0.05, _f(1)), vy)
				return Vector2(player.facing * dist / maxf(0.05, _f(1)), minf(v.y + Player.GRAVITY * 0.6 * delta, Player.MAX_FALL))
			if phase == "startup":
				return Vector2(0.0, g)
		"wirbelsturz":
			if phase == "fall":
				return Vector2(player.facing * float(params.get("vx", 220)), float(params.get("fall", 700)))
			if phase == "startup" or phase == "active":
				return Vector2(v.x * 0.9, minf(v.y + Player.GRAVITY * 0.6 * delta, 100.0))
		"wechselhuelle":
			return Vector2(0.0, g)
		"klon_aufsteiger":
			if phase == "active" and _step >= 20:
				return Vector2(v.x, minf(v.y + Player.GRAVITY * 0.85 * delta, Player.MAX_FALL))
		"wirbelansturm":
			return Vector2(move_toward(v.x, 0.0, 600.0 * delta), g)
	return super.drive_velocity(v, delta, on_floor)


func pose_frame() -> int:
	return 3
