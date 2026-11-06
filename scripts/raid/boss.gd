class_name Boss
extends Enemy
## A raid boss (Kampf-Endgame doc, "Raids und Bosse"). Builds on Enemy (look,
## HP bar, burning, death show) and adds:
##
##  Wucht-Leiste  super armour: hits do not stagger or push the boss, they
##                drain its Wucht instead (heavy hits, Druckbruch and
##                Perfekt-Blocks drain more). Empty = BRUCH: the boss reels
##                for BRUCH_TIME, takes +50 % damage and can be juggled.
##                During its big attacks the bar is locked (only dodging helps).
##  Schild-Phasen at 70 % and 35 % HP the boss turns invulnerable and calls
##                shield crystals onto the platforms. All crystals broken in
##                time = instant Bruch; too slow = Essensturm, a fire flood
##                over the whole floor (stand on a platform).
##  Attacks       Hammerschlag (front smash + two ground shockwaves to jump
##                over), Glutschwung (wide swing), Glutregen (marked ember
##                rain), Ansturm (charge across the arena, phase 2 and 3).
##
## Strength scales with the player count (RaidScaling).

signal phase_changed(phase: int)
signal shield_started
signal shield_ended(broken: bool)

const BRUCH_TIME := 4.0
const BRUCH_DAMAGE := 1.5
const SHIELD_AT := [0.7, 0.35]
const ARENA := Vector2(150.0, 980.0)  # the boss stays on the lower floor

var director: RaidDirector
## Tower guards are smaller versions: less Wucht, fewer shield phases.
var wucht_mult := 1.0
var shield_at: Array = SHIELD_AT.duplicate()
var wucht := 0.0
var wucht_max := 260.0
var wucht_locked := false
var bruch := 0.0
var bruch_count := 0
var phase := 1  # 1, 2, 3 (after each shield)
var shielded := false
var shield_left := 0.0
var crystals: Array = []
var attack := ""  # current attack id
var _next_shield := 0
var _wucht_shown := 1.0
var _shield_word_cd := 0.0
var _last_attack := ""
var _rain_left := 0
var _rain_t := 0.0
var _charge_dir := 1.0


func _ready() -> void:
	super._ready()
	max_hp = float(data.hp) * RaidScaling.hp_factor() * hp_mult
	hp = max_hp
	wucht_max = float(data.get("wucht", 260.0)) * RaidScaling.wucht_factor() * wucht_mult
	wucht = wucht_max
	_wucht_shown = 1.0
	_cd = 1.6
	add_to_group("bosses")


## Counts as elite (loot, EXP orbs), except while broken: then it reels
## and can be juggled like a normal enemy.
func is_elite() -> bool:
	return bruch <= 0.0


func weight() -> float:
	return 3.0 if bruch <= 0.0 else 1.6


func _dmg() -> float:
	return float(data.damage) * dmg_mult


func is_broken() -> bool:
	return bruch > 0.0


## Damage multiplier for TrainingRoom.deal_hit: nothing through the shield,
## +50 % while broken.
func damage_factor() -> float:
	if shielded:
		return 0.0
	return BRUCH_DAMAGE if bruch > 0.0 else 1.0


# --- target interface -------------------------------------------------------------

func take_hit(knockback: float, from_x: float) -> void:
	if state == "dead":
		return
	if state == "sleep":
		director._wake()
		return
	_hp_shown = 3.0
	if shielded:
		flash = 0.04
		_shield_word_cd -= 1.0
		if _shield_word_cd <= 0.0 and world.glut_fx != null:
			_shield_word_cd = 4.0
			world.glut_fx.word(head_position() + Vector2(0, -16), "SCHILD!", Color("ffd25c"), 16)
		world.effects.ring(get_hurt_rect().get_center(), 30.0, Color(1.0, 0.8, 0.35))
		return
	if bruch > 0.0:
		super.take_hit(knockback, from_x)  # reels, can be juggled
		return
	flash = 0.07
	_squash = Vector2(0.96, 1.04)
	if not wucht_locked:
		drain_wucht(5.0 + knockback * 0.09)


## Wucht damage from any source (hits, Druckbruch, Perfekt-Block).
func drain_wucht(amount: float) -> void:
	if wucht_locked or bruch > 0.0 or shielded or state == "dead":
		return
	wucht = maxf(0.0, wucht - amount)
	if wucht <= 0.0:
		_break()


func set_hitstun(seconds: float) -> void:
	if bruch > 0.0:
		super.set_hitstun(seconds)


