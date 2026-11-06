class_name BollwerkCaster
extends GlutCaster
## Runs the Züge of the fighting style Bollwerk (gepanzerter Supersoldat,
## Wachprotokoll) and owns its state. Same interface as GlutCaster; the rules
## are the style's own (docs/stil-bollwerk.md):
##  - Schild: an extra bar (40 % of the HP) takes hits before the HP. After
##    3.5 s without a hit it refills (full in 2 s). Breaking it gives a clear
##    signal (blue shards, red visor blink); then the HP are open.
##  - Einsatzenergie: 3 cells. A salvo with 3 of 4 hits, every 3 pistol hits
##    and every melee hit fill one. The next Ausrüstungszug (Granate, Schild-
##    protokoll, Kettenhaken) spends all cells and gets stronger per cell.
##    Shield and energy are separate: attacking never refills the shield.
##  - Magazin: the rifle has a magazine; reloading (1.2 s) blocks shooting,
##    not moving or melee. Manual reload: hold down 0.3 s on the ground.
##  - Granaten: 2 charges, one comes back every 9 s.
##  - Schildstörung ("stoerung"): plasma/electric Züge. Enemies here have no
##    energy shields, so it does the limited posture damage instead (+50 %).

const AIM_TILT := 20.0
const HEX_TIME := 0.4

var bfx: BollwerkFx
var rules: Dictionary = {}

# shield
var shield := 0.0
var shield_max := 1.0
var _since_hit := 99.0
var _hex_k := 0.0
var _broken_t := 0.0

# energy
var energy := 0
var _energy_idle := 0.0
var _spent := 0  # cells spent by the running Ausrüstungszug

# magazine
var ammo := 0
var mag := 32
var reload_t := 0.0
var reload_max := 1.2
var _mag_key := ""
var _down_t := 0.0

# grenades
var grenades := 2.0

# salvo rhythm
var _last_salvo := -9.0
var _spread := 1.0
var _shots_fired := 0
var _shots_hit := 0
var _pistol_hits := 0
var aim_deg := 0.0

# Fremdklinge cooldown (Zug 2 falls back to the Kolbenschlag meanwhile)
var blade_cd := 0.0

# Kettenhaken / Schubdüse / Orbitalsturz
var _grab := Vector2.INF
var _grab_target: Node2D = null
var _hook_tip := Vector2.ZERO
var _push := Vector2.ZERO
var _land_x := 0.0
var _missed := true

# Schildprotokoll
var wall: Node2D = null
var _reserve := false

# weapon shown in the hand ("" = the Salve weapon)
var weapon_override := ""
var _now := 0.0


func setup(p: Player, st: FightingStyle) -> void:
	super.setup(p, st)
	GlutIcons.style_id = st.id
	rules = st.data.get("rules", {})
	bfx = BollwerkFx.new()
	bfx.room = world
	world.add_child(bfx)
	shield_max = player.max_hp * float(rules.get("shield_frac", 0.4))
	shield = shield_max
	grenades = float(rules.get("grenades", 2))
	_refresh_mag(true)


func _r(key: String, def: float) -> float:
	return float(rules.get(key, def))


func stage_color() -> Color:
	return style.color("amber")


func trail_color() -> Color:
	return style.color("steel").lerp(style.color("amber"), 0.3)


func normal_element() -> String:
	return ""


func normal_mul() -> float:
	return 1.0


func blade_heat() -> float:
	return 0.0


func reset_fight() -> void:
	shield_max = player.max_hp * _r("shield_frac", 0.4)
	shield = shield_max
	energy = 0
	grenades = _r("grenades", 2)
	blade_cd = 0.0
	reload_t = 0.0
	ammo = mag


func salve_weapon() -> String:
	var a := style.alt("salve")
	return str(a.get("weapon", style.zug("salve").get("weapon", rules.get("weapon_default", "wachhund"))))


func _refresh_mag(fill := false) -> void:
	var key := salve_weapon()
	var p := style.params("salve")
	mag = int(p.get("mag", 32))
	reload_max = float(p.get("reload", _r("reload", 1.2)))
	if key != _mag_key or fill:
		_mag_key = key
		ammo = mag
		reload_t = 0.0


func start_reload() -> void:
	if reload_t > 0.0 or ammo >= mag:
		return
	reload_t = reload_max
	Sfx.play("bw_reload")
	var hand := _muzzle()
	bfx.word(player.global_position + Vector2(0, -52), "KLACK", style.color("steel"), 14)
	# the empty magazine drops out
	bfx.shards(hand + Vector2(-player.facing * 4.0, 4), PI / 2.0, 0.3, 1, 60.0, style.color("steel"))


# --- energy ---------------------------------------------------------------------

func add_energy(n := 1) -> void:
	var before := energy
	energy = mini(int(_r("energy_max", 3)), energy + n)
	_energy_idle = 0.0
	if energy > before:
		var c := player.global_position + Vector2(-player.facing * 8.0, -30)
		bfx.glow(c, Color(style.color("gold"), 0.8), 10.0, 0.25)
		bfx.ring(c, 10.0, style.color("gold"), 0.25, 2.0)
		if energy == int(_r("energy_max", 3)):
			bfx.word(c + Vector2(0, -20), "EINSATZBEREIT", style.color("gold"), 13)


## Ausrüstungszug: takes all cells (shown on the Zug), returns how many.
func _spend_energy() -> int:
	var n := energy
	energy = 0
	if n > 0:
		var c := player.global_position + Vector2(0, -26)
		bfx.ring(c, 18.0 + n * 6.0, style.color("gold"), 0.3, 3.0)
		bfx.word(c + Vector2(-player.facing * 14.0, -34), "ENERGIE x%d" % n, style.color("gold"), 14)
	return n


