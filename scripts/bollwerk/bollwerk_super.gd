class_name BollwerkSuper
extends Node2D
## Meisterzug of Bollwerk (3 Stufen of the Legendenleiste). Common intro: the
## camera leans in, the amber visor glints and a green reticle locks onto the
## target (manga cut-in). Then one of three supers:
##  zwillingsrohr   Doppelabschuss: kneel with the twin rocket tube, aim two
##                  rockets with up/down (36 each, big area)
##  lanzenstrahl    1 s aim line, then a beam pierces everything on the line
##                  (72, Schildstörung, +30 % against elites)
##  letzter_befehl  hook, heavy blow, shotgun from point blank (88 in total);
##                  if the hook misses, 2 Stufen come back (costs only 1)
## The intro freezes the world; afterwards hit-stop applies.

const INTRO := 0.8
const ROCKET_SPEED := 520.0

var room: TrainingRoom
var player: Player
var caster: BollwerkCaster
var bfx: BollwerkFx
var variant := "zwillingsrohr"
var title := "Meisterzug"

var phase := "intro"
var _t := 0.0
var _step := 0
var _target: Node2D = null
var _dealt: Dictionary = {}
var _pose := "idle_0"
var _aim := 0.0  # degrees, positive = up
var _rockets: Array = []  # {pos, vel, life}
var _fired := 0
var _hook_tip := Vector2.ZERO
var _from := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.z_index = CombatFx.FOCUS_Z
	player.sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	var cfx := room.fx
	cfx.hold(true)
	cfx.dim(0.85)
	cfx.punch(0.2)
	cfx.flash(0.22 * FxSettings.factor("flash"), Color(1.0, 0.85, 0.5))
	if room.hud != null:
		room.hud.show_cutin(title + "!", _c("amber"))
	_target = _nearest(420.0)
	if _target != null:
		player.facing = 1 if _target.global_position.x >= player.global_position.x else -1
	var weapon := str(caster.style.variant().get("weapon", "zwillingsrohr"))
	caster.weapon_override = weapon
	caster.aim_deg = 0.0
	Sfx.play("bw_charge")


# --- helpers -----------------------------------------------------------------------

func _c(k: String) -> Color:
	return caster.style.color(k)


func _center() -> Vector2:
	return player.global_position + Vector2(0, -22)


func _helmet() -> Vector2:
	return player.global_position + Vector2(player.facing * 3.0, -38.0)


func _fwd(d: float, y := 0.0) -> Vector2:
	return Vector2(player.facing * d, y)


func _muzzle() -> Vector2:
	return caster._muzzle()


func _targets() -> Array:
	return room.get_tree().get_nodes_in_group("targets")


func _nearest(max_d: float, front_only := false) -> Node2D:
	var best: Node2D = null
	var best_d := max_d
	for tg in _targets():
		var dx: float = tg.global_position.x - player.global_position.x
		if front_only and dx * player.facing < 0.0:
			continue
		var d: float = absf(dx) + absf(tg.global_position.y - player.global_position.y) * 0.5
		if d < best_d:
			best = tg
			best_d = d
	return best


func _deal(tg: Node2D, dmg: float, kb: float, profile := "super", launch := 0.0, stoer := false) -> void:
	if stoer:
		tg.status["stoerung"] = 3.0
		if tg.has_method("posture_hit"):
			tg.posture_hit(12.0, player.global_position.x)
	var dealt := room.deal_hit(tg, dmg, "", player.global_position.x, kb, profile, launch)
	var id := tg.get_instance_id()
	if not _dealt.has(id):
		_dealt[id] = [tg, 0]
	_dealt[id][1] += dealt
	player.on_attack_hit()


func _show_totals() -> void:
	for id in _dealt:
		var e: Array = _dealt[id]
		if is_instance_valid(e[0]) and e[1] > 0 and room.numbers != null:
			room.numbers.spawn_number(e[0].head_position() + Vector2(0, -14), e[1], _c("gold"), id + 1, true)
	_dealt.clear()


func _set_pose(p: String) -> void:
	_pose = p
	player.sprite.scale.x = player.facing
	player.sprite.set_state("attack")
	player.sprite.attack_pose = p


func _next(p: String) -> void:
	phase = p
	_t = 0.0
	_step = 0


