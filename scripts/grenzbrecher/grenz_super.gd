class_name GrenzSuper
extends Node2D
## Meisterzug of Grenzbrecher (costs 3 Stufen of the Legendenleiste). Common
## intro: dust rises, little stones float, the aura flares, a manga cut-in on
## the eyes. Then one of three supers:
##  grenzbruch  a pillar of light to the top of the screen and a pressure
##              wave; then 10 s Grenzbruch rules (GrenzCaster.burst_time)
##  fernstrahl  visible charge with a blinking target mark (the dodge
##              window), teleport next to the target, point-blank Kernstrahl
##  sonnenkern  a mini sun grows over the raised fist (2.5 s; a hit breaks it
##              and refunds 2 Stufen), then it is thrown: huge area damage,
##              gold flash, white flash and a short slow motion
## The intro freezes the world; afterwards hit-stop applies.

const INTRO := 0.75
const SUN_PREP := 2.5

var room: TrainingRoom
var player: Player
var caster: GrenzCaster
var gfx: GrenzFx
var variant := "grenzbruch"
var title := "Meisterzug"

var phase := "intro"
var _t := 0.0
var _step := 0
var _target = null
var _dealt: Dictionary = {}
var _pose := 5
var _sun := Vector2.ZERO
var _sun_v := Vector2.ZERO
var _sun_r := 4.0
var _aborted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.z_index = CombatFx.FOCUS_Z
	player.sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	var cfx := room.fx
	cfx.hold(true)
	cfx.dim(0.85)
	cfx.punch(0.18)
	cfx.flash(0.25 * FxSettings.factor("flash"), Color(0.8, 0.92, 1.0))
	if room.hud != null:
		room.hud.show_cutin(title + "!", _c("sky"))
	_target = _nearest(400.0)
	if _target != null:
		player.facing = 1 if _target.global_position.x >= player.global_position.x else -1
	gfx.word(_center() + Vector2(0, -50), "HAAA!", _c("white"), 24)
	gfx.rocks(player.global_position, 10, 50.0)
	Sfx.play("super_flash")


# --- helpers -----------------------------------------------------------------------

func _c(k: String) -> Color:
	return caster.style.color(k)


func _center() -> Vector2:
	return player.global_position + Vector2(0, -20)


func _palm() -> Vector2:
	return player.global_position + _fwd(14.0, -24.0)


func _fwd(d: float, y := 0.0) -> Vector2:
	return Vector2(player.facing * d, y)


func _targets() -> Array:
	return room.get_tree().get_nodes_in_group("targets")


func _nearest(max_d: float):
	var best = null
	var best_d := max_d
	for t in _targets():
		var d: float = absf(t.global_position.x - player.global_position.x) + absf(t.global_position.y - player.global_position.y) * 0.5
		if d < best_d:
			best = t
			best_d = d
	return best


func _deal(t, dmg: float, kb: float, profile := "super", launch := 0.0) -> void:
	var dealt := room.deal_hit(t, dmg, "", player.global_position.x, kb, profile, launch)
	var id: int = t.get_instance_id()
	if not _dealt.has(id):
		_dealt[id] = [t, 0]
	_dealt[id][1] += dealt
	if t.has_method("posture_hit"):
		t.posture_hit(dmg * 2.0, player.global_position.x)
	player.on_attack_hit()


func _show_totals() -> void:
	for id in _dealt:
		var e: Array = _dealt[id]
		if is_instance_valid(e[0]) and e[1] > 0:
			room.numbers.spawn_number(e[0].head_position() + Vector2(0, -14), e[1], _c("gold"), id + 1, true)
	_dealt.clear()


func _set_pose(f: int) -> void:
	_pose = f
	player.sprite.scale.x = player.facing
	player.sprite.set_state("attack")
	player.sprite.attack_frame = f


func _next(p: String) -> void:
	phase = p
	_t = 0.0
	_step = 0


# --- main loop ------------------------------------------------------------------