func posture_hit(amount: float, _from_x: float) -> bool:
	var before := bruch
	drain_wucht(amount * 2.0)
	return before <= 0.0 and bruch > 0.0


func parried(from_x: float) -> void:
	if state == "dead":
		return
	flash = 0.15
	if world.glut_fx != null:
		world.glut_fx.word(head_position() + Vector2(0, -10), "ABGEPRALLT!", Color("ffd25c"), 14)
	if wucht_locked:
		return
	drain_wucht(45.0)
	if bruch <= 0.0 and state in ["windup", "strike"]:
		_end_attack(0.9)  # the blow is knocked aside, the boss resets
		vel.x = signf(global_position.x - from_x) * 60.0


func launch(speed: float) -> void:
	if bruch > 0.0:
		super.launch(speed * 0.8)


func apply_damage(amount: float) -> void:
	if shielded or state == "dead":
		return
	hp = maxf(0.0, hp - amount)
	_hp_shown = 3.0
	if _next_shield < shield_at.size() and hp <= max_hp * float(shield_at[_next_shield]):
		hp = max_hp * float(shield_at[_next_shield])
		_start_shield()
		return
	if hp <= 0.0:
		_die()


func _die() -> void:
	bruch = 0.0
	shielded = false
	wucht_locked = false
	super._die()
	director.boss_defeated(self)


## The big bar lives in the HUD (RaidBossBar); over the boss only its statuses.
func _draw_overlay() -> void:
	if state == "dead":
		return
	var x := -16.0
	var top: float = -float(data.hurt.y) - 18.0
	for key in status.keys():
		var c: Color = GameData.STATUS[key].color
		_overlay.draw_rect(Rect2(Vector2(x, top), Vector2(7, 7)), Color("1a1020"))
		_overlay.draw_rect(Rect2(Vector2(x + 1, top + 1), Vector2(5, 5)), c)
		x += 9.0


# --- Bruch ---------------------------------------------------------------------------

func _break() -> void:
	bruch = BRUCH_TIME
	bruch_count += 1
	wucht = 0.0
	attack = ""
	wucht_locked = false
	_enter("hurt")
	_stun = 0.6
	_play("hurt", true)
	flash = 0.25
	vel = Vector2(-facing * 90.0, -120.0)
	on_ground = false
	world.fx.shake(7.0)
	world.fx.flash(0.3, Color("fff4d0"))
	world.fx.punch(0.16)
	world.effects.burst(get_hurt_rect().get_center(), Color("ffb347"), 30, 220.0, 200.0)
	world.effects.ring(get_hurt_rect().get_center(), 70.0, Color("fff4d0"))
	Sfx.play("super_flash", -2.0)
	Sfx.play("hit_heavy")
	if world.glut_fx != null:
		world.glut_fx.word(head_position() + Vector2(0, -24), "BRUCH!", Color("fff4d0"), 34)
	world.toast("Bruch! +50 % Schaden, jetzt kombinieren")
	if world.stage != null:
		world.stage.flash_light(get_hurt_rect().get_center(), Color(1.0, 0.85, 0.5), 2.2, 1.4, 0.5)


func _end_bruch() -> void:
	bruch = 0.0
	# every further Bruch needs a little more Wucht
	wucht_max *= 1.12
	wucht = wucht_max
	_enter("idle")
	_cd = 0.8
	world.effects.ring(get_hurt_rect().get_center(), 50.0, Color(1.0, 0.55, 0.25))
	if world.glut_fx != null:
		world.glut_fx.word(head_position() + Vector2(0, -16), "WUCHT ZURÜCK", Color("ff9a2a"), 14)


# --- shield phases ---------------------------------------------------------------------

func _start_shield() -> void:
	_next_shield += 1
	shielded = true
	shield_left = RaidScaling.shield_time()
	attack = ""
	wucht_locked = false
	bruch = 0.0
	status.clear()
	_enter("shield")
	_play("roar", true)
	vel = Vector2.ZERO
	world.fx.shake(6.0)
	world.fx.flash(0.25, Color(1.0, 0.75, 0.35))
	Sfx.play("super_flash", -4.0)
	if world.glut_fx != null:
		world.glut_fx.word(head_position() + Vector2(0, -30), "GLUTSCHILD!", Color("ffd25c"), 30)
	world.toast("Glutschild! Zerstöre die Kristalle in %d Sekunden" % int(shield_left))
	crystals.clear()
	var spots: Array = director.crystal_spots(RaidScaling.crystals())
	for i in spots.size():
		var c := ShieldCrystal.new()
		c.world = world
		c.boss = self
		c.position = spots[i]
		c.delay = 0.4 + 0.25 * i
		world.add_enemy(c)
		crystals.append(c)
	shield_started.emit()


