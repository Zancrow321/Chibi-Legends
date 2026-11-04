class_name FeuerSuper
extends Node2D
## Meisterzug of Lauffeuer (3 Stufen of the Legendenleiste). Common intro:
## the world darkens, fire climbs up the figure and lights it from below,
## behind it the silhouette of a signal tower flares up. Then one of three:
##  grosser_brand  a giant Flammenfaust rolls through a wide corridor and
##                 ignites every Brandherd in it (domino chain)
##  brandgestirn   fire gathers above the figure into a huge crusted ball
##                 (long, clearly visible wind-up and target circle), thrown
##                 into the target area: huge impact, short burning ground
##  leuchtfeuer    eight Zunderflocken rise in the target area and ignite
##                 together after 1.5 s; flakes at Brandherde make them erupt
## The intro freezes the world; afterwards everything runs normally.

const INTRO := 0.85
const ORANGE := Color("ff8a2a")
const GOLD := Color("ffc94a")
const WHITE := Color("fff3c8")

var room: TrainingRoom
var player: Player
var caster: FeuerCaster
var variant := "grosser_brand"
var title := "Meisterzug"

var phase := "intro"
var _t := 0.0
var _step := 0
var _target_pos := Vector2.ZERO
var _dealt: Dictionary = {}
var _ball: FeuerStrip
var _fist: FeuerStrip
var _flakes: Array = []
var _tower_glow := 0.0
var _pose := "charge_0"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = CombatFx.FOCUS_Z - 1
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	player.z_index = CombatFx.FOCUS_Z
	player.sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	var cfx := room.fx
	cfx.hold(true)
	cfx.dim(0.85)
	cfx.punch(0.16)
	cfx.flash(0.25 * FxSettings.factor("flash"), Color(1.0, 0.7, 0.35))
	if room.hud != null:
		room.hud.show_cutin(title + "!", ORANGE)
	var tg := _nearest(420.0)
	if tg != null:
		player.facing = 1 if tg.global_position.x >= player.global_position.x else -1
		_target_pos = Vector2(tg.global_position.x, _ground(tg.global_position.x, tg.global_position.y))
	else:
		var x := player.global_position.x + player.facing * 170.0
		_target_pos = Vector2(x, _ground(x, player.global_position.y))
	Sfx.play("super_flash")
	Sfx.play("lauf_super", -2.0)


# --- helpers -------------------------------------------------------------------------

func _center() -> Vector2:
	return player.global_position + Vector2(0, -22)


func _hand() -> Vector2:
	return player.global_position + Vector2(player.facing * 12.0, -30.0)


func _ground(x: float, from_y: float) -> float:
	var gy := GlutHazard.ground_y(x, from_y - 4.0)
	return gy if gy < 9000.0 else from_y


func _targets() -> Array:
	return room.get_tree().get_nodes_in_group("targets")


