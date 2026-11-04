class_name TrainingDummy
extends Node2D
## Training dummy: endless HP, shows statuses, wobbles on hit,
## burns while it has the "brand" status.

const BURN_TICK := 0.5
const BURN_DAMAGE := 3.0

var world: Node
var big := false
var label := "Trainingspuppe"
var status: Dictionary = {}
var wobble := 0.0
var flash := 0.0
var knock := 0.0
var _burn_timer := 0.0
var _home_x := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("targets")
	_home_x = position.x


func size() -> Vector2:
	return Vector2(40, 66) if big else Vector2(26, 44)


func get_hurt_rect() -> Rect2:
	var s := size()
	return Rect2(global_position + Vector2(-s.x / 2.0, -s.y), s)


func head_position() -> Vector2:
	return global_position + Vector2(0, -size().y - 6)


func take_hit(knockback: float, from_x: float) -> void:
	wobble = 1.0
	flash = 0.08
	var dir := signf(global_position.x - from_x)
	knock += dir * knockback * (0.25 if big else 0.5) * 0.06


func _process(delta: float) -> void:
	_t += delta
	wobble = maxf(0.0, wobble - delta * 2.5)
	flash = maxf(0.0, flash - delta)
	# dummies are on springs: knockback slides them, then they return home
	position.x += knock
	knock *= 0.8
	position.x = lerpf(position.x, _home_x, 1.0 - exp(-4.0 * delta))
	Reactions.tick(status, delta)
	if status.has("brand"):
		_burn_timer -= delta
		if _burn_timer <= 0.0:
			_burn_timer = BURN_TICK
			world.deal_dot(self, BURN_DAMAGE, "feuer")
	else:
		_burn_timer = 0.0
	queue_redraw()


func _draw() -> void:
	var s := size()
	var k := 1.5 if big else 1.0
	var tilt := sin(_t * 30.0) * wobble * 0.25
	var outline := Color("1a1020")
	var wood := Color("8a5a34")
	var straw := Color("e0b85a") if not big else Color("8f8a9a")
	var straw_dark := straw.darkened(0.25)
	# post and base (not tilted)
	draw_rect(Rect2(-14 * k - 1, -5, 28 * k + 2, 6), outline)
	draw_rect(Rect2(-14 * k, -4, 28 * k, 4), wood.darkened(0.2))
	draw_rect(Rect2(-3 * k - 1, -s.y * 0.45 - 1, 6 * k + 2, s.y * 0.45), outline)
	draw_rect(Rect2(-3 * k, -s.y * 0.45, 6 * k, s.y * 0.45 - 4), wood)
	draw_set_transform(Vector2(0, -s.y * 0.4), tilt, Vector2.ONE)
	var body := Rect2(-s.x / 2.0, -s.y * 0.6, s.x, s.y * 0.45)
	var head := Rect2(-s.x * 0.38, -s.y * 0.6 - s.x * 0.7, s.x * 0.76, s.x * 0.7)
	for r in [body, head, Rect2(-s.x / 2.0 - 8 * k, body.position.y + 4, s.x + 16 * k, 6 * k)]:
		draw_rect(r.grow(1), outline)
	draw_rect(Rect2(-s.x / 2.0 - 8 * k, body.position.y + 4, s.x + 16 * k, 6 * k), wood)
	draw_rect(body, straw)
	draw_rect(Rect2(body.position, Vector2(4, body.size.y)), straw_dark)
	draw_rect(head, straw.lightened(0.1))
	# target on the chest
	var c := body.get_center()
	draw_circle(c, 7 * k, Color("f4efe2"))
	draw_circle(c, 5 * k, Color("d23b3b"))
	draw_circle(c, 3 * k, Color("f4efe2"))
	draw_circle(c, 1.5 * k, Color("d23b3b"))
	# stitched face
	var hc := head.get_center()
	draw_rect(Rect2(hc + Vector2(-5 * k, -2 * k), Vector2(3 * k, 3 * k)), outline)
	draw_rect(Rect2(hc + Vector2(2 * k, -2 * k), Vector2(3 * k, 3 * k)), outline)
	draw_rect(Rect2(hc + Vector2(-3 * k, 4 * k), Vector2(6 * k, 1 * k)), outline)
	if flash > 0.0:
		draw_rect(body, Color(1, 1, 1, 0.7))
		draw_rect(head, Color(1, 1, 1, 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_status_icons(s)


func _draw_status_icons(s: Vector2) -> void:
	var keys := status.keys()
	var x := -keys.size() * 7.0
	for key in keys:
		var col: Color = GameData.STATUS[key].color
		var p := Vector2(x, -s.y - 18)
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(12, 12)), Color("1a1020"))
		draw_rect(Rect2(p - Vector2(4, 4), Vector2(10, 10)), col.darkened(0.45))
		match key:
			"brand":
				draw_rect(Rect2(p + Vector2(0, -2), Vector2(2, 6)), col)
				draw_rect(Rect2(p + Vector2(-2, 1), Vector2(6, 3)), col)
			"frost":
				draw_rect(Rect2(p + Vector2(0, -3), Vector2(2, 8)), col)
				draw_rect(Rect2(p + Vector2(-3, 0), Vector2(8, 2)), col)
			"schock":
				draw_rect(Rect2(p + Vector2(1, -3), Vector2(2, 4)), col)
				draw_rect(Rect2(p + Vector2(-1, 1), Vector2(4, 1)), col)
				draw_rect(Rect2(p + Vector2(-1, 2), Vector2(2, 3)), col)
		# remaining time bar
		var frac := clampf(status[key] / Reactions.STATUS_DURATION, 0.0, 1.0)
		draw_rect(Rect2(p + Vector2(-4, 7), Vector2(10 * frac, 2)), col)
		x += 14.0
