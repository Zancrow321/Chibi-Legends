class_name GlutIcons
extends RefCounted
## Skill icons of Glutatem, drawn in code on any CanvasItem (HUD skill bar
## and the style menu use the same icons).

const BG := Color("3a1410")
const DARK := Color("1a0c0c")
const IRON := Color("6a6478")
const IRON_L := Color("9a94b0")


static func _bg(ci: CanvasItem, r: Rect2, col := BG) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(6)
	ci.draw_style_box(sb, r)


static func _anvil(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_rect(Rect2(c + Vector2(-5, 2) * s, Vector2(10, 6) * s), IRON.darkened(0.3))
	ci.draw_rect(Rect2(c + Vector2(-11, -4) * s, Vector2(20, 6) * s), IRON)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(9, -4) * s, c + Vector2(15, -4) * s, c + Vector2(9, 0) * s]), IRON)
	ci.draw_rect(Rect2(c + Vector2(-11, -4) * s, Vector2(20, 1.5) * s), IRON_L)


const ICON_DIR := "res://assets/combat/icons/glutatem/%s.png"
static var _tex: Dictionary = {}


## PixelLab icon for a Zug or Meisterzug (assets/combat/icons/glutatem), or null.
static func texture(id: String) -> Texture2D:
	if not _tex.has(id):
		var path := ICON_DIR % id
		_tex[id] = load(path) if ResourceLoader.exists(path) else null
	return _tex[id]


## Style whose icons are shown (set by the caster of the player's style).
static var style_id := "glutatem"


static func draw(ci: CanvasItem, r: Rect2, id: String, t := 0.0) -> void:
	if style_id == "gleichklang":
		KlangIcons.draw(ci, r, id, t)
		return
	if style_id == "lauffeuer":
		FeuerIcons.draw(ci, r, id, t)
		return
	var tex := texture(id)
	if tex != null:
		_draw_texture(ci, r, tex, id, t)
		return
	_draw_code(ci, r, id, t)


## Painted icon: framed, with a soft breathing ember glow over it.
static func _draw_texture(ci: CanvasItem, r: Rect2, tex: Texture2D, id: String, t: float) -> void:
	_bg(ci, r.grow(1), DARK)
	ci.draw_texture_rect(tex, r, false)
	var pulse := 0.5 + 0.5 * sin(t * (3.0 if id == "meisterzug" else 2.0) + r.position.x * 0.05)
	ci.draw_texture_rect(tex, r, false, Color(1.0, 0.6, 0.3, 0.12 + 0.12 * pulse))
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = Color(GlutFx.heat(0.55 + 0.35 * pulse), 0.85)
	ci.draw_style_box(sb, r.grow(1))