func crystal_broken(c: ShieldCrystal) -> void:
	crystals.erase(c)
	if world.glut_fx != null:
		world.glut_fx.word(c.global_position + Vector2(0, -40), "%d ÜBRIG" % crystals.size() if crystals.size() > 0 else "SCHILD BRICHT!", Color("ffd25c"), 18)
	if crystals.is_empty() and shielded:
		_end_shield(true)


func _end_shield(broken: bool) -> void:
	shielded = false
	for c in crystals:
		if is_instance_valid(c):
			c.vanish()
	crystals.clear()
	phase += 1
	phase_changed.emit(phase)
	shield_ended.emit(broken)
	if broken:
		_break()
	else:
		_enter("idle")
		_cd = 0.6
		_begin("essensturm")


# --- behaviour ---------------------------------------------------------------------------

func _think(delta: float) -> void:
	_shield_word_cd = maxf(0.0, _shield_word_cd - delta)
	_wucht_shown = move_toward(_wucht_shown, wucht / wucht_max, delta * 1.5)
	var p: Node2D = world.player
	var dx := p.global_position.x - global_position.x
	if bruch > 0.0:
		bruch -= delta
		if bruch <= 0.0:
			_end_bruch()
		elif state == "hurt" and _st > _stun and on_ground:
			_enter("dazed")
		elif state == "dazed":
			vel.x = move_toward(vel.x, 0.0, 400.0 * delta)
			_squash = Vector2(1.0 + sin(_t * 9.0) * 0.03, 1.0 - sin(_t * 9.0) * 0.03)
			if world.glut_fx != null and randf() < 0.15:
				world.glut_fx.glow(head_position() + Vector2(randf_range(-14, 14), 4), Color(1.6, 1.4, 0.6), 3.0, 0.5, Vector2(0, -30))
		return
	if state == "spawn":
		if _st > 1.2:
			_enter("idle")
		return
	if state == "shield":
		shield_left -= delta
		vel.x = move_toward(vel.x, 0.0, 500.0 * delta)
		if _st > 0.9 and _anim == "roar":
			_play("idle")
		if shield_left <= 0.0:
			_end_shield(false)
		return
	match state:
		"idle", "move":
			_cd -= delta
			facing = 1 if dx > 0.0 else -1
			var dist := absf(dx)
			if _cd <= 0.0:
				_begin(_pick_attack(dist))
				return
			if dist > 90.0:
				if state != "move":
					_enter("move")
				vel.x = facing * float(data.speed)
			elif state != "idle":
				_enter("idle")
		"windup", "strike", "recover":
			_attack_tick(delta, p)


func _pick_attack(dist: float) -> String:
	var options: Array = []
	if dist < 140.0:
		options += ["slam", "swipe", "swipe"]
	else:
		options += ["slam", "rain"]
	if dist >= 140.0 and phase >= 2:
		options += ["charge", "charge"]
	if phase >= 3:
		options += ["rain"]
	# no attack twice in a row when there is a choice
	var fresh := options.filter(func(o): return o != _last_attack)
	if not fresh.is_empty():
		options = fresh
	return options[randi() % options.size()]


func _begin(id: String) -> void:
	attack = id
	_last_attack = id
	_enter("windup")
	vel.x = 0.0
	match id:
		"slam":
			_play("slam", true)
		"swipe":
			_play("swipe", true)
		"rain", "essensturm":
			wucht_locked = true
			_play("roar", true)
			if world.glut_fx != null:
				world.glut_fx.word(head_position() + Vector2(0, -26), "GLUTREGEN!" if id == "rain" else "ESSENSTURM!", Color("ff7a2a"), 24 if id == "rain" else 30)
			if id == "essensturm":
				world.toast("Essensturm! Rauf auf eine Plattform!")
		"charge":
			wucht_locked = true
			_play("walk", true)
			_charge_dir = float(facing)
			if world.glut_fx != null:
				world.glut_fx.word(head_position() + Vector2(0, -26), "ANSTURM!", Color("ff7a2a"), 24)


## Wind-up time per attack (seconds); a bit faster in later phases.
func _windup_time() -> float:
	var t: float = {"slam": 0.95, "swipe": 0.62, "rain": 1.0, "charge": 0.8, "essensturm": 1.6}.get(attack, 0.8)
	return t * (1.0 - 0.08 * (phase - 1))