func _aim_input(speed: float, lo: float, hi: float) -> void:
	var d := 0.0
	if player.ctl.is_action_pressed("move_up"):
		d = 1.0
	elif player.ctl.is_action_pressed("move_down"):
		d = -1.0
	_aim = clampf(_aim + d * speed * get_process_delta_time(), lo, hi)
	caster.aim_deg = _aim


func _aim_dir() -> Vector2:
	var a := deg_to_rad(_aim)
	return Vector2(player.facing * cos(a), -sin(a))


## Auto aim: tilt the barrel towards the locked target (the player can correct).
func _auto_aim() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var d: Vector2 = _target.get_hurt_rect().get_center() - (player.global_position + Vector2(0, -26))
	if absf(d.x) < 60.0:
		return
	_aim = clampf(rad_to_deg(atan2(-d.y, absf(d.x))), -15.0, 15.0)
	caster.aim_deg = _aim


# --- main loop ------------------------------------------------------------------

func _process(delta: float) -> void:
	if phase != "intro" and room.fx.is_frozen():
		return
	_t += delta
	_update_rockets(delta)
	match phase:
		"intro":
			_intro()
		"kneel":
			_kneel()
		"aim":
			_beam_aim()
		"beam":
			_beam_fire()
		"hook":
			_hook()
		"pull":
			_pull()
		"blow":
			_blow()
		"shotgun":
			_shotgun()
		"end":
			if _t >= 0.45 and _rockets.is_empty():
				_finish()
	if phase != "end" or _t < 0.25:
		_set_pose(_pose)


func _intro() -> void:
	_set_pose("idle_0" if _t < 0.3 else "cast_wind")
	if _step == 0 and _t >= 0.18:
		_step = 1
		bfx.glint(_helmet() + _fwd(3.0), 18.0)
		bfx.word(_center() + Vector2(0, -50), "ZIEL ERFASST", _c("olive"), 16)
		Sfx.play("bw_reload")
	if _target != null and is_instance_valid(_target):
		var k := clampf(_t / INTRO, 0.0, 1.0)
		var tc: Vector2 = _target.get_hurt_rect().get_center()
		bfx.marker(tc, 1.0 - k * 0.5 + 0.2, _c("olive"))
		bfx.ring_in(tc, 26.0 - k * 12.0, _c("olive"), 0.06, 1.5)
	if _t >= INTRO:
		room.fx.hold(false)
		room.fx.dim(0.55)
		match variant:
			"lanzenstrahl":
				_next("aim")
				Sfx.play("bw_charge")
			"letzter_befehl":
				_next("hook")
			_:
				_next("kneel")


func _finish() -> void:
	_show_totals()
	room.fx.dim(0.0)
	room.fx.hold(false)
	caster.weapon_override = ""
	caster.aim_deg = 0.0
	player.z_index = 0
	player.in_super = false
	player.sprite.process_mode = Node.PROCESS_MODE_INHERIT
	queue_free()


# --- Zwillingsrohr: Doppelabschuss -------------------------------------------------

func _kneel() -> void:
	_pose = "charge_0"
	if _step == 0:
		_step = 1
		_auto_aim()
		bfx.smoke(player.global_position + Vector2(0, -2), 3, 8.0)
		room.dust.land(player.global_position, 0.6)
	_aim_input(45.0, -35.0, 40.0)
	var tip := _muzzle()
	bfx.aim_line(tip, tip + _aim_dir() * 240.0, 0.5 + 0.5 * sin(_t * 18.0), _c("olive"))
	if (_fired == 0 and _t >= 0.55) or (_fired == 1 and _t >= 0.5):
		_fire_rocket()
		_t = 0.0
		if _fired >= 2:
			_next("end")
			_pose = "cast_hit"


func _fire_rocket() -> void:
	_fired += 1
	var tip := _muzzle()
	var dir := _aim_dir()
	_rockets.append({"pos": tip, "vel": dir * ROCKET_SPEED, "life": 1.4})
	bfx.muzzle(tip, dir.angle(), 18.0, _c("orange"))
	bfx.smoke(tip - dir * 18.0, 4, 6.0)  # back blast
	bfx.glow(tip - dir * 22.0, Color(_c("orange"), 0.8), 18.0, 0.2)
	bfx.word(tip + Vector2(0, -20), "FWOOSH!", _c("orange"), 20)
	room.fx.shake(4.0 * FxSettings.factor("shake"), player.facing)
	Sfx.play("bw_shot_heavy")
	player.global_position.x -= player.facing * 6.0  # recoil