# --- casting -------------------------------------------------------------------

func cast(dir: String) -> bool:
	if busy() or player.in_super:
		return false
	var z := style.zug_in(dir)
	if z == "":
		z = style.zug_in("neutral")
	if z == "" or cooldowns.get(z, 0.0) > 0.0:
		return false
	_refresh_mag()
	if z == "salve" or (z == "orbitalsturz" and str(style.params(z).get("kind", "")) == "luftsalve"):
		if reload_t > 0.0:
			return false
		if ammo <= 0:
			Sfx.play("bw_empty")
			bfx.word(_muzzle() + Vector2(0, -14), "LEER", style.color("steel"), 13)
			start_reload()
			return false
	if z == "splitterwurf" and grenades < 1.0:
		Sfx.play("bw_empty")
		bfx.word(player.global_position + Vector2(0, -52), "KEINE GRANATE", style.color("steel"), 13)
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
	_x_start = player.global_position.x
	_y_start = player.global_position.y
	_age = 0.0
	_missed = true
	_spent = 0
	_grab = Vector2.INF
	_grab_target = null
	var alt_cd = style.alt(z).get("cd", null)
	cooldowns[z] = style.cooldown(z, alt_cd)
	player.move = {}
	if style.zug(z).get("gear", false):
		_spent = _spend_energy()
		if z == "kettenhaken" and _spent >= 3:
			cooldowns[z] = 0.0
	_on_start()
	return true


func _decide_enhanced() -> void:
	_decided = true
	if not Input.is_action_pressed("special") or not (player.gauge >= 100.0 or player.infinite_aura):
		return
	# Salve: hammering the button must not eat the Leiste; only a real hold counts
	if zug_id == "salve" and _age < 0.15:
		return
	enhanced = true
	if not player.infinite_aura:
		player.gauge -= 100.0
	params = style.params(zug_id, true)
	var c := player.global_position + Vector2(0, -26)
	bfx.ring(c, 26.0, style.color("amber"), 0.3, 3.0)
	bfx.word(c + Vector2(-player.facing * 18.0, -40), "VERSTÄRKT", style.color("gold"), 16, -0.05)
	world.fx.flash(0.12 * FxSettings.factor("flash"), Color(1.0, 0.8, 0.45))


func interrupt() -> void:
	if zug_id == "schildprotokoll" and _reserve and phase == "startup":
		bfx.word(player.global_position + Vector2(0, -52), "ABGEBROCHEN", style.color("steel"), 13)
	_reserve = false
	zug_id = ""
	phase = ""
	countering = false
	weapon_override = ""
	aim_deg = 0.0


# --- geometry ---------------------------------------------------------------------

func _center() -> Vector2:
	return player.global_position + Vector2(0, -22)


func _fwd(d: float, y := 0.0) -> Vector2:
	return Vector2(player.facing * d, y)


func _rect_front(x0: float, w: float, y_top: float, h: float) -> Rect2:
	var x := player.global_position.x + (x0 if player.facing > 0 else -x0 - w)
	return Rect2(x, player.global_position.y + y_top, w, h)


## Muzzle of the gun in the hand (world), from the creator weapon's tip.
func _muzzle() -> Vector2:
	var line := player.sprite.blade_line()
	if not line.is_empty():
		return line[1]
	return player.global_position + Vector2(player.facing * 22.0, -26.0)


func _helmet() -> Vector2:
	return player.global_position + Vector2(player.facing * 3.0, -38.0)


# --- per frame ----------------------------------------------------------------

func tick(delta: float) -> void:
	_now += delta
	for z in cooldowns:
		cooldowns[z] = maxf(0.0, cooldowns[z] - delta)
	invuln = maxf(0.0, invuln - delta)
	blade_cd = maxf(0.0, blade_cd - delta)
	_tick_shield(delta)
	_tick_energy(delta)
	_tick_ammo(delta)
	grenades = minf(_r("grenades", 2), grenades + delta / maxf(0.1, _r("grenade_regen", 9.0)))
	if wall != null and not is_instance_valid(wall):
		wall = null
	_show_weapon()
	if not busy():
		return
	t += delta
	_age += delta
	if not _decided and _age >= 0.15:
		_decide_enhanced()
	match zug_id:
		"salve":
			_tick_salve()
		"durchbruch":
			_tick_durchbruch()
		"splitterwurf":
			_tick_simple(Callable(self, "_throw"))
		"schildprotokoll":
			_tick_schild()
		"kettenhaken":
			_tick_haken()
		"orbitalsturz":
			_tick_sturz()


func _show_weapon() -> void:
	var body: LayeredBody = player.sprite.body
	if body == null or not player.sprite.use_body:
		return
	var want := weapon_override if weapon_override != "" else salve_weapon()
	body.set_weapon(want)
	body.aim_deg = aim_deg


func _tick_shield(delta: float) -> void:
	_since_hit += delta
	_hex_k = maxf(0.0, _hex_k - delta / HEX_TIME)
	_broken_t = maxf(0.0, _broken_t - delta)
	shield_max = player.max_hp * _r("shield_frac", 0.4)
	if _since_hit >= _r("shield_delay", 3.5) and shield < shield_max:
		var was_empty := shield <= 0.0
		shield = minf(shield_max, shield + shield_max / maxf(0.1, _r("shield_fill", 2.0)) * delta)
		if was_empty:
			bfx.word(player.global_position + Vector2(0, -54), "SCHILD LÄDT", style.color("shield"), 13)
			Sfx.play("bw_shield_hit", -6.0)
		if shield >= shield_max:
			bfx.ring(_center(), 26.0, style.color("shield"), 0.35, 2.5)
		if player.sprite.visible and not player.in_super:
			bfx.hex_shield(_center(), 0.3 + 0.2 * sin(_now * 14.0))
	if _hex_k > 0.0 and player.sprite.visible:
		bfx.hex_shield(_center(), _hex_k)
	if _broken_t > 0.0 and fmod(_broken_t, 0.2) < 0.1:
		bfx.glow(_helmet() + _fwd(2.0), Color(1.0, 0.2, 0.15, 0.9), 6.0, 0.05)


