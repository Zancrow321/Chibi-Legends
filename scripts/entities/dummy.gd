class_name TrainingDummy
extends Node2D
## Training dummy: endless HP, shows statuses, wobbles on hit,
## burns while it has the "brand" status.
## Look: PixelLab sprite strips in assets/dummies (frame 0 = rest, 1-6 = hit
## wobble, leaning left = pushed from the right; mirrored for hits from the left).

const BURN_TICK := 0.5
const BURN_DAMAGE := 3.0
const TEX_SMALL := preload("res://assets/dummies/klein.png")
const TEX_BIG := preload("res://assets/dummies/gross.png")
const FRAMES := 7
const HIT_FPS := 16.0
## Per strip: cell size, x of the post in the cell, bottom row of the base.
const CELL_SMALL := Vector3(64, 30, 62)
const CELL_BIG := Vector3(96, 48, 92)

var world: Node
var big := false
var label := "Trainingspuppe"
var status: Dictionary = {}
var wobble := 0.0
var flash := 0.0
var knock := 0.0
var _burn_timer := 0.0
var _home_x := 0.0
var _home_y := 0.0
## Height above the post when launched (juggle), and its vertical speed.
var air := 0.0
var air_v := 0.0
var _t := 0.0
## Playback position of the hit wobble (-1 = resting) and its mirror side.
var _hit_t := -1.0
var _hit_flip := false


func _ready() -> void:
	add_to_group("targets")
	_home_x = position.x
	_home_y = position.y


func size() -> Vector2:
	return Vector2(46, 86) if big else Vector2(26, 56)


func get_hurt_rect() -> Rect2:
	var s := size()
	return Rect2(global_position + Vector2(-s.x / 2.0, -s.y), s)


func head_position() -> Vector2:
	return global_position + Vector2(0, -size().y - 6)


func take_hit(knockback: float, from_x: float) -> void:
	wobble = 1.0
	flash = 0.08
	var dir := signf(global_position.x - from_x)
	_hit_t = 0.0
	_hit_flip = dir > 0.0
	knock += dir * knockback * (0.25 if big else 0.5) * 0.06


## Throws the dummy up (positive) or slams it down (negative). Big dummies
## are heavy and barely move; while airborne every hit keeps it up (juggle).
func launch(speed: float) -> void:
	var k := 0.35 if big else 1.0
	if speed > 0.0:
		air_v = maxf(air_v, 0.0) * 0.3 + speed * k
	elif air > 0.0:
		air_v = speed * k


func _process(delta: float) -> void:
	_t += delta
	if air > 0.0 or air_v > 0.0:
		air_v -= 900.0 * delta
		air = maxf(0.0, air + air_v * delta)
		if air <= 0.0:
			air_v = 0.0
			wobble = 1.0
			_hit_t = 0.0
	position.y = _home_y - air
	wobble = maxf(0.0, wobble - delta * 2.5)
	if _hit_t >= 0.0:
		_hit_t += delta * HIT_FPS
		if _hit_t >= FRAMES - 1:
			_hit_t = -1.0
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
	var tex: Texture2D = TEX_BIG if big else TEX_SMALL
	var cell: Vector3 = CELL_BIG if big else CELL_SMALL
	var frame := 0 if _hit_t < 0.0 else 1 + int(_hit_t)
	var flip := _hit_flip and frame > 0
	# soft ground shadow that stays on the floor while juggled
	var sh := clampf(1.0 - air / 160.0, 0.3, 1.0)
	draw_set_transform(Vector2(0, air), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, (s.x * 0.6 + 6.0) * sh, Color(0, 0, 0, 0.3 * sh))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	var dst := Rect2(-cell.y, -cell.z, cell.x, cell.x)
	var src := Rect2(frame * cell.x, 0, cell.x, cell.x)
	var tint := Color(1, 1, 1)
	if flash > 0.0:
		tint = Color(3, 3, 3)  # hit flash: blow the sprite out to near white
	draw_texture_rect_region(tex, dst, src, tint)
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