func _update_rockets(delta: float) -> void:
	if _rockets.is_empty():
		return
	var keep: Array = []
	for r in _rockets:
		var prev: Vector2 = r.pos
		r.pos = prev + r.vel * delta
		r.life -= delta
		bfx.tracer(prev - r.vel.normalized() * 10.0, r.pos, _c("orange"), 0.12, 3.0)
		if randf() < 0.7:
			bfx.smoke(prev, 1, 2.0)
		var boom: bool = r.life <= 0.0 or r.pos.x < 0.0 or r.pos.x > TrainingRoom.WIDTH
		if r.pos.y >= GlutHazard.ground_y(r.pos.x, prev.y - 2.0):
			boom = true
		for tg in _targets():
			if tg.get_hurt_rect().grow(4.0).has_point(r.pos):
				boom = true
				break
		if boom:
			_rocket_boom(r.pos)
		else:
			keep.append(r)
	_rockets = keep


func _rocket_boom(p: Vector2) -> void:
	var radius := 70.0
	for tg in _targets():
		var hr: Rect2 = tg.get_hurt_rect()
		var nearest := Vector2(clampf(p.x, hr.position.x, hr.end.x), clampf(p.y, hr.position.y, hr.end.y))
		if nearest.distance_to(p) <= radius:
			_deal(tg, 36.0, 260.0, "super_final", 200.0)
	bfx.explosion(p, radius)
	bfx.ring(p, radius * 1.2, _c("gold"), 0.45, 5.0)
	bfx.word(p + Vector2(0, -50), "KA-WUMM!", _c("orange"), 32)
	room.fx.shake(8.0 * FxSettings.factor("shake"))
	room.fx.flash(0.3 * FxSettings.factor("flash"), Color(1.0, 0.7, 0.35))
	room.fx.freeze(0.07 * FxSettings.factor("stop"))
	Sfx.play("bw_explosion", 2.0)


# --- Lanzenstrahl --------------------------------------------------------------------

func _beam_aim() -> void:
	_pose = "thrust_hit"
	if _step == 0:
		_step = 1
		_auto_aim()
	_aim_input(25.0, -30.0, 30.0)
	var tip := _muzzle()
	var k := clampf(_t / 1.0, 0.0, 1.0)
	bfx.aim_line(tip, tip + _aim_dir() * 900.0, 0.3 + 0.7 * k * (0.6 + 0.4 * sin(_t * 30.0)), _c("plasma"))
	bfx.ring_in(tip, 18.0 - k * 10.0, _c("plasma"), 0.05, 1.5)
	bfx.glow(tip, Color(_c("plasma"), 0.4 + 0.5 * k), 6.0 + 10.0 * k, 0.05)
	if _t >= 1.0:
		_next("beam")
		_fire_beam()


func _fire_beam() -> void:
	var tip := _muzzle()
	var end := tip + _aim_dir() * 900.0
	for h in caster._ray(tip, end, true):
		var tg: Node2D = h[0]
		var mul := 1.3 if tg is Enemy and tg.is_elite() else 1.0
		_deal(tg, 72.0 * mul, 320.0, "super_final", 120.0, true)
		bfx.zap(h[1], 26.0, 5)
		bfx.burst(BollwerkFx.bw("plasmatreffer"), h[1], 70.0, 0.35)
	bfx.word(tip + _fwd(60.0, -30.0), "VSCHHHHH!", _c("plasma"), 30)
	room.fx.flash(0.45 * FxSettings.factor("flash"), Color(0.6, 1.0, 1.0))
	room.fx.shake(7.0 * FxSettings.factor("shake"), player.facing)
	room.fx.freeze(0.08 * FxSettings.factor("stop"))
	Sfx.play("bw_beam", 3.0)
	player.global_position.x -= player.facing * 10.0


func _beam_fire() -> void:
	_pose = "thrust_hit"
	var tip := _muzzle()
	var end := tip + _aim_dir() * 900.0
	var k := 1.0 - clampf(_t / 0.45, 0.0, 1.0)
	bfx.beam(tip, end, 3.0 + 12.0 * k, _c("plasma"))
	if _t >= 0.45:
		_pose = "cast_hit"
		_next("end")


# --- Letzter Befehl -------------------------------------------------------------------