func _attack_tick(delta: float, p: Node2D) -> void:
	match state:
		"windup":
			vel.x = move_toward(vel.x, 0.0, 600.0 * delta)
			if attack == "charge":
				_squash = Vector2(1.08, 0.92)
				if randf() < 0.4:
					world.dust.puff(global_position, -facing, 1)
			if _st >= _windup_time():
				_enter("strike")
				_strike_begin(p)
		"strike":
			_strike_tick(delta, p)
		"recover":
			vel.x = move_toward(vel.x, 0.0, 500.0 * delta)
			if _st > 0.0:
				_enter("idle")


func _strike_begin(_p: Node2D) -> void:
	_anim_t = float(_hit_frame(_anim)) / _fps(_anim)  # jump to the blow
	match attack:
		"slam":
			var impact := global_position + Vector2(facing * 54.0, 0)
			var r := Rect2(global_position.x + (0.0 if facing > 0 else -110.0), global_position.y - 90.0, 110.0, 90.0)
			_hit_box(r, _dmg() * 1.3)
			world.dust.land(impact, 2.4)
			world.effects.burst(impact + Vector2(0, -4), Color("ffb347"), 26, 200.0, 420.0)
			world.fx.shake(8.0, facing)
			Sfx.play("hit_heavy", -2.0)
			if world.glut_fx != null:
				world.glut_fx.word(impact + Vector2(0, -50), "KRAWUMM!", Color("ffd25c"), 26)
				for i in 8:
					world.glut_fx.flame(impact + Vector2(randf_range(-30, 30), -2), randf_range(6, 12), Vector2(randf_range(-60, 60), -120), 0.5)
			if world.stage != null:
				world.stage.flash_light(impact + Vector2(0, -20), Color(1.0, 0.55, 0.25), 2.0, 1.0, 0.4)
			for dir in [-1.0, 1.0]:
				director.spawn_hazard("wave", impact + Vector2(dir * 20.0, 0), dir, _dmg() * 0.8)
		"swipe":
			var r := Rect2(global_position.x + (-30.0 if facing > 0 else -110.0), global_position.y - 100.0, 140.0, 100.0)
			_hit_box(r, _dmg())
			Sfx.play("swing_heavy", -2.0)
			world.fx.shake(4.0, facing)
			if world.glut_fx != null:
				var c := global_position + Vector2(facing * 50.0, -50.0)
				for i in 10:
					var a := -1.2 + 2.4 * float(i) / 9.0
					world.glut_fx.flame(c + Vector2(cos(a) * 50.0 * facing, sin(a) * 45.0), 7.0, Vector2(facing * 80.0, 0), 0.3)
		"rain":
			_rain_left = 5 + phase + RaidScaling.players - 1
			_rain_t = 0.0
		"essensturm":
			director.spawn_hazard("flood", Vector2(0, TrainingRoom.GROUND_Y), 1.0, _dmg() * 1.6)
			world.fx.shake(10.0)
			world.fx.flash(0.35, Color(1.0, 0.5, 0.2))
			Sfx.play("super_flash")
		"charge":
			vel.x = _charge_dir * 520.0
			_play("walk", true)
			Sfx.play("dash", -2.0)


func _strike_tick(delta: float, p: Node2D) -> void:
	match attack:
		"slam", "swipe":
			if _st > 0.5:
				_end_attack(1.2)
		"rain":
			_rain_t -= delta
			if _rain_left > 0 and _rain_t <= 0.0:
				_rain_t = 0.32
				_rain_left -= 1
				# aimed at the player first, then scattered around them
				var x := p.global_position.x + (0.0 if _rain_left % 3 == 0 else randf_range(-170, 170))
				x = clampf(x, 40.0, TrainingRoom.WIDTH - 40.0)
				director.spawn_hazard("marker", Vector2(x, GlutHazard.ground_y(x, p.global_position.y - 4.0)), 1.0, _dmg() * 0.9)
			if _rain_left <= 0 and _st > 1.2:
				_end_attack(1.0)
		"essensturm":
			if _st > 2.6:
				_end_attack(1.4)
		"charge":
			vel.x = _charge_dir * 520.0
			_anim_t += delta  # stomps faster
			if randf() < 0.6:
				world.dust.puff(global_position, -_charge_dir, 2)
			var s: Vector2 = data.hurt
			_hit_box(Rect2(global_position + Vector2(-s.x * 0.6, -s.y), Vector2(s.x * 1.2, s.y)), _dmg() * 1.1)
			var at_wall := (_charge_dir > 0.0 and global_position.x >= ARENA.y - 4.0) or (_charge_dir < 0.0 and global_position.x <= ARENA.x + 4.0)
			if at_wall or _st > 2.2:
				vel.x = -_charge_dir * 80.0
				world.fx.shake(7.0, _charge_dir)
				world.dust.land(global_position + Vector2(_charge_dir * 30.0, 0), 2.0)
				Sfx.play("hit_heavy", -4.0)
				_end_attack(1.3)