func _process(delta: float) -> void:
	if _aborted:
		return
	if phase != "intro" and room.fx.is_frozen():
		return
	_t += delta
	match phase:
		"intro":
			_intro()
		"pillar":
			_pillar()
		"aim":
			_aim()
		"fire":
			_fire()
		"prep":
			_prep(delta)
		"throw":
			_throw(delta)
		"end":
			if _t >= 0.45:
				_finish()
	if phase != "end" or _t < 0.2:
		if phase != "prep":
			_set_pose(_pose)


func _intro() -> void:
	_set_pose(6 if _t < 0.4 else 1)
	gfx.aura(player.global_position, clampf(_t / INTRO, 0.2, 1.0), _c("sky"), 1.2)
	if randf() < 0.5:
		gfx.rocks(player.global_position, 1, 50.0)
	if _step == 0 and _t >= 0.4:
		_step = 1
		gfx.gburst("aura", player.global_position + Vector2(0, -30), 110.0, 0.4)
		gfx.ring(_center(), 60.0, _c("white"), 0.35, 4.0)
		room.fx.flash(0.3 * FxSettings.factor("flash"), Color(0.85, 0.95, 1.0))
		Sfx.play("hit_heavy")
	if _t >= INTRO:
		room.fx.hold(false)
		room.fx.dim(0.55)
		match variant:
			"fernstrahl":
				_next("aim")
			"sonnenkern":
				_begin_prep()
			_:
				_next("pillar")


func _finish() -> void:
	_show_totals()
	room.fx.dim(0.0)
	room.fx.hold(false)
	player.z_index = 0
	player.in_super = false
	player.sprite.process_mode = Node.PROCESS_MODE_INHERIT
	caster.sun_super = null
	queue_free()


# --- Grenzbruch ---------------------------------------------------------------------

func _pillar() -> void:
	_set_pose(5)
	var p := player.global_position
	gfx.aura(p, 1.0, _c("white"), 1.8)
	if _step == 0:
		_step = 1
		gfx.gburst("grenzbruch", p + Vector2(0, -90), 220.0, 0.8, 0.0, false, Color(1, 1, 1, 0.95), 0.6)
		gfx.gburst("schockring", p + Vector2(0, -16), 200.0, 0.5)
		for i in 3:
			gfx.ring(p + Vector2(0, -16), 60.0 + i * 40.0, [_c("white"), _c("sky"), _c("blue")][i], 0.45 + i * 0.1, 6.0)
		gfx.word(p + Vector2(0, -96), "GRENZBRUCH!", _c("white"), 34)
		gfx.rocks(p, 16, 70.0)
		room.fx.flash(0.5 * FxSettings.factor("flash"), Color(0.85, 0.95, 1.0))
		room.fx.shake(10.0 * FxSettings.factor("shake"))
		room.fx.freeze(0.1 * FxSettings.factor("stop"))
		Sfx.play("break", 4.0)
		for tg in _targets():
			if tg.get_hurt_rect().get_center().distance_to(_center()) < 100.0:
				_deal(tg, 12.0, 260.0, "super_final", 160.0)
		caster.burst_time = GrenzCaster.BURST_TIME
		caster.add_ki(30.0)
	if _t >= 0.5:
		room.fx.dim(0.0)
		_next("end")


# --- Fernstrahl -----------------------------------------------------------------------

func _aim() -> void:
	_set_pose(1)
	var k := clampf(_t / 0.8, 0.0, 1.0)
	gfx.aura(player.global_position, 0.6 + 0.4 * k, _c("sky"))
	gfx.orb(player.global_position + _fwd(-4.0, -27.0), 4.0 + 8.0 * k, _c("sky"))
	if _target != null and is_instance_valid(_target):
		gfx.mark(_target.get_hurt_rect().get_center(), k)
		gfx.beam(player.global_position + _fwd(0, -26), _target.get_hurt_rect().get_center(), 1.5, 0.4, _c("gold"))
	if _step == 0 and _t > 0.2:
		_step = 1
		gfx.word(_center() + Vector2(0, -60), "ZIEL ERFASST", _c("gold"), 18)
	if _t >= 0.8:
		# teleport next to the target
		var from := player.global_position
		if _target != null and is_instance_valid(_target):
			var tp: Vector2 = _target.global_position
			var side := signf(from.x - tp.x)
			if side == 0.0:
				side = -player.facing
			player.global_position = Vector2(clampf(tp.x + side * 50.0, 12.0, TrainingRoom.WIDTH - 12.0), from.y)
			player.facing = 1 if tp.x >= player.global_position.x else -1
		room.afterimages.add(player.sprite.snapshot(), Color(0.7, 1.2, 1.8, 0.7))
		gfx.gburst("fernschritt", from + Vector2(0, -20), 90.0, 0.35)
		gfx.gburst("fernschritt", _center(), 100.0, 0.35)
		gfx.word(_center() + Vector2(0, -56), "ZWOOM", _c("sky"), 18)
		Sfx.play("dash", 4.0)
		_next("fire")


