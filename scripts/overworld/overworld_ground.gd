class_name OverworldGround
extends Node2D
## Ground of the academy courtyard, drawn in code: cobblestone plaza with a
## pale stone curb and a strip of lawn, the marble terrace with stairs, the
## dorm balcony and two floating rune stones. Lit by the scene (pixel_lit).

const INK := Color("2e222f")
const STONE := [Color("ab947a"), Color("ab947a"), Color("b2ba90"), Color("966c6c")]
const MORTAR := Color("7f708a")
const CURB := Color("c7dcd0")
const CURB_SHADE := Color("9babb2")
const LAWN := Color("1ebc73")
const LAWN_LIGHT := Color("91db69")
const LAWN_DARK := Color("239063")
const MARBLE := Color("c7dcd0")
const MARBLE_SHADE := Color("9babb2")

var world: Overworld


static func _h(i: int, salt: float) -> float:
	return fposmod(sin(i * 12.9898 + salt * 78.233) * 43758.5453, 1.0)


func _draw() -> void:
	for gr in Overworld.GROUND:
		var r := Rect2(gr[0], gr[1], gr[2], 240.0)
		if gr[1] < Overworld.GROUND_Y:
			_marble(r)
		else:
			_plaza(r)
	for rp in Overworld.RAMPS:
		_stairs(rp)
	_balcony(Overworld.PLATFORMS[0])
	for i in range(1, Overworld.PLATFORMS.size()):
		_rune_stone(Overworld.PLATFORMS[i], i)


func _plaza(r: Rect2) -> void:
	draw_rect(r, MORTAR.darkened(0.45))
	# lawn strip with tufts and a few flowers along the front edge
	draw_rect(Rect2(r.position.x, r.position.y - 1, r.size.x, 1), INK)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 5), LAWN)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), LAWN_LIGHT)
	var n := int(r.size.x / 5.0)
	for i in n:
		var x := r.position.x + i * 5.0 + _h(i, 1) * 3.0
		var th := 1.0 + floorf(_h(i, 2) * 3.0)
		draw_rect(Rect2(x, r.position.y - th, 1, th), LAWN if _h(i, 3) > 0.4 else LAWN_LIGHT)
		if _h(i, 4) > 0.93:
			draw_rect(Rect2(x, r.position.y - th - 1, 2, 2), Color("fdcbb0") if _h(i, 5) > 0.5 else Color("f9c22b"))
	draw_rect(Rect2(r.position.x, r.position.y + 5, r.size.x, 2), LAWN_DARK)
	# pale curb
	var cy := r.position.y + 7.0
	draw_rect(Rect2(r.position.x, cy, r.size.x, 4), CURB)
	draw_rect(Rect2(r.position.x, cy + 4, r.size.x, 2), CURB_SHADE)
	for i in int(r.size.x / 22.0):
		draw_rect(Rect2(r.position.x + i * 22.0, cy, 1, 6), MORTAR)
	# cobblestones, offset rows, darker towards the bottom
	var y := cy + 7.0
	var row := 0
	while y < r.end.y:
		var bh := 7.0 if row < 3 else 9.0
		var dark := clampf(row * 0.13 - 0.05, 0.0, 0.72)
		var x := r.position.x - (0.0 if row % 2 == 0 else 7.0)
		var k := 0
		while x < r.end.x:
			var bw := 15.0 + floorf(_h(row * 131 + k, 6) * 8.0)
			var pick := _h(row * 57 + k, 7)
			var col: Color = STONE[0 if pick < 0.6 else (1 if pick < 0.8 else (2 if pick < 0.93 else 3))].darkened(dark)
			var bx := maxf(x, r.position.x)
			var ex := minf(x + bw - 1.0, r.end.x)
			if ex > bx:
				draw_rect(Rect2(bx, y, ex - bx, bh - 1.0), col)
				draw_rect(Rect2(bx, y, ex - bx, 1), col.lightened(0.12))
			x += bw
			k += 1
		y += bh
		row += 1


