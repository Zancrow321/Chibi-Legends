class_name SparringPost
extends Node2D
## Sparring post ("Schlagpfahl") for testing the defensive Züge: a wooden
## post with a swinging arm and a little sling on top. When the player comes
## close it telegraphs (the arm creaks back, a "!" appears) and swings; from
## further away it throws a log (Holzscheit) that can be countered with the
## Ambosshaltung, thrown back with Spiegelschmiede or burnt by Funkenschild.
## It is also a target with endless HP like the dummies.

const SWING_RANGE := 74.0
const THROW_MIN := 90.0
const THROW_MAX := 330.0
const SWING_EVERY := 1.7
const THROW_EVERY := 2.6
const TELEGRAPH := 0.45
const SWING_DAMAGE := 40.0
const LOG_DAMAGE := 30.0

var world: TrainingRoom
var label := "Sparringspfahl"
var status: Dictionary = {}
var flash := 0.0
var wobble := 0.0
var air := 0.0
var air_v := 0.0
var _home_y := 0.0
var _burn_timer := 0.0
var _t := 0.0
var _cd := 1.0
var _telegraph := -1.0  # >= 0 while winding up
var _action := ""  # "swing" or "throw"
var _swing := -1.0  # >= 0 while the arm swings
var _arm := 0.0  # arm angle (0 = rest, -1 = pulled back, 1 = swung)
var _sling := 0.0
var facing := -1


func _ready() -> void:
	add_to_group("targets")
	_home_y = position.y


func get_hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-13, -58), Vector2(26, 58))


func head_position() -> Vector2:
	return global_position + Vector2(0, -66)


func take_hit(knockback: float, _from_x: float) -> void:
	flash = 0.08
	wobble = 1.0
	# a clean hit interrupts the wind-up
	if _telegraph >= 0.0 and knockback >= 120.0:
		_telegraph = -1.0
		_cd = 1.0


func launch(speed: float) -> void:
	if speed > 0.0:
		air_v = maxf(air_v, 0.0) * 0.3 + speed * 0.25


func _process(delta: float) -> void:
	_t += delta
	flash = maxf(0.0, flash - delta)
	wobble = maxf(0.0, wobble - delta * 2.5)
	if air > 0.0 or air_v > 0.0:
		air_v -= 900.0 * delta
		air = maxf(0.0, air + air_v * delta)
		if air <= 0.0:
			air_v = 0.0
	position.y = _home_y - air
	Reactions.tick(status, delta)
	if status.has("brand"):
		_burn_timer -= delta
		if _burn_timer <= 0.0:
			_burn_timer = TrainingDummy.BURN_TICK
			world.deal_dot(self, TrainingDummy.BURN_DAMAGE, "feuer")
	_think(delta)
	queue_redraw()


func _think(delta: float) -> void:
	var p := world.player
	var dx := p.global_position.x - global_position.x
	var dist := absf(dx)
	if _swing >= 0.0:
		_swing += delta
		_arm = minf(1.0, _arm + delta * 14.0)
		if _swing >= 0.05 and _swing - delta < 0.05:
			var r := Rect2(global_position.x + (0.0 if facing > 0 else -SWING_RANGE), global_position.y - 52, SWING_RANGE, 40)
			if r.intersects(p.get_hurt_rect()):
				p.receive_hit(SWING_DAMAGE, global_position.x, self)
			if world.glut_fx != null:
				world.glut_fx.word(global_position + Vector2(facing * 30.0, -78), "WUSCH!", Color("e8d8c0"), 16)
		if _swing > 0.35:
			_swing = -1.0
		return
	_arm = move_toward(_arm, 0.0, delta * 3.0)
	_sling = move_toward(_sling, 0.0, delta * 3.0)
	if _telegraph >= 0.0:
		_telegraph += delta
		if _action == "swing":
			_arm = -minf(1.0, _telegraph / TELEGRAPH)
		else:
			_sling = -minf(1.0, _telegraph / TELEGRAPH)
		if _telegraph >= TELEGRAPH:
			_telegraph = -1.0
			if _action == "swing":
				_swing = 0.0
				_cd = SWING_EVERY
			else:
				_throw()
				_cd = THROW_EVERY
		return
	if dist > THROW_MAX + 40.0 or p.hp <= 0.0:
		return
	facing = 1 if dx > 0.0 else -1
	_cd -= delta
	if _cd > 0.0:
		return
	if dist <= SWING_RANGE:
		_action = "swing"
		_telegraph = 0.0
	elif dist >= THROW_MIN and dist <= THROW_MAX:
		_action = "throw"
		_telegraph = 0.0