func _fire() -> void:
	_set_pose(3)
	var palm := _palm()
	var end := palm + _fwd(360.0)
	var k := clampf(_t / 0.06, 0.0, 1.0)
	gfx.beam(palm, palm.lerp(end, k), 34.0, 1.0)
	if randf() < 0.7:
		gfx.shards(palm, 0.0 if player.facing > 0 else PI, 0.8, 3, 300.0, _c("pale"))
	if _step == 0:
		_step = 1
		gfx.gburst("kern", palm, 140.0, 0.4)
		gfx.word(palm + Vector2(0, -50), "FERNSTRAHL!", _c("white"), 34)
		room.fx.flash(0.55 * FxSettings.factor("flash"), Color(0.9, 0.97, 1.0))
		room.fx.punch(0.08)
		Sfx.play("break", 4.0)
	var rect := Rect2(minf(palm.x, end.x), palm.y - 24, absf(end.x - palm.x), 48)
	# 8 ticks, then the final blow
	var due := mini(8, int(_t / 0.6 * 8.0))
	while _step - 1 < due:
		_step += 1
		for tg in _targets():
			if rect.intersects(tg.get_hurt_rect()):
				_deal(tg, 5.0, 30.0, "super", 0.0)
		room.fx.shake(4.0 * FxSettings.factor("shake"), player.facing)
	if _t >= 0.65:
		for tg in _targets():
			if rect.intersects(tg.get_hurt_rect()):
				_deal(tg, 24.0, 420.0, "super_final", 200.0)
				gfx.gburst("schockring", tg.get_hurt_rect().get_center(), 150.0, 0.45)
		gfx.gburst("einschlag", end + _fwd(-60), 200.0, 0.5)
		room.fx.flash(0.4 * FxSettings.factor("flash"), Color(1, 1, 1))
		room.fx.shake(12.0 * FxSettings.factor("shake"), player.facing)
		room.fx.freeze(0.14 * FxSettings.factor("stop"))
		room.fx.dim(0.2)
		_pose = 3
		_next("end")


# --- Sonnenkern -----------------------------------------------------------------------

func _begin_prep() -> void:
	_next("prep")
	room.fx.dim(0.35)
	# the figure is open while the sun grows: a hit breaks it (GrenzCaster.interrupt)
	player.in_super = false
	caster.zug_id = "sonnenkern_prep"
	caster.phase = "active"
	caster.t = 0.0
	caster._decided = true
	caster.sun_super = self
	_sun_r = 4.0