func _tick_energy(delta: float) -> void:
	if energy <= 0:
		_energy_idle = 0.0
		return
	_energy_idle += delta
	var after := _r("energy_decay_after", 6.0)
	if _energy_idle >= after + _r("energy_decay_every", 2.0):
		energy -= 1
		_energy_idle = after


func _tick_ammo(delta: float) -> void:
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			reload_t = 0.0
			ammo = mag
			bfx.word(player.global_position + Vector2(0, -52), "KLICK", style.color("amber"), 12)
		return
	# manual reload: hold down on the ground (not while L is held)
	if not busy() and player.is_on_floor() and Input.is_action_pressed("move_down") and not Input.is_action_pressed("special") and ammo < mag:
		_down_t += delta
		if _down_t >= _r("manual_reload_hold", 0.3):
			_down_t = 0.0
			start_reload()
	else:
		_down_t = 0.0


# --- shield / guard ------------------------------------------------------------

## Every hit that reaches the figure: the wall, then the shield.
func guard_hit(damage: float, from_x: float, source: Node) -> bool:
	_since_hit = 0.0
	if zug_id == "schildprotokoll" and _reserve and phase == "startup":
		interrupt()
	# the energy wall stands between the attacker and the figure
	if wall != null and is_instance_valid(wall) and wall.alive():
		var wx: float = wall.global_position.x
		if (from_x - wx) * (player.global_position.x - wx) < 0.0:
			var melee := source is Enemy
			wall.absorb(damage * (2.0 if melee else 1.0))
			return true
	if shield <= 0.0:
		return false
	shield -= damage
	_hex_k = 1.0
	var c := _center()
	if world.numbers != null:
		world.numbers.spawn_number(player.global_position + Vector2(0, -50), int(damage), style.color("shield"), player.get_instance_id(), false)
	bfx.zap(c + Vector2(signf(from_x - player.global_position.x) * 10.0, 0), 22.0, 3, style.color("shield"))
	if shield <= 0.0:
		shield = 0.0
		_broken_t = 1.2
		bfx.shards(c, -PI / 2.0, PI, 26, 220.0, style.color("shield"))
		bfx.burst(BollwerkFx.bw("schildbruch"), c, 90.0, 0.4)
		bfx.ring(c, 34.0, style.color("shield"), 0.4, 4.0)
		bfx.word(c + Vector2(0, -40), "SCHILD WEG!", Color("ff6a5a"), 20)
		world.fx.flash(0.2 * FxSettings.factor("flash"), Color(0.4, 0.7, 1.0))
		world.fx.shake(4.0 * FxSettings.factor("shake"))
		Sfx.play("bw_shield_break")
	else:
		Sfx.play("bw_shield_hit")
		player.sprite.flash = 0.03
	player.velocity.x = signf(player.global_position.x - from_x) * 60.0
	return true


## Prallstoß: in its perfect window a projectile flies back, a hit is
## caught. Notreserve: a hit breaks the activation (handled in guard_hit).
func try_counter(from_x: float, projectile: Node = null) -> bool:
	if zug_id != "schildprotokoll" or str(params.get("kind", "")) != "prall" or phase != "active":
		return false
	if t > float(params.get("perfect", 0.1)):
		return false
	invuln = 0.3
	var c := _center() + _fwd(12.0)
	bfx.ring(c, 30.0, style.color("plasma"), 0.35, 4.0)
	bfx.zap(c, 30.0, 5)
	bfx.word(c + Vector2(0, -40), "ABGELENKT!", style.color("white"), 22)
	world.fx.flash(0.18 * FxSettings.factor("flash"), Color(0.6, 1.0, 1.0))
	world.fx.freeze(0.08 * FxSettings.factor("stop"))
	player.add_gauge(12.0)
	if projectile != null and projectile.has_method("reflect"):
		projectile.reflect(player)
	elif projectile != null and projectile.has_method("burn"):
		projectile.burn()
	return true


# --- hits ---------------------------------------------------------------------

func on_zug_hit(zid: String, targets: Array) -> void:
	if targets.is_empty():
		return
	_missed = false
	player.add_gauge(5.0 if zid == zug_id and not _reported else 1.5)
	if zid == zug_id:
		_reported = true


func on_normal_hit() -> void:
	pass


func _deal(tg: Node2D, dmg: float, kb: float, profile := "", launch := 0.0, posture := 0.0, stoer := false) -> void:
	if stoer:
		tg.status["stoerung"] = 3.0
		posture *= 1.5
		bfx.zap(tg.get_hurt_rect().get_center(), 18.0, 2)
	world.deal_hit(tg, dmg, "", player.global_position.x, kb, profile, launch)
	if posture > 0.0 and tg.has_method("posture_hit"):
		tg.posture_hit(posture, player.global_position.x)


