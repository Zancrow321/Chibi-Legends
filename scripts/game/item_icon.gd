class_name ItemIcon
extends RefCounted
## Draws a gear icon (sword, armour, talisman) with ink outlines in the
## rarity colour, on any CanvasItem. Size 1.0 is about 16 px; the menus
## draw it at 2.5-3x. Three small variations per slot ("icon" 0-2).

const INK := Color("2e222f")
const STEEL := Color("c7dcd0")
const STEEL_DARK := Color("7e9e99")
const WOOD := Color("9a4f50")
const CLOTH := [Color("e83b3b"), Color("4d9be6"), Color("1ebc73")]


static func draw_icon(ci: CanvasItem, c: Vector2, item: Dictionary, s: float) -> void:
	var col := Loot.color(item)
	var v := int(item.get("icon", 0)) % 3
	match str(item.get("slot", "waffe")):
		"waffe":
			_sword(ci, c, s, col, v)
		"ruestung":
			_armour(ci, c, s, col, v)
		_:
			_talisman(ci, c, s, col, v)


static func _poly(ci: CanvasItem, pts: Array, fill: Color, c: Vector2, s: float, outline := 1.6) -> void:
	var p := PackedVector2Array()
	for q in pts:
		p.append(c + (q as Vector2) * s)
	ci.draw_colored_polygon(p, fill)
	p.append(p[0])
	ci.draw_polyline(p, INK, outline * s, false)


static func _sword(ci: CanvasItem, c: Vector2, s: float, col: Color, v: int) -> void:
	var w: float = [1.6, 2.2, 1.3][v]
	# blade on the diagonal, tip up right
	_poly(ci, [Vector2(-3, 3) + Vector2(-w, -w) * 0.5, Vector2(6 - w * 0.3, -8), Vector2(7.5, -7.5), Vector2(7, -6 + w * 0.3), Vector2(-3, 3) + Vector2(w, w) * 0.5], STEEL, c, s)
	ci.draw_line(c + Vector2(-2.5, 2.5) * s, c + Vector2(6.2, -6.2) * s, Color.WHITE, 0.8 * s)
	# guard in the rarity colour, grip and pommel
	_poly(ci, [Vector2(-7, 1), Vector2(-1, 7), Vector2(0, 6), Vector2(-6, 0)], col, c, s)
	_poly(ci, [Vector2(-5, 5), Vector2(-7.5, 7.5), Vector2(-6.5, 8.5), Vector2(-4, 6)], WOOD, c, s)
	ci.draw_circle(c + Vector2(-8, 8.5) * s, 1.8 * s, INK)
	ci.draw_circle(c + Vector2(-8, 8.5) * s, 1.1 * s, col)


static func _armour(ci: CanvasItem, c: Vector2, s: float, col: Color, v: int) -> void:
	var body: Color = [STEEL_DARK, WOOD.lightened(0.15), STEEL][v]
	_poly(ci, [Vector2(-8, -6), Vector2(-3, -8), Vector2(0, -5), Vector2(3, -8), Vector2(8, -6), Vector2(7, 0), Vector2(5, 0), Vector2(5, 8), Vector2(-5, 8), Vector2(-5, 0), Vector2(-7, 0)], body, c, s)
	# rarity trim across the chest and a belt
	ci.draw_line(c + Vector2(-4.5, -1) * s, c + Vector2(4.5, -1) * s, col, 1.6 * s)
	ci.draw_line(c + Vector2(-4.5, 5) * s, c + Vector2(4.5, 5) * s, CLOTH[v].darkened(0.2), 1.4 * s)
	ci.draw_circle(c + Vector2(0, 2) * s, 1.4 * s, col)


static func _talisman(ci: CanvasItem, c: Vector2, s: float, col: Color, v: int) -> void:
	# cord, then a gem in a ring
	ci.draw_arc(c + Vector2(0, -3) * s, 6.0 * s, PI * 1.05, PI * 1.95, 12, INK, 1.4 * s)
	var gem := c + Vector2(0, 3) * s
	ci.draw_circle(gem, 5.6 * s, INK)
	ci.draw_circle(gem, 4.4 * s, Color("f9c22b") if v == 1 else STEEL)
	match v:
		0:
			ci.draw_circle(gem, 3.0 * s, col)
		1:
			_poly(ci, [Vector2(0, -3.2), Vector2(3, 0), Vector2(0, 3.2), Vector2(-3, 0)], col, gem, s, 1.0)
		_:
			_poly(ci, [Vector2(0, -3.4), Vector2(2.9, 1.8), Vector2(-2.9, 1.8)], col, gem, s, 1.0)
	ci.draw_circle(gem + Vector2(-1.2, -1.2) * s, 0.9 * s, Color(1, 1, 1, 0.9))
