class_name KlangIcons
extends RefCounted
## Skill icons of Gleichklang, drawn in code (HUD skill bar and style menu).
## Night-blue background, pale blue arcs, a bronze Klangloch where it fits.

const BG := Color("1c1a33")
const BG2 := Color("26203f")
const BLUE := Color("8fd3ff")
const PALE := Color("cfeaff")
const WHITE := Color("f4fbff")
const VIOLET := Color("a884f3")
const BRONZE := Color("e0a060")
const SHAFT := Color("5c4646")


static func _bg(ci: CanvasItem, r: Rect2, col := BG) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(6)
	sb.border_color = Color(BLUE, 0.35)
	sb.set_border_width_all(1)
	ci.draw_style_box(sb, r)


static func _hole(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	ci.draw_circle(c, 4.2 * s, BRONZE)
	ci.draw_circle(c, 2.6 * s, Color("16121f"))
	ci.draw_circle(c, 1.2 * s, Color(BLUE, 0.7 + 0.3 * sin(t * 6.0)))


static func _arc(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, w: float, col: Color) -> void:
	ci.draw_arc(c, r, a0, a1, 18, Color(col, 0.35), w * 2.2, true)
	ci.draw_arc(c, r, a0, a1, 18, col, w, true)
	ci.draw_arc(c, r + w * 0.25, a0 + (a1 - a0) * 0.3, a1, 14, WHITE, maxf(1.0, w * 0.35), true)


static func draw(ci: CanvasItem, r: Rect2, id: String, t := 0.0) -> void:
	if PixelSkillIcon.try_draw(ci, r, "gleichklang", id, t, BG, BLUE, Color(0.8, 0.9, 1.0)):
		return
	var c := r.get_center()
	var s := r.size.x / 50.0
	match id:
		"sicheltakt":
			_bg(ci, r)
			_arc(ci, c + Vector2(-4, 2) * s, 14 * s, -2.0, 0.9, 3.0 * s, BLUE)
			_arc(ci, c + Vector2(-4, 2) * s, 9 * s, 1.0, -1.6, 2.0 * s, PALE)
		"seelensichel":
			_bg(ci, r)
			_arc(ci, c + Vector2(-12, 0) * s, 22 * s, -0.8, 0.8, 4.0 * s, BLUE)
			_arc(ci, c + Vector2(-12, 0) * s, 27 * s, -0.6, 0.6, 2.0 * s, VIOLET)
		"himmelsreigen":
			_bg(ci, r)
			_arc(ci, c + Vector2(-2, 8) * s, 15 * s, 1.0, -1.8, 3.5 * s, BLUE)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(8, -18) * s, c + Vector2(13, -9) * s, c + Vector2(3, -9) * s]), PALE)
		"seelenlauschen":
			_bg(ci, r, BG2)
			var k := 0.5 + 0.5 * sin(t * 4.0)
			for i in 3:
				ci.draw_arc(c, (6 + i * 6 + k * 2) * s, 0.0, TAU, 24, Color(VIOLET, 0.65 - i * 0.18), 1.5 * s, true)
			ci.draw_line(c + Vector2(-6, 0) * s, c + Vector2(-2, 2) * s, PALE, 1.5 * s)
			ci.draw_line(c + Vector2(6, 0) * s, c + Vector2(2, 2) * s, PALE, 1.5 * s)
		"sichelschritt":
			_bg(ci, r)
			ci.draw_line(c + Vector2(-14, 16) * s, c + Vector2(4, -8) * s, SHAFT, 3 * s)
			_arc(ci, c + Vector2(-4, 8) * s, 18 * s, -2.6, -0.6, 2.5 * s, BLUE)
			for i in 3:
				var y := (-2 + i * 6) * s
				ci.draw_line(c + Vector2(8, y), c + Vector2(18 - i * 3, y), Color(PALE, 0.7), 1.5 * s)
		"fallende_sichel":
			_bg(ci, r)
			_arc(ci, c + Vector2(0, -4) * s, 12 * s, -PI, PI * 0.6, 3.0 * s, BLUE)
			ci.draw_line(c + Vector2(-2, 6) * s, c + Vector2(8, 18) * s, PALE, 2.5 * s)
			ci.draw_rect(Rect2(c + Vector2(-18, 17) * s, Vector2(36, 2) * s), Color(BLUE, 0.6))
		_:  # Meisterzug and its variants
			_bg(ci, r, Color("120f22"))
			for i in 8:
				var a := t * 0.8 + TAU * i / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * 12 * s, c + Vector2(cos(a), sin(a)) * 22 * s, Color(BLUE, 0.35), 1.5 * s)
			var sync := 0.5 + 0.5 * sin(t * 3.0)
			ci.draw_arc(c + Vector2(-4 * sync, 0) * s, 11 * s, 0.0, TAU, 24, Color(PALE, 0.9), 2.0 * s, true)
			ci.draw_arc(c + Vector2(4 * sync, 0) * s, 11 * s, 0.0, TAU, 24, Color(VIOLET, 0.9), 2.0 * s, true)
			_hole(ci, c, s, t)