## Hits every target in the rect once per hit_set; returns them.
func _area(rect: Rect2, dmg: float, kb: float, profile := "", launch := 0.0, hit_set = null, posture := 0.0, stoer := false) -> Array:
	var out: Array = []
	for tg in world.get_tree().get_nodes_in_group("targets"):
		if hit_set != null and hit_set.has(tg.get_instance_id()):
			continue
		if rect.intersects(tg.get_hurt_rect()):
			if hit_set != null:
				hit_set[tg.get_instance_id()] = true
			_deal(tg, dmg, kb, profile, launch, posture, stoer)
			out.append(tg)
	on_zug_hit(zug_id, out)
	return out


func _radial(c: Vector2, r: float, dmg: float, kb: float, profile := "heavy", launch := 0.0, posture := 0.0, stoer := false, hit_set = null) -> Array:
	var out: Array = []
	for tg in world.get_tree().get_nodes_in_group("targets"):
		if hit_set != null and hit_set.has(tg.get_instance_id()):
			continue
		var hr: Rect2 = tg.get_hurt_rect()
		var nearest := Vector2(clampf(c.x, hr.position.x, hr.end.x), clampf(c.y, hr.position.y, hr.end.y))
		if nearest.distance_to(c) <= r:
			if hit_set != null:
				hit_set[tg.get_instance_id()] = true
			var dir := signf(hr.get_center().x - c.x)
			world.deal_hit(tg, dmg, "", hr.get_center().x - dir * 20.0, kb, profile, launch)
			if stoer:
				tg.status["stoerung"] = 3.0
			if posture > 0.0 and tg.has_method("posture_hit"):
				tg.posture_hit(posture * (1.5 if stoer else 1.0), c.x)
			out.append(tg)
	return out


## First target hit by a ray (or all of them with pierce). [[target, point], ...]
func _ray(a: Vector2, b: Vector2, pierce: bool) -> Array:
	var hits: Array = []
	for tg in world.get_tree().get_nodes_in_group("targets"):
		var hr: Rect2 = tg.get_hurt_rect()
		if hr.size == Vector2.ZERO:
			continue
		var d := _seg_rect(a, b, hr)
		if d >= 0.0:
			hits.append([d, tg])
	hits.sort_custom(func(x, y): return x[0] < y[0])
	var out: Array = []
	for h in hits:
		out.append([h[1], a.lerp(b, h[0])])
		if not pierce:
			break
	return out


## Fraction along a->b where the segment enters the rect, or -1.
static func _seg_rect(a: Vector2, b: Vector2, r: Rect2) -> float:
	if r.has_point(a):
		return 0.0
	var best := 2.0
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var p = Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4])
		if p != null:
			best = minf(best, a.distance_to(p) / maxf(0.001, a.distance_to(b)))
	return best if best <= 1.0 else -1.0


# --- Zug 1: Kontrollierte Salve --------------------------------------------------

func _on_start() -> void:
	match zug_id:
		"salve":
			var gap := _now - _last_salvo
			var step := float(params.get("spread_step", 3.0))
			if gap < 0.3:
				_spread = minf(float(params.get("spread_max", 12.0)), _spread + step)
			else:
				_spread = 1.0
			_last_salvo = _now
			_shots_fired = 0
			_shots_hit = 0
			var n := int(params.get("shots", 4))
			frames[1] = maxi(frames[1], int(ceil(float(params.get("every", 0.045)) * 60.0 * n)) + 1)
		"durchbruch":
			if str(params.get("kind", "")) == "klinge":
				if blade_cd > 0.0:
					params["kind"] = "kolben"
					params["damage"] = 10.4
					params["dist"] = 18
					params["stoer"] = false
					frames = [6, 6, 12]
				else:
					weapon_override = "fremdklinge"
		"orbitalsturz":
			var kind := str(params.get("kind", ""))
			if kind == "luftsalve":
				if player.is_on_floor():
					player.velocity.y = -330.0
			elif player.is_on_floor():
				params["kind"] = "boden"
				frames = [4, 4, 12]
			else:
				frames[0] = maxi(1, int(round(float(params.get("aim", 0.4)) * 60.0)))
			_land_x = player.global_position.x
		"schildprotokoll":
			_reserve = str(params.get("kind", "")) == "reserve"
			if _reserve:
				bfx.word(player.global_position + Vector2(0, -52), "NOTRESERVE…", style.color("shield"), 13)
		"kettenhaken":
			if str(params.get("kind", "")) == "schub":
				var dx := Input.get_axis("move_left", "move_right")
				var dy := Input.get_axis("move_up", "move_down")
				_push = Vector2(dx, dy)
				if _push == Vector2.ZERO:
					_push = Vector2(player.facing, 0)
				_push = _push.normalized()
				if dx != 0.0:
					player.facing = 1 if dx > 0.0 else -1
			else:
				_find_grab()


func _tick_salve() -> void:
	var n := int(params.get("shots", 4))
	var every := float(params.get("every", 0.045))
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
	elif phase == "active":
		var tilt := 0.0
		if Input.is_action_pressed("move_up"):
			tilt = -AIM_TILT
		elif Input.is_action_pressed("move_down"):
			tilt = AIM_TILT
		aim_deg = -tilt  # body: positive = muzzle up
		while _shots_fired < n and t >= _shots_fired * every:
			if ammo <= 0:
				break
			_fire_shot(tilt)
		if t >= _f(1) or (ammo <= 0 and _shots_fired < n and t >= _shots_fired * every):
			_end_salvo()
			_next_phase()
	elif phase == "recovery" and t >= _f(2):
		aim_deg = 0.0
		_next_phase()