func _throw() -> void:
	_sling = 1.0
	var scheit := Holzscheit.new()
	scheit.world = world
	var from := global_position + Vector2(facing * 6.0, -64)
	scheit.global_position = from
	var target := world.player.global_position + Vector2(0, -20)
	var tt := clampf(absf(target.x - from.x) / 260.0, 0.45, 1.1)
	scheit.vel = Vector2((target.x - from.x) / tt, (target.y - from.y - 0.5 * Holzscheit.GRAVITY * tt * tt) / tt)
	world.attacks.add_child(scheit)


func _draw() -> void:
	var outline := Color("1a1020")
	var wood := Color("8a5a34")
	var wood_d := Color("6a4226")
	var wood_l := Color("a8744a")
	var tilt := sin(_t * 30.0) * wobble * 0.12
	# base
	draw_rect(Rect2(-16, -5, 32, 6), outline)
	draw_rect(Rect2(-15, -4, 30, 4), wood_d)
	draw_set_transform(Vector2(0, -4), tilt, Vector2.ONE)
	# post
	draw_rect(Rect2(-9, -54, 18, 54), outline)
	draw_rect(Rect2(-8, -53, 16, 52), wood)
	draw_rect(Rect2(-8, -53, 4, 52), wood_l)
	draw_rect(Rect2(4, -53, 4, 52), wood_d)
	for y in [-44, -30, -16]:
		draw_rect(Rect2(-9, y, 18, 3), outline)
		draw_rect(Rect2(-8, y + 1, 16, 1), Color("5a5060"))
	# straw padding (target)
	draw_rect(Rect2(-11, -40, 22, 14), outline)
	draw_rect(Rect2(-10, -39, 20, 12), Color("e0b85a"))
	draw_rect(Rect2(-10, -39, 20, 2), Color("f0d47a"))
	draw_circle(Vector2(0, -33), 4, Color("d23b3b"))
	draw_circle(Vector2(0, -33), 2, Color("f4efe2"))
	# swinging arm (pivot at the right/left side, depending on facing)
	var piv := Vector2(facing * 7.0, -46)
	var tip := piv + Vector2(facing * 30.0, 0).rotated(-facing * _arm * 0.8)
	draw_line(piv, tip, outline, 7.0)
	draw_line(piv, tip, wood_l, 4.0)
	draw_rect(Rect2(tip - Vector2(4, 4), Vector2(8, 8)), outline)
	draw_rect(Rect2(tip - Vector2(3, 3), Vector2(6, 6)), wood)
	draw_circle(piv, 3, Color("5a5060"))
	# sling on top
	var top := Vector2(0, -56)
	var arm2 := top + Vector2(-facing * 12.0, -4).rotated(facing * _sling * 1.1)
	draw_line(top, arm2, outline, 5.0)
	draw_line(top, arm2, wood_d, 3.0)
	draw_rect(Rect2(arm2 - Vector2(4, 3), Vector2(8, 5)), outline)
	draw_rect(Rect2(arm2 - Vector2(3, 2), Vector2(6, 3)), Color("5a3a20"))
	if flash > 0.0:
		draw_rect(Rect2(-8, -53, 16, 52), Color(1, 1, 1, 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# telegraph: "!" over the post
	if _telegraph >= 0.0:
		var a := 0.6 + 0.4 * sin(_t * 40.0)
		draw_rect(Rect2(-3, -88, 6, 12), Color(outline, a))
		draw_rect(Rect2(-2, -87, 4, 10), Color(1.0, 0.85, 0.3, a))
		draw_rect(Rect2(-3, -74, 6, 5), Color(outline, a))
		draw_rect(Rect2(-2, -73, 4, 3), Color(1.0, 0.85, 0.3, a))
	# status icons
	var keys := status.keys()
	var x := -keys.size() * 7.0
	for key in keys:
		var col: Color = GameData.STATUS[key].color
		draw_rect(Rect2(Vector2(x, -100) - Vector2(5, 5), Vector2(12, 12)), outline)
		draw_rect(Rect2(Vector2(x, -100) - Vector2(4, 4), Vector2(10, 10)), col.darkened(0.3))
		x += 14.0