func _nearest(max_d: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_d
	for t in _targets():
		var d: float = absf(t.global_position.x - player.global_position.x) + absf(t.global_position.y - player.global_position.y) * 0.5
		if d < best_d:
			best = t
			best_d = d
	return best


func _deal(t: Node2D, dmg: float, kb: float, profile := "super", launch := 0.0) -> void:
	var dealt := room.deal_hit(t, dmg, "feuer", player.global_position.x, kb, profile, launch)
	var id := t.get_instance_id()
	if not _dealt.has(id):
		_dealt[id] = [t, 0]
	_dealt[id][1] += dealt
	player.on_attack_hit()


func _show_totals() -> void:
	for id in _dealt:
		var e: Array = _dealt[id]
		if is_instance_valid(e[0]) and e[1] > 0:
			room.numbers.spawn_number(e[0].head_position() + Vector2(0, -14), e[1], GOLD, id + 1, true)
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


func _fx() -> GlutFx:
	return caster.fx


# --- main loop ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if phase != "intro" and room.fx.is_frozen():
		queue_redraw()
		return
	_t += delta
	_tower_glow = maxf(0.0, _tower_glow - delta * 0.8)
	match phase:
		"intro":
			_intro(delta)
		"brand_wind":
			_brand_wind()
		"brand_roll":
			_brand_roll(delta)
		"ball_grow":
			_ball_grow(delta)
		"ball_fly":
			_ball_fly(delta)
		"flakes":
			_flakes_rise(delta)
		"end":
			if _t >= 0.6:
				_finish()
	_set_pose(_pose)
	queue_redraw()


func _intro(delta: float) -> void:
	_set_pose("charge_0" if _t < 0.5 else "super_0")
	var k := clampf(_t / INTRO, 0.0, 1.0)
	_tower_glow = k
	if fmod(_t, 0.04) < delta:
		var p := player.global_position + Vector2(randf_range(-10, 10), -randf_range(0, 40) * k)
		_fx().flame(p, 6.0 + 6.0 * k, Vector2(0, -90), 0.35, 1.0)
	_fx().light(player.global_position + Vector2(0, -6), Color(1.0, 0.55, 0.25), 1.5 + 2.5 * k, 0.9, 0.05)
	if _step == 0 and _t >= 0.5:
		_step = 1
		_fx().ring(_center(), 60.0, GOLD, 0.45, 5.0)
		_fx().word(_center() + Vector2(0, -70), "FWOOSH!", GOLD, 30)
		room.fx.flash(0.35 * FxSettings.factor("flash"), Color(1.0, 0.75, 0.4))
		room.fx.shake(5.0 * FxSettings.factor("shake"))
	if _t >= INTRO:
		room.fx.hold(false)
		room.fx.dim(0.55)
		match variant:
			"brandgestirn":
				_next("ball_grow")
				_ball = FeuerStrip.spawn(room.attacks, "brandgestirn", player.global_position + Vector2(0, -90), {"size": 0.3, "hdr": 1.4, "loop": true})
				_ball.z_index = 6
			"leuchtfeuer":
				_next("flakes")
				_spawn_flakes()
			_:
				_next("brand_wind")


func _finish() -> void:
	_show_totals()
	room.fx.dim(0.0)
	room.fx.hold(false)
	player.z_index = 0
	player.in_super = false
	player.sprite.process_mode = Node.PROCESS_MODE_INHERIT
	if _ball != null and is_instance_valid(_ball):
		_ball.queue_free()
	queue_free()


# --- Großer Brand ---------------------------------------------------------------------------

func _brand_wind() -> void:
	_set_pose("charge_0")
	if fmod(_t, 0.03) < get_process_delta_time():
		_fx().flame(_hand() + Vector2(randf_range(-5, 5), 0), 10.0, Vector2(0, -70), 0.3)
	if _t >= 0.3:
		_next("brand_roll")
		_pose = "cross_hit"
		_fist = FeuerStrip.spawn(room.attacks, "flammenfaust", _hand() + Vector2(player.facing * 40.0, -10), {"size": 3.6, "hdr": 1.5, "flip": player.facing < 0, "frame_override": 2})
		_fist.z_index = 6
		_fx().word(_center() + Vector2(player.facing * 60.0, -80), "GROSSER BRAND!", WHITE, 30)
		room.fx.shake(10.0 * FxSettings.factor("shake"), player.facing)
		room.fx.punch(0.1)
		room.fx.flash(0.4 * FxSettings.factor("flash"), Color(1.0, 0.65, 0.3))
		Sfx.play("swing_heavy", 4.0)


func _brand_roll(delta: float) -> void:
	_set_pose("cross_hit")
	var speed := 640.0
	_fist.position.x += player.facing * speed * delta
	_fist.frame_override = clampi(2 + int(_t * 14.0), 2, 8)
	var p := _fist.position
	_fx().light(p, Color(1.0, 0.6, 0.3), 3.5, 1.4, 0.05)
	if fmod(_t, 0.025) < delta:
		_fx().flame(p - Vector2(player.facing * 90.0, randf_range(-30, 30)), 16.0, Vector2(-player.facing * 120.0, -40), 0.4)
		_fx().embers(p, 3, 40.0, 60.0, 0.8)
	var corridor := Rect2(minf(p.x, p.x - player.facing * 100.0) - 60.0, p.y - 70.0, 220.0, 140.0)
	for tg in _targets():
		if _dealt.has(tg.get_instance_id()):
			continue
		if corridor.intersects(tg.get_hurt_rect()):
			_deal(tg, 64.0, 260.0, "super_final", 220.0)
			_fx().anvil(tg.get_hurt_rect().get_center(), 26.0, 12)
			room.fx.freeze(0.06 * FxSettings.factor("stop"))
	var n := 0
	for h in caster.herde.duplicate():
		if is_instance_valid(h) and absf(h.global_position.x - p.x) < 110.0:
			h.ignite(1.6, 0.08 * n)
			n += 1
	if _t >= 0.75:
		FeuerStrip.spawn(room.attacks, "einschlag", p, {"size": 2.2, "hdr": 1.5})
		_fx().sparks(p, 0.0 if player.facing > 0 else PI, 1.2, 40, 400.0, 0.8)
		_fist.queue_free()
		room.fx.dim(0.25)
		_next("end")


# --- Brandgestirn ---------------------------------------------------------------------------

func _ball_grow(delta: float) -> void:
	_set_pose("super_0")
	var k := clampf(_t / 1.2, 0.0, 1.0)
	_ball.size = lerpf(0.3, 1.5, k * k * (3.0 - 2.0 * k))
	_ball.position = player.global_position + Vector2(0, -60 - 60.0 * _ball.size)
	room.fx.dim(0.55 + 0.35 * k)
	_tower_glow = maxf(_tower_glow, k)
	# fire from all around streams into the ball
	if fmod(_t, 0.03) < delta:
		var a := randf() * TAU
		var from := _ball.position + Vector2(cos(a), sin(a)) * randf_range(120, 220)
		_fx().flame(from, 7.0, (_ball.position - from) * 2.2, 0.45, 0.9)
	_fx().light(_ball.position, Color(1.0, 0.6, 0.3), 2.0 + 3.0 * k, 1.6, 0.05)
	if _t >= 1.2:
		_next("ball_fly")
		_pose = "throw_0"
		_fx().word(_ball.position + Vector2(0, -80), "BRANDGESTIRN!", WHITE, 30)
		Sfx.play("swing_heavy", 4.0)


func _ball_fly(delta: float) -> void:
	_set_pose("throw_0")
	var start := player.global_position + Vector2(0, -150)
	var k := clampf(_t / 0.45, 0.0, 1.0)
	var p := start.lerp(_target_pos + Vector2(0, -20), k * k)
	p.y -= sin(k * PI) * 40.0
	_ball.position = p
	if k >= 1.0:
		_ball.queue_free()
		_ball = null
		_impact(_target_pos)
		_next("end")


func _impact(p: Vector2) -> void:
	FeuerStrip.spawn(room.attacks, "einschlag", p + Vector2(0, 30), {"anchor": "bottom", "size": 3.0, "hdr": 1.6})
	room.fx.flash(0.8 * FxSettings.factor("flash"), Color(1.0, 0.95, 0.8))
	room.fx.shake(14.0 * FxSettings.factor("shake"))
	room.fx.punch(0.14)
	room.fx.freeze(0.12 * FxSettings.factor("stop"))
	room.fx.dim(0.2)
	_fx().ring(p + Vector2(0, -10), 120.0, GOLD, 0.5, 8.0)
	_fx().ring(p + Vector2(0, -10), 70.0, WHITE, 0.35, 5.0)
	_fx().fountain(p, 50, 420.0)
	_fx().word(p + Vector2(0, -140), "BOOM!", WHITE, 40)
	_fx().light(p + Vector2(0, -40), Color(1.0, 0.8, 0.5), 5.0, 2.2, 0.6)
	for i in 10:
		_fx().smoke(p + Vector2(randf_range(-60, 60), -10), randf_range(14, 24), Vector2(randf_range(-30, 30), -30), 2.0)
	Sfx.play("hit_heavy", 6.0)
	for tg in _targets():
		if tg.get_hurt_rect().get_center().distance_to(p + Vector2(0, -20)) < 120.0:
			_deal(tg, 90.0, 300.0, "super_final", 280.0)
	for h in caster.herde.duplicate():
		if is_instance_valid(h) and absf(h.global_position.x - p.x) < 140.0:
			h.ignite(1.4, 0.15)
	caster.burning_ground(p, 3.0, 60.0)


# --- Leuchtfeuer -------------------------------------------------------------------------------

func _spawn_flakes() -> void:
	for i in 8:
		var off := Vector2(randf_range(-110, 110), -randf_range(20, 110))
		var f := FeuerStrip.spawn(room.attacks, "zunderflocke", _target_pos + off, {"size": 1.4, "hdr": 1.6, "loop": true, "speed": randf_range(0.8, 1.3)})
		f.z_index = 6
		_flakes.append(f)
	_fx().word(_target_pos + Vector2(0, -150), "LEUCHTFEUER", GOLD, 26)
	_pose = "taunt_0"


func _flakes_rise(delta: float) -> void:
	_set_pose("taunt_0" if _t < 1.2 else "cross_hit")
	for f in _flakes:
		if is_instance_valid(f):
			f.position += Vector2(sin(_t * 3.0 + f.get_instance_id()) * 10.0, -8.0) * delta
			f.alpha = 0.7 + 0.3 * sin(_t * 9.0 + f.position.x)
			_fx().light(f.position, Color(1.0, 0.85, 0.5), 0.5, 0.3, 0.05)
	if _t >= 1.5:
		room.fx.flash(0.5 * FxSettings.factor("flash"), Color(1.0, 0.9, 0.7))
		room.fx.shake(10.0 * FxSettings.factor("shake"))
		room.fx.punch(0.08)
		room.fx.dim(0.25)
		Sfx.play("hit_heavy", 4.0)
		var counts := {}
		for f in _flakes:
			if not is_instance_valid(f):
				continue
			var p: Vector2 = f.position
			FeuerStrip.spawn(room.attacks, "ausbruch", p + Vector2(0, 30), {"anchor": "bottom", "size": 1.4, "hdr": 1.5, "speed": 1.4})
			_fx().ring(p, 30.0, GOLD, 0.3, 4.0)
			for tg in _targets():
				if tg.get_hurt_rect().get_center().distance_to(p) < 44.0:
					var id: int = tg.get_instance_id()
					var c: int = counts.get(id, 0)
					counts[id] = c + 1
					_deal(tg, 16.0 * FeuerCaster.FALLOFF[mini(c, 2)], 120.0, "super_final" if c == 0 else "super", 180.0)
			for h in caster.herde.duplicate():
				if is_instance_valid(h) and h.global_position.distance_to(p) < 60.0:
					h.ignite(1.3, 0.05)
			f.queue_free()
		_flakes.clear()
		_fx().word(_target_pos + Vector2(0, -160), "BOOM!", WHITE, 40)
		_next("end")


# --- draw -------------------------------------------------------------------------------------

## Silhouette of a signal tower behind the figure; its beacon flares up.
func _draw() -> void:
	if _tower_glow <= 0.01:
		return
	var base := player.global_position + Vector2(-player.facing * 46.0, 2.0)
	var a := clampf(_tower_glow, 0.0, 1.0)
	var col := Color(0.06, 0.03, 0.05, 0.85 * a)
	var pts := PackedVector2Array([base + Vector2(-18, 0), base + Vector2(18, 0), base + Vector2(10, -150), base + Vector2(-10, -150)])
	draw_colored_polygon(pts, col)
	draw_rect(Rect2(base + Vector2(-16, -166), Vector2(32, 16)), col)
	draw_rect(Rect2(base + Vector2(-20, -152), Vector2(40, 4)), col)
	var top := base + Vector2(0, -176)
	var tex := GlutFx.glow_texture()
	var b := FxSettings.boost()
	draw_texture_rect(tex, Rect2(top - Vector2(70, 70), Vector2(140, 140)), false, Color(1.0 * b, 0.55 * b, 0.2 * b, 0.5 * a))
	draw_texture_rect(tex, Rect2(top - Vector2(26, 26), Vector2(52, 52)), false, Color(1.0 * b, 0.9 * b, 0.6 * b, 0.9 * a))