func _fire_shot(tilt_deg: float) -> void:
	_shots_fired += 1
	ammo -= int(params.get("per_shot", 1))
	var spread := _spread
	if n_shots() >= 3 and _shots_fired == 1:
		spread *= 0.4  # the first bullet of a burst goes where you aim
	var ang := deg_to_rad(tilt_deg + randf_range(-spread, spread))
	var dir := Vector2(player.facing * cos(ang), sin(ang))
	var a := _muzzle()
	var range_px := float(params.get("range", 320))
	var b := a + dir * range_px
	var pierce: bool = params.get("pierce", false)
	var hits := _ray(a, b, pierce)
	var end := b
	if not hits.is_empty():
		end = hits.back()[1] if pierce else hits[0][1]
	bfx.tracer(a, end, style.color("amber"), 0.08, 1.4 if not pierce else 2.2)
	bfx.muzzle(a, dir.angle(), 7.0 if n_shots() > 1 else 9.0)
	world.fx.shake(0.8 * FxSettings.factor("shake"), player.facing)
	Sfx.play("bw_shot" if n_shots() > 1 else "bw_shot_heavy", -2.0 if n_shots() > 1 else -6.0)
	var dmg := float(params.get("damage", 2.4))
	for h in hits:
		var tg: Node2D = h[0]
		var mul := float(params.get("close_mul", 1.0)) if a.distance_to(h[1]) < 40.0 else 1.0
		_deal(tg, dmg * mul, 30.0, "light", 0.0, float(params.get("posture", 0.0)))
		bfx.shards(h[1], dir.angle() + PI, 0.6, 3, 120.0, style.color("gold"))
		bfx.glow(h[1], Color(style.color("amber"), 0.7), 6.0, 0.08)
	if not hits.is_empty():
		_shots_hit += 1
		on_zug_hit("salve", [hits[0][0]])
	if ammo <= 0:
		start_reload()


func n_shots() -> int:
	return int(params.get("shots", 4))


func _end_salvo() -> void:
	var n := n_shots()
	if n >= 3:
		if _shots_hit >= int(ceil(n * 0.75)):
			add_energy(1)
	else:
		_pistol_hits += _shots_hit
		while _pistol_hits >= 3:
			_pistol_hits -= 3
			add_energy(1)


# --- Zug 2: Bollwerk-Durchbruch ---------------------------------------------------

func _tick_durchbruch() -> void:
	var kind := str(params.get("kind", "kolben"))
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
			bfx.speedlines(_center(), 0.0 if player.facing > 0 else PI, 6, 34.0, style.color("white"))
			Sfx.play("swing_heavy")
			if kind == "klinge":
				blade_cd = float(params.get("blade_cd", 8.0))
				bfx.glow(_muzzle(), Color(style.color("plasma"), 0.8), 18.0, 0.2)
	elif phase == "active":
		var w := float(params.get("w", 40))
		var r := _rect_front(4, w, -40, 38)
		var posture := float(params.get("posture", 8.0)) * (float(params.get("posture_mul", 1.0)))
		var dmg := float(params.get("damage", 12.8))
		var kb := float(params.get("kb", 190)) + float(params.get("kb_add", 0))
		var targets: Array = []
		for tg in world.get_tree().get_nodes_in_group("targets"):
			if _hit_set.has(tg.get_instance_id()) or not r.intersects(tg.get_hurt_rect()):
				continue
			_hit_set[tg.get_instance_id()] = true
			var bonus := 1.0
			if tg is Enemy and tg.haltung >= tg.haltung_max() * 0.5:
				bonus = 1.5
			_deal(tg, dmg * bonus, kb, "heavy", 60.0 if kind == "schulter" else 0.0, posture, params.get("stoer", false))
			targets.append(tg)
		if not targets.is_empty():
			on_zug_hit(zug_id, targets)
			add_energy(1)
			var c: Vector2 = targets[0].get_hurt_rect().get_center()
			var word: String = {"kolben": "THUNK!", "schulter": "WUMM!", "klinge": "ZSSHH!"}.get(kind, "THUNK!")
			bfx.word(c + Vector2(0, -34), word, style.color("plasma") if kind == "klinge" else style.color("gold"), 22)
			bfx.ring(c, 22.0, style.color("plasma") if kind == "klinge" else style.color("amber"), 0.25, 3.0)
			bfx.burst(BollwerkFx.bw("plasmatreffer" if kind == "klinge" else "durchbruch"), c, 56.0, 0.25, randf() * TAU)
			world.fx.shake(4.0 * FxSettings.factor("shake"), player.facing)
			world.fx.freeze(0.05 * FxSettings.factor("stop"))
		if kind == "klinge" and _step == 0:
			_step = 1
			var m := _muzzle()
			bfx.arc(_center() + _fwd(6.0), 30.0, -0.9 if player.facing > 0 else PI + 0.9, 0.5 if player.facing > 0 else PI - 0.5, 8.0, style.color("plasma"), 0.22)
			bfx.glow(m, Color(style.color("plasma"), 0.9), 14.0, 0.15)
		if t >= _f(1):
			_next_phase()
	elif phase == "recovery":
		if t >= _f(2):
			weapon_override = ""
			_next_phase()


# --- Zug 3: Splitterwurf ------------------------------------------------------------

func _throw() -> void:
	grenades -= 1.0
	var n := 2 if _spent >= 3 else 1
	var hand := player.global_position + _fwd(8.0, -34.0)
	for i in n:
		var g := BollwerkGrenade.new()
		g.caster = self
		g.kind = str(params.get("kind", "splitter"))
		g.damage = float(params.get("damage", 16))
		g.radius = float(params.get("radius", 46)) * (1.0 + 0.2 * _spent) * float(params.get("radius_mul", 1.0))
		g.fuse = float(params.get("fuse", 1.2))
		g.zap_time = float(params.get("zap", 0.0))
		g.global_position = hand
		g.vel = Vector2(player.facing * (210.0 + i * 70.0), -300.0 + i * 40.0)
		world.attacks.add_child(g)
	bfx.word(hand + Vector2(0, -16), "HUP!", style.color("steel"), 14)
	Sfx.play("swing_light")