static func _draw_code(ci: CanvasItem, r: Rect2, id: String, t := 0.0) -> void:
	var c := r.get_center()
	var s := r.size.x / 50.0
	match id:
		"funkenschlag":
			_bg(ci, r)
			for i in 7:
				var a := -0.55 + 1.1 * i / 6.0
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(c + Vector2(-2, -4) * s + d * 6 * s, c + Vector2(-2, -4) * s + d * (16 + 4 * (i % 2)) * s, GlutFx.heat(0.7 + 0.04 * i), 2.0 * s)
			_anvil(ci, c + Vector2(-6, 10) * s, s * 0.8)
			ci.draw_circle(c + Vector2(-2, -4) * s, 4 * s, GlutFx.heat(1.0))
		"schlackeregen":
			_bg(ci, r)
			ci.draw_arc(c + Vector2(0, 14) * s, 16 * s, PI * 1.1, PI * 1.9, 12, Color(GlutFx.heat(0.5), 0.6), 1.5 * s)
			for i in 3:
				var p := c + Vector2(-12 + i * 12, -8 + absf(i - 1) * 8) * s
				ci.draw_circle(p, 4.5 * s, DARK)
				ci.draw_circle(p, 3.2 * s, GlutFx.heat(0.75))
				ci.draw_circle(p + Vector2(-1, -1) * s, 1.4 * s, GlutFx.heat(1.0))
			ci.draw_rect(Rect2(c + Vector2(-16, 14) * s, Vector2(32, 3) * s), GlutFx.heat(0.55))
		"weissglut":
			_bg(ci, r, Color("4a2410"))
			var k := 0.5 + 0.5 * sin(t * 6.0)
			ci.draw_circle(c, 15 * s, Color(GlutFx.heat(0.7), 0.25 + 0.15 * k))
			ci.draw_line(c + Vector2(-10, 14) * s, c + Vector2(10, -16) * s, GlutFx.heat(0.85), 5 * s)
			ci.draw_line(c + Vector2(-10, 14) * s, c + Vector2(10, -16) * s, GlutFx.heat(1.0), 2 * s)
			ci.draw_line(c + Vector2(-15, 10) * s, c + Vector2(-5, 18) * s, IRON_L, 3 * s)
		"ambosshaltung":
			_bg(ci, r, Color("2a1a2a"))
			ci.draw_arc(c + Vector2(0, 4) * s, 17 * s, PI * 1.05, PI * 1.95, 14, GlutFx.heat(0.8), 3 * s)
			ci.draw_arc(c + Vector2(0, 4) * s, 13 * s, PI * 1.15, PI * 1.85, 14, Color(GlutFx.heat(1.0), 0.6), 1.5 * s)
			_anvil(ci, c + Vector2(-2, 8) * s, s)
		"funkenflug":
			_bg(ci, r)
			for i in 4:
				var y := (-9 + i * 6) * s
				ci.draw_line(c + Vector2(-17, y), c + Vector2(6 - absf(i - 1.5) * 4, y), Color(GlutFx.heat(0.5 + i * 0.1), 0.5 + i * 0.12), 2 * s)
			ci.draw_circle(c + Vector2(10, -1) * s, 5 * s, GlutFx.heat(0.85))
			ci.draw_circle(c + Vector2(10, -1) * s, 2.5 * s, GlutFx.heat(1.0))
		"essensturz":
			_bg(ci, r)
			ci.draw_rect(Rect2(c + Vector2(-2, -18) * s, Vector2(4, 20) * s), IRON_L)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-7, 0) * s, c + Vector2(7, 0) * s, c + Vector2(0, 9) * s]), GlutFx.heat(0.9))
			ci.draw_rect(Rect2(c + Vector2(-18, 13) * s, Vector2(36, 3) * s), GlutFx.heat(0.6))
			for d in [-1.0, 1.0]:
				ci.draw_arc(c + Vector2(d * 12, 13) * s, 5 * s, PI, TAU, 8, GlutFx.heat(0.8), 2 * s)
		"meisterzug", "letzte_esse", "schmelzofen", "funkensturm":
			_bg(ci, r, Color("2a0c08"))
			for i in 10:
				var a2 := t * 1.2 + TAU * i / 10.0
				ci.draw_line(c, c + Vector2(cos(a2), sin(a2)) * 22 * s, Color(GlutFx.heat(0.8), 0.45), 2 * s)
			var flame := PackedVector2Array([c + Vector2(0, -17) * s, c + Vector2(9, -2) * s, c + Vector2(8, 9) * s, c + Vector2(0, 14) * s, c + Vector2(-8, 9) * s, c + Vector2(-9, -2) * s])
			ci.draw_colored_polygon(flame, GlutFx.heat(0.6))
			var inner := PackedVector2Array([c + Vector2(0, -8) * s, c + Vector2(5, 2) * s, c + Vector2(4, 9) * s, c + Vector2(0, 12) * s, c + Vector2(-4, 9) * s, c + Vector2(-5, 2) * s])
			ci.draw_colored_polygon(inner, GlutFx.heat(0.95))
		_:
			_bg(ci, r, Color("2a2140"))