func _end_attack(pause: float) -> void:
	attack = ""
	wucht_locked = false
	_enter("recover")
	_st = -0.45
	_play("idle")
	_cd = pause * randf_range(0.85, 1.15) * (1.0 - 0.1 * (phase - 1))


func _hit_box(r: Rect2, damage: float) -> void:
	debug_rect = r
	debug_rect_t = 0.15
	_hit_decoys(r)
	var p := world.player
	if r.intersects(p.get_hurt_rect()):
		p.receive_hit(damage, global_position.x, self)


func _move(delta: float) -> void:
	super._move(delta)
	global_position.x = clampf(global_position.x, ARENA.x, ARENA.y)


func _enter(s: String) -> void:
	super._enter(s)
	match s:
		"dazed":
			_play("hurt", false)
		"move":
			_play("walk")


# --- look ---------------------------------------------------------------------------------

func _strip_len(anim: String) -> int:
	return int(look.anims[anim][0]) if look.anims.has(anim) else 1


## Frame of the blow in an attack strip (third value in frames.json).
func _hit_frame(anim: String) -> int:
	var a: Array = look.anims.get(anim, [])
	return int(a[2]) if a.size() > 2 else _strip_len(anim) / 2


func _fps(anim: String) -> float:
	return float(look.anims[anim][1]) if look.anims.has(anim) else 8.0


func _animate() -> void:
	if not look.anims.has(_anim):
		return
	var n := _strip_len(_anim)
	var f := int(_anim_t * _fps(_anim))
	match _anim:
		"hurt", "death":
			f = mini(f, n - 1)
		"slam", "swipe", "roar":
			var hit := maxi(1, _hit_frame(_anim))
			if state == "windup":
				f = mini(int(_st / maxf(_windup_time(), 0.01) * hit), hit - 1)
			else:
				f = mini(f, n - 1)
		_:
			f = f % n
	if state == "dazed":
		f = n - 1 if _anim == "hurt" else f
	sprite.frame = f
	sprite.flip_h = facing > 0  # the boss art faces left
	var cell: Array = look.cell
	var foot: float = look.foot
	var sc: Vector2 = _squash * float(data.get("scale", 1.0))
	sprite.scale = sc
	sprite.position = Vector2(-float(cell[0]) * 0.5 * sc.x, -foot * sc.y)
	var tint := Color.WHITE
	if state == "windup":
		var pulse := 0.5 + 0.5 * sin(_st * 26.0)
		tint = Color(1.0 + pulse * 0.8, 1.0 - pulse * 0.2, 1.0 - pulse * 0.3)
	if shielded:
		tint = tint * Color(1.25, 1.1, 0.75)
	if bruch > 0.0:
		tint = tint * Color(1.1, 1.1, 1.2)
	if status.has("brand"):
		tint = tint * Color(1.15, 0.92, 0.85)
	if flash > 0.0:
		tint = Color(3.0, 3.0, 3.0)
	sprite.modulate = tint


func _draw() -> void:
	if state == "dead":
		return
	var c := get_hurt_rect().get_center() - global_position
	if shielded:
		# a hexagon dome of glowing glass around the boss
		var r := 78.0 + sin(_t * 3.0) * 2.0
		var pts := PackedVector2Array()
		for i in 7:
			var a := TAU * float(i) / 6.0 + _t * 0.4
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, Color(1.0, 0.75, 0.3, 0.12))
		draw_polyline(pts, Color(1.8, 1.3, 0.5, 0.75), 2.0)
		for i in 6:
			draw_line(c, pts[i], Color(1.6, 1.1, 0.4, 0.15), 1.0)
	if wucht_locked and state != "dead":
		# red rim: the Wucht-Leiste is locked, dodge!
		draw_arc(c, 62.0, 0.0, TAU, 32, Color(1.6, 0.25, 0.15, 0.35 + 0.25 * sin(_t * 20.0)), 2.0)