# --- Zug 4: Schildprotokoll ----------------------------------------------------------

func _tick_schild() -> void:
	var kind := str(params.get("kind", "wand"))
	if phase == "startup":
		if kind == "reserve":
			var k := t / maxf(0.01, _f(0))
			bfx.ring_in(_center(), 30.0, style.color("shield"), 0.1, 1.5)
			bfx.hex_shield(_center(), 0.3 + 0.6 * k)
		if t >= _f(0):
			_next_phase()
			match kind:
				"wand":
					_place_wall()
				"prall":
					_pulse()
				"reserve":
					_reserve = false
					var gain := shield_max * float(params.get("amount", 0.5))
					shield = minf(shield_max, shield + gain)
					_since_hit = _r("shield_delay", 3.5)  # starts refilling right away
					bfx.ring(_center(), 34.0, style.color("shield"), 0.4, 4.0)
					bfx.word(_center() + Vector2(0, -40), "SCHILD +%d %%" % int(params.get("amount", 0.5) * 100), style.color("shield"), 18)
					_hex_k = 1.0
					Sfx.play("bw_shield_hit")
	elif phase == "active":
		if kind == "prall":
			bfx.hex_shield(_center() + _fwd(8.0), 1.0 - t / maxf(0.01, _f(1)), style.color("plasma"))
		if t >= _f(1):
			_next_phase()
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


func _place_wall() -> void:
	if wall != null and is_instance_valid(wall):
		wall.collapse()
	var w := BollwerkWall.new()
	w.caster = self
	w.hp = float(params.get("hp", 300)) + float(params.get("hp_add", 0)) + 100.0 * _spent
	w.life = float(params.get("life", 6.0)) + float(params.get("life_add", 0))
	w.recharge = _spent >= 3
	w.dir = player.facing
	var x := player.global_position.x + player.facing * 22.0
	w.global_position = Vector2(x, GlutHazard.ground_y(x, player.global_position.y - 4.0))
	world.attacks.add_child(w)
	wall = w
	bfx.word(w.global_position + Vector2(0, -60), "WAND!", style.color("shield"), 18)
	Sfx.play("block")


func _pulse() -> void:
	var c := _center() + _fwd(10.0)
	bfx.ring(c, 46.0, style.color("plasma"), 0.3, 5.0)
	bfx.zap(c, 40.0, 6)
	bfx.word(c + Vector2(0, -34), "WUMP!", style.color("plasma"), 20)
	Sfx.play("bw_shield_hit", 4.0)
	_radial(c, 48.0, float(params.get("damage", 6.4)), 260.0, "heavy", 0.0, 6.0, true, {})
	world.fx.shake(3.0 * FxSettings.factor("shake"))


# --- Zug 5: Kettenhaken / Schubdüse ---------------------------------------------------

func _find_grab() -> void:
	var reach := float(params.get("grab", 210))
	var best_d := reach
	for tg in world.get_tree().get_nodes_in_group("targets"):
		var c: Vector2 = tg.get_hurt_rect().get_center()
		var dx: float = (c.x - player.global_position.x) * player.facing
		if dx < 10.0 or dx > reach or absf(c.y - (player.global_position.y - 22)) > 70.0:
			continue
		if dx < best_d:
			best_d = dx
			_grab = c
			_grab_target = tg
	if _grab_target != null:
		return
	# no enemy: an edge of a platform above / in front
	for pl in TrainingRoom.PLATFORMS:
		for ex in [pl[0], pl[0] + pl[2]]:
			var e := Vector2(ex, pl[1])
			var dx2: float = (e.x - player.global_position.x) * player.facing
			if dx2 > 0.0 and dx2 < reach and e.y < player.global_position.y - 10.0 and player.global_position.y - e.y < 160.0:
				if _grab == Vector2.INF or dx2 < (_grab.x - player.global_position.x) * player.facing:
					_grab = e


func _tick_haken() -> void:
	if str(params.get("kind", "")) == "schub":
		_tick_schub()
		return
	var hand := player.global_position + _fwd(8.0, -28.0)
	if phase == "startup":
		var aim := _grab if _grab != Vector2.INF else hand + _fwd(80.0, -10.0)
		_hook_tip = hand.lerp(aim, clampf(t / maxf(0.01, _f(0)), 0.0, 1.0))
		bfx.chain(hand, _hook_tip)
		if t >= _f(0):
			_next_phase()
			Sfx.play("bw_hook")
			if _grab == Vector2.INF:
				bfx.word(hand + _fwd(30, -14), "KLIRR", style.color("steel"), 12)
				phase = "recovery"
				t = 0.0
				player.velocity = Vector2(player.facing * 160.0, -180.0)
			else:
				bfx.glow(_grab, Color(style.color("amber"), 0.8), 10.0, 0.15)
				bfx.word(_grab + Vector2(0, -16), "TSCHAK", style.color("amber"), 14)
	elif phase == "active":
		if _grab_target != null and is_instance_valid(_grab_target):
			_grab = _grab_target.get_hurt_rect().get_center()
		bfx.chain(hand, _grab)
		if randf() < 0.5:
			bfx.speedlines(_center(), (_grab - _center()).angle() + PI, 2, 26.0, style.color("white"))
		if Input.is_action_just_pressed("special") and params.get("finisher", true):
			_follow = true
		var arrive := player.global_position.distance_to(_grab + Vector2(-player.facing * 14.0, 22.0)) < 18.0
		if arrive or t >= _f(1) or player.is_on_wall():
			_next_phase()
			if _grab_target != null and _follow and params.get("finisher", true):
				_hook_finisher()
			elif _grab_target == null:
				player.velocity = Vector2(player.facing * 60.0, -200.0)  # pull up onto the ledge
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