func _hook() -> void:
	_pose = "jab_hit"
	if _step == 0:
		_step = 1
		_target = _nearest(260.0, true)
		_from = player.global_position + _fwd(8.0, -28.0)
		Sfx.play("bw_hook")
	var goal := _from + _fwd(240.0, -8.0)
	if _target != null and is_instance_valid(_target):
		goal = _target.get_hurt_rect().get_center()
	_hook_tip = _from.lerp(goal, clampf(_t / 0.18, 0.0, 1.0))
	bfx.chain(player.global_position + _fwd(8.0, -28.0), _hook_tip)
	if _t >= 0.18:
		if _target == null or not is_instance_valid(_target):
			# missed: only one Stufe is spent
			player.gauge = minf(player.gauge + 200.0, 300.0)
			bfx.word(_hook_tip + Vector2(0, -16), "DANEBEN", _c("steel"), 16)
			bfx.word(_center() + Vector2(0, -50), "+2 STUFEN ZURÜCK", _c("gold"), 13)
			_pose = "idle_0"
			_next("end")
		else:
			bfx.word(_hook_tip + Vector2(0, -16), "TSCHAK!", _c("amber"), 18)
			_next("pull")


func _pull() -> void:
	_pose = "airpunch_hit"
	if not is_instance_valid(_target):
		_next("end")
		return
	var goal: Vector2 = Vector2(_target.global_position.x - player.facing * 20.0, player.global_position.y)
	bfx.chain(player.global_position + _fwd(8.0, -28.0), _target.get_hurt_rect().get_center())
	bfx.speedlines(_center(), 0.0 if player.facing < 0 else PI, 2, 30.0, _c("white"))
	if randf() < 0.6:
		room.afterimages.add(player.sprite.snapshot(), Color(1.0, 0.7, 0.3, 0.4))
	player.global_position.x = move_toward(player.global_position.x, goal.x, 900.0 * get_process_delta_time())
	if absf(player.global_position.x - goal.x) < 2.0 or _t > 0.4:
		_next("blow")


func _blow() -> void:
	_pose = "hook_hit"
	if _step == 0:
		_step = 1
		if is_instance_valid(_target):
			_deal(_target, 30.0, 40.0, "super", 0.0)
			var c: Vector2 = _target.get_hurt_rect().get_center()
			bfx.word(c + Vector2(0, -40), "KRACK!", _c("gold"), 26)
			bfx.ring(c, 26.0, _c("amber"), 0.3, 4.0)
		room.fx.shake(5.0 * FxSettings.factor("shake"))
		room.fx.freeze(0.06 * FxSettings.factor("stop"))
		Sfx.play("hit_heavy")
		caster.weapon_override = "schrotflinte"
	if _t >= 0.28:
		_next("shotgun")


func _shotgun() -> void:
	_pose = "thrust_hit"
	if _step == 0:
		_step = 1
		var tip := _muzzle()
		for i in 7:
			var a := deg_to_rad(randf_range(-9.0, 9.0))
			var dir := Vector2(player.facing * cos(a), sin(a))
			bfx.tracer(tip, tip + dir * 90.0, _c("gold"), 0.1, 1.8)
		bfx.muzzle(tip, 0.0 if player.facing > 0 else PI, 24.0, _c("orange"))
		bfx.burst(BollwerkFx.bw("schrotladung"), tip + _fwd(34.0), 90.0, 0.3, 0.0, player.facing < 0)
		bfx.smoke(tip, 4, 6.0)
		if is_instance_valid(_target):
			_deal(_target, 58.0, 380.0, "super_final", 160.0)
			var c: Vector2 = _target.get_hurt_rect().get_center()
			bfx.shards(c, 0.0 if player.facing > 0 else PI, 0.7, 14, 260.0, _c("gold"))
			bfx.word(c + Vector2(0, -50), "BLAMM!", _c("orange"), 36)
		room.fx.flash(0.35 * FxSettings.factor("flash"), Color(1.0, 0.8, 0.4))
		room.fx.shake(8.0 * FxSettings.factor("shake"), player.facing)
		room.fx.freeze(0.08 * FxSettings.factor("stop"))
		Sfx.play("bw_shot_heavy", 4.0)
		player.global_position.x -= player.facing * 14.0
	if _t >= 0.4:
		_pose = "win_0"
		_next("end")