func _prep(delta: float) -> void:
	var k := clampf(_t / SUN_PREP, 0.0, 1.0)
	var fist := player.global_position + _fwd(2.0, -46.0)
	_sun = fist + Vector2(0, -10.0 - 34.0 * k)
	_sun_r = lerpf(4.0, 30.0, k * k * (3.0 - 2.0 * k))
	gfx.orb(_sun, _sun_r, _c("gold"), true)
	gfx.aura(player.global_position, 0.5 + 0.5 * k, _c("gold").lerp(_c("sky"), 0.5))
	# dust and stones rise into the sun
	if randf() < 0.7:
		var from := player.global_position + Vector2(randf_range(-90, 90), randf_range(-4, 0))
		gfx.glow(from, Color(_c("gold"), 0.7), 3.0, 0.5, (_sun - from) * 1.8)
	if randf() < 0.4:
		gfx.rocks(player.global_position, 1, 80.0)
	if fmod(_t, 0.5) < delta:
		room.fx.shake((1.0 + 4.0 * k) * FxSettings.factor("shake"))
		gfx.ring(_sun, _sun_r * 1.6, Color(_c("gold"), 0.7), 0.4, 2.0)
	if _step == 0 and _t > 0.3:
		_step = 1
		gfx.word(_sun + Vector2(0, -40), "SONNENKERN…", _c("gold"), 18)
	if _t >= SUN_PREP:
		caster.zug_id = ""
		caster.phase = ""
		caster.sun_super = null
		player.in_super = true
		_sun_v = Vector2(player.facing * 300.0, 170.0)
		gfx.word(_sun + Vector2(0, -50), "NIMM DAS!", _c("white"), 26)
		room.fx.flash(0.3 * FxSettings.factor("flash"), Color(1.0, 0.92, 0.6))
		Sfx.play("swing_heavy", 4.0)
		_pose = 3
		_next("throw")


## A hit broke the charge: the sun fizzles, 2 Stufen come back.
func abort() -> void:
	if phase != "prep" or _aborted:
		return
	_aborted = true
	gfx.ring(_sun, _sun_r * 2.0, _c("gold"), 0.4, 3.0)
	gfx.shards(_sun, -PI / 2.0, 3.0, 14, 200.0, _c("gold"))
	gfx.word(_sun + Vector2(0, -30), "ZERPLATZT", _c("orange"), 16)
	player.add_gauge(200.0)
	room.fx.dim(0.0)
	room.fx.hold(false)
	player.z_index = 0
	player.in_super = false
	player.sprite.process_mode = Node.PROCESS_MODE_INHERIT
	caster.sun_super = null
	queue_free()


func _throw(delta: float) -> void:
	_set_pose(3)
	_sun += _sun_v * delta
	_sun_v.y += 200.0 * delta
	gfx.orb(_sun, _sun_r, _c("gold"), true)
	if randf() < 0.8:
		gfx.glow(_sun - _sun_v.normalized() * _sun_r, Color(_c("orange"), 0.5), _sun_r * 0.8, 0.3)
	var hit := false
	for tg in _targets():
		if tg.get_hurt_rect().grow(_sun_r * 0.6).has_point(_sun):
			hit = true
	var gy := GlutHazard.ground_y(_sun.x, _sun.y - _sun_r)
	if hit or _sun.y + _sun_r * 0.5 >= gy or _t > 1.6:
		_explode()


func _explode() -> void:
	var c := _sun
	gfx.gburst("einschlag", c + Vector2(0, -20), 320.0, 0.7)
	gfx.gburst("sonnenkern", c, 260.0, 0.55, 0.0, false, Color(1, 1, 1, 0.9), 0.8)
	gfx.gburst("schockring", c, 280.0, 0.55)
	for i in 4:
		gfx.ring(c, 80.0 + i * 45.0, [_c("white"), _c("gold"), _c("orange"), _c("sky")][i], 0.5 + i * 0.1, 7.0)
	gfx.shards(c, -PI / 2.0, 3.0, 30, 420.0, _c("gold"))
	gfx.rocks(Vector2(c.x, GlutHazard.ground_y(c.x, c.y - 30.0)), 20, 110.0)
	gfx.word(c + Vector2(0, -110), "KRAAAASH!", _c("white"), 40)
	for tg in _targets():
		if tg.get_hurt_rect().get_center().distance_to(c) < 120.0:
			_deal(tg, 96.0, 380.0, "super_final", 260.0)
	room.fx.flash(0.65 * FxSettings.factor("flash"), Color(1.0, 0.9, 0.55))
	room.fx.shake(16.0 * FxSettings.factor("shake"))
	room.fx.freeze(0.16 * FxSettings.factor("stop"))
	room.fx.punch(0.1)
	room._slowmo(0.3, 0.35)
	room.dust.land(Vector2(c.x, GlutHazard.ground_y(c.x, c.y - 30.0)), 1.0)
	Sfx.play("break", 6.0)
	room.fx.dim(0.15)
	_pose = 3
	_next("end")