var _follow := false


func _hook_finisher() -> void:
	var dmg := float(params.get("damage", 11.2)) * (1.0 + 0.25 * _spent)
	var posture := float(params.get("posture", 6.0)) * float(params.get("posture_mul", 1.0))
	var hit := _area(_rect_front(-4, 34, -42, 40), dmg, 220.0, "heavy", 80.0, {}, posture)
	if not hit.is_empty():
		add_energy(1)
		var c: Vector2 = hit[0].get_hurt_rect().get_center()
		bfx.word(c + Vector2(0, -34), "KRAK!", style.color("gold"), 24)
		bfx.ring(c, 26.0, style.color("amber"), 0.3, 4.0)
		world.fx.shake(5.0 * FxSettings.factor("shake"), player.facing)
		world.fx.freeze(0.06 * FxSettings.factor("stop"))
		Sfx.play("hit_heavy")


func _tick_schub() -> void:
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
			invuln = 0.12
			bfx.glow(player.global_position + Vector2(0, -16) - _push * 10.0, Color(style.color("orange"), 0.9), 14.0, 0.2)
			bfx.word(player.global_position + Vector2(0, -50), "FSSHH", style.color("orange"), 14)
			Sfx.play("dash")
	elif phase == "active":
		if randf() < 0.6:
			bfx.glow(player.global_position + Vector2(0, -18) - _push * 12.0, Color(style.color("orange"), 0.7), 8.0, 0.15, -_push * 60.0)
			bfx.smoke(player.global_position + Vector2(0, -16) - _push * 14.0, 1, 3.0)
		if t >= _f(1):
			_next_phase()
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


# --- Zug 6: Orbitalsturz ------------------------------------------------------------

func _ground_below() -> Vector2:
	var x := player.global_position.x
	return Vector2(x, GlutHazard.ground_y(x, player.global_position.y))


func _tick_sturz() -> void:
	var kind := str(params.get("kind", "sturz"))
	if kind == "luftsalve":
		_tick_luftsalve()
		return
	if kind == "boden":
		_tick_simple(Callable(self, "_ground_slam"))
		return
	if phase == "startup":
		var k := clampf(t / maxf(0.01, _f(0)), 0.0, 1.0)
		bfx.marker(_ground_below() + Vector2(0, -2), k)
		bfx.aim_line(player.global_position + Vector2(0, -6), _ground_below(), k, style.color("olive"))
		if t >= _f(0):
			phase = "fall"
			t = 0.0
			_hit_set = {}
			bfx.word(player.global_position + Vector2(0, -50), "RUNTER!", style.color("gold"), 16)
			Sfx.play("dash", 2.0)
	elif phase == "fall":
		if randf() < 0.7:
			player.world.afterimages.add(player.sprite.snapshot(), Color(1.0, 0.7, 0.3, 0.45))
		bfx.marker(_ground_below() + Vector2(0, -2), 1.0)
		var r := Rect2(player.global_position + Vector2(-12, -30), Vector2(24, 32))
		_area(r, float(params.get("damage", 14.4)) * 0.4, 30.0, "light", -200.0, _hit_set)
		if player.is_on_floor() and t > 0.02:
			_impact()
			phase = "recovery"
			t = 0.0
			if _missed:
				frames[2] += int(float(params.get("whiff", 0.4)) * 60.0)
		elif t > 1.2:
			_next_phase()
	elif phase == "recovery" and t >= _f(2):
		_next_phase()


func _impact() -> void:
	var p := player.global_position
	var r := float(params.get("radius", 54)) * float(params.get("radius_mul", 1.0))
	var hit := _radial(p + Vector2(0, -10), r, float(params.get("damage", 14.4)), 200.0, "heavy", float(params.get("launch", 140)), float(params.get("posture", 0.0)), false, _hit_set)
	on_zug_hit(zug_id, hit)
	if not hit.is_empty():
		add_energy(1)
	bfx.burst(BollwerkFx.bw("staubstoss"), p + Vector2(0, -r * 0.9), r * 2.0, 0.4, 0.0, false, Color.WHITE, 0.7)
	bfx.ring(p + Vector2(0, -3), r, style.color("amber"), 0.35, 5.0)
	for i in 10:
		bfx.smoke(p + Vector2(randf_range(-r * 0.6, r * 0.6), -4), 1, 4.0)
	bfx.shards(p, -PI / 2.0, 1.2, 14, 260.0, style.color("steel"))
	bfx.word(p + Vector2(0, -60), "KRAK!", style.color("gold"), 30)
	world.dust.land(p, 1.0)
	world.fx.shake(7.0 * FxSettings.factor("shake"))
	world.fx.punch(0.04)
	world.fx.freeze(0.05 * FxSettings.factor("stop"))
	Sfx.play("bw_explosion", -6.0)


func _ground_slam() -> void:
	var p := player.global_position
	var hit := _radial(p + Vector2(0, -8), 30.0, float(params.get("damage", 14.4)) * 0.5, 160.0, "heavy", 0.0, 0.0, false, {})
	on_zug_hit(zug_id, hit)
	bfx.ring(p + Vector2(0, -3), 30.0, style.color("amber"), 0.3, 3.0)
	for i in 5:
		bfx.smoke(p + Vector2(randf_range(-14, 14), -4), 1, 3.0)
	bfx.word(p + Vector2(0, -46), "THUD", style.color("steel"), 16)
	world.dust.land(p, 0.7)
	world.fx.shake(3.0 * FxSettings.factor("shake"))