func _marble(r: Rect2) -> void:
	draw_rect(r, MARBLE_SHADE.darkened(0.45))
	draw_rect(Rect2(r.position.x, r.position.y - 1, r.size.x, 1), INK)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 3), Color("ffffff"))
	draw_rect(Rect2(r.position.x, r.position.y + 3, r.size.x, 4), MARBLE)
	draw_rect(Rect2(r.position.x, r.position.y + 7, r.size.x, 2), MARBLE_SHADE)
	# big marble slabs with a gold inlay line
	draw_rect(Rect2(r.position.x, r.position.y + 12, r.size.x, 1), Color("f9c22b"))
	var y := r.position.y + 14.0
	var row := 0
	while y < r.end.y:
		var dark := clampf(row * 0.12, 0.0, 0.65)
		var x := r.position.x - (0.0 if row % 2 == 0 else 14.0)
		while x < r.end.x:
			var bx := maxf(x, r.position.x)
			var ex := minf(x + 27.0, r.end.x)
			if ex > bx:
				draw_rect(Rect2(bx, y, ex - bx, 11), MARBLE.darkened(dark))
				draw_rect(Rect2(bx, y, ex - bx, 1), Color("ffffff").darkened(dark))
			x += 28.0
		y += 12.0
		row += 1


func _stairs(rp: Array) -> void:
	# the ramp collision, drawn as four marble steps
	var x0: float = rp[0]
	var x1: float = rp[1]
	var rising := float(rp[2]) > float(rp[3])
	var steps := 4
	var sw := (x1 - x0) / steps
	var sh := absf(float(rp[2]) - float(rp[3])) / steps
	for i in steps:
		var top := Overworld.GROUND_Y - (i + 1) * sh
		var rect := Rect2(x0 + i * sw, top, x1 - x0 - i * sw, Overworld.GROUND_Y - top + 8.0) if rising \
			else Rect2(x0, top, x1 - x0 - i * sw, Overworld.GROUND_Y - top + 8.0)
		draw_rect(Rect2(rect.position.x, rect.position.y - 1, rect.size.x, 1), INK)
		draw_rect(rect, MARBLE.darkened(0.06 * (steps - i)))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), Color("ffffff"))


func _balcony(p: Array) -> void:
	var r := Rect2(p[0], p[1], p[2], 6)
	draw_rect(r.grow(1), INK)
	draw_rect(r, Color("694f62"))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color("966c6c"))
	# railing
	draw_rect(Rect2(r.position.x, r.position.y - 14, r.size.x, 2), Color("694f62"))
	for i in int(r.size.x / 8.0) + 1:
		draw_rect(Rect2(r.position.x + i * 8.0, r.position.y - 14, 2, 14), Color("694f62"))
	# brackets
	for x in [r.position.x + 6.0, r.end.x - 8.0]:
		draw_rect(Rect2(x, r.end.y, 2, 10), Color("45293f"))


func _rune_stone(p: Array, i: int) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var bob := roundf(sin(t * 1.4 + i) * 1.5)
	var r := Rect2(p[0], p[1] + bob, p[2], 8)
	draw_rect(r.grow(1), INK)
	draw_rect(r, MARBLE_SHADE)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color("ffffff"))
	var under := PackedVector2Array([r.position + Vector2(4, 8), r.end + Vector2(-4, 0), Vector2(r.get_center().x, r.end.y + 12)])
	draw_colored_polygon(under, Color("7f708a"))
	# glowing rune marks (bright enough to bloom)
	var glow := Color(0.5, 1.8, 1.5) * (0.85 + 0.15 * sin(t * 3.0 + i))
	for k in 4:
		draw_rect(Rect2(r.position.x + 8 + k * 12, r.position.y + 3, 6, 2), glow)


func _process(_delta: float) -> void:
	queue_redraw()  # rune stones bob