func _tick_luftsalve() -> void:
	if phase == "startup":
		if t >= _f(0):
			_next_phase()
	elif phase == "active":
		aim_deg = -40.0
		var every := 0.09
		while _step < 12 and t >= _step * every:
			_step += 1
			if ammo <= 0:
				break
			_fire_down()
		if t >= _f(1) or player.is_on_floor() or ammo <= 0:
			_next_phase()
	elif phase == "recovery" and t >= _f(2):
		aim_deg = 0.0
		_next_phase()


func _fire_down() -> void:
	ammo -= 1
	var ang := deg_to_rad(40.0 + randf_range(-4, 4))
	var dir := Vector2(player.facing * cos(ang), sin(ang))
	var a := _muzzle()
	var hits := _ray(a, a + dir * 260.0, false)
	var end := a + dir * 260.0
	if not hits.is_empty():
		end = hits[0][1]
		_deal(hits[0][0], 2.4, 20.0, "light")
		on_zug_hit(zug_id, [hits[0][0]])
		_shots_hit += 1
		if _shots_hit % 3 == 0:
			add_energy(1)
	else:
		var gy := GlutHazard.ground_y(end.x, a.y)
		if end.y > gy:
			end = a + dir * ((gy - a.y) / maxf(0.01, dir.y))
			bfx.glow(end, Color(style.color("amber"), 0.6), 5.0, 0.1)
	bfx.tracer(a, end)
	bfx.muzzle(a, dir.angle(), 7.0)
	Sfx.play("bw_shot", -3.0)
	if ammo <= 0:
		start_reload()


# --- movement & pose ------------------------------------------------------------------

func drive_velocity(v: Vector2, delta: float, on_floor: bool) -> Vector2:
	match zug_id:
		"durchbruch":
			if phase == "startup" or (phase == "active" and t < _f(1) * 0.5):
				var total := _f(0) + _f(1) * 0.5
				return Vector2(player.facing * float(params.get("dist", 34)) / maxf(0.05, total), minf(v.y + Player.GRAVITY * delta, Player.MAX_FALL))
		"kettenhaken":
			if str(params.get("kind", "")) == "schub":
				if phase == "active":
					return _push * float(params.get("dist", 120)) / maxf(0.05, _f(1))
				if phase == "recovery":
					return Vector2(move_toward(v.x, 0.0, 1800.0 * delta), minf(v.y + Player.GRAVITY * delta, Player.MAX_FALL))
				return Vector2(v.x * 0.5, v.y * 0.5)
			if phase == "active" and _grab != Vector2.INF:
				var goal := _grab + Vector2(-player.facing * 14.0, 22.0)
				var d := goal - player.global_position
				return d.normalized() * minf(560.0, d.length() / maxf(delta, 0.001))
			if phase == "startup":
				return Vector2(0.0, minf(v.y + Player.GRAVITY * delta * 0.3, 60.0))
		"orbitalsturz":
			match phase:
				"startup":
					if str(params.get("kind", "")) in ["sturz"]:
						var dx := Input.get_axis("move_left", "move_right")
						return Vector2(dx * 50.0, minf(v.y * 0.85 + 20.0 * delta, 30.0))
				"fall":
					return Vector2(0.0, 820.0)
				"active":
					if str(params.get("kind", "")) == "luftsalve":
						return Vector2(move_toward(v.x, -player.facing * 40.0, 400.0 * delta), minf(v.y + Player.GRAVITY * 0.35 * delta, 160.0))
		"schildprotokoll", "salve":
			var gx := move_toward(v.x, 0.0, (1800.0 if on_floor else 300.0) * delta)
			var g := Player.GRAVITY * delta * (0.4 if zug_id == "salve" and not on_floor else 1.0)
			return Vector2(gx, minf(v.y + g, Player.MAX_FALL))
	return super.drive_velocity(v, delta, on_floor)


func creator_pose() -> String:
	if not busy():
		return ""
	match zug_id:
		"salve":
			return "jab_hit" if player.is_on_floor() else "airpunch_hit"
		"durchbruch":
			var kind := str(params.get("kind", "kolben"))
			if phase == "startup":
				return "dash_0" if kind == "schulter" else "jab_wind"
			if phase == "active":
				return {"kolben": "hook_hit", "schulter": "dashpunch_hit", "klinge": "thrust_hit"}.get(kind, "hook_hit")
			return "cross_hit"
		"splitterwurf":
			return "cast_wind" if phase == "startup" else ("throw_0" if phase == "active" else "cast_hit")
		"schildprotokoll":
			var k := str(params.get("kind", "wand"))
			if k == "reserve":
				return "charge_0" if phase == "startup" else "win_0"
			if k == "prall":
				return "cast_hit" if phase != "startup" else "cast_wind"
			return "block_0" if phase == "startup" else "cast_hit"
		"kettenhaken":
			if str(params.get("kind", "")) == "schub":
				return "dash_0" if phase != "recovery" else "land_0"
			if phase == "startup":
				return "jab_hit"
			if phase == "active":
				return "airpunch_hit"
			return "hook_hit" if _follow else "land_0"
		"orbitalsturz":
			var k2 := str(params.get("kind", ""))
			if k2 == "luftsalve":
				return "airpunch_hit"
			if k2 == "boden":
				return "stomp_hit" if phase != "startup" else "land_0"
			if phase == "startup":
				return "djump_0"
			if phase == "fall":
				return "fall_1"
			return "stomp_hit" if t < 0.2 else "land_0"
	return ""
