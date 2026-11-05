class_name MondIcons
extends RefCounted
## Icons for the Züge of Schwarzmond, drawn in code (night blue, black ink,
## cold white/cyan rim; red only for the entfesselte Blutmond).

const IDS := ["mondschnitt", "mondsichel", "aufsteigender_mond", "entschlossene_abwehr", "schwarze_spur",
	"fallender_mond", "meisterzug", "neumond", "blutmond", "mondfinsternis"]
const BG := Color("141428")
const NIGHT := Color("232246")
const INK := Color("07060c")
const CYAN := Color("6fe3ff")
const WHITE := Color("f4f8ff")
const RED := Color("c8142e")


static func has(id: String) -> bool:
	return id in IDS


static func _bg(ci: CanvasItem, r: Rect2, col := BG) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = Color(CYAN, 0.55)
	ci.draw_style_box(sb, r)


static func _sichel(ci: CanvasItem, c: Vector2, dir: Vector2, r: float, rim := CYAN) -> void:
	ci.draw_colored_polygon(MondFx.crescent(c, dir, r, 1.25, 1.1), INK)
	ci.draw_polyline(MondFx.rim(c, dir, r, 1.25), rim, maxf(1.0, r * 0.12), true)
	ci.draw_polyline(MondFx.rim(c, dir, r, 1.0), WHITE, maxf(0.6, r * 0.05), true)


static func _blade(ci: CanvasItem, a: Vector2, b: Vector2, s: float) -> void:
	ci.draw_line(a, b, INK, 5.0 * s)
	ci.draw_line(a, b, Color(CYAN, 0.8), 1.4 * s)


static func draw(ci: CanvasItem, r: Rect2, id: String, t := 0.0) -> void:
	if PixelSkillIcon.try_draw(ci, r, "schwarzmond", id, t, BG, CYAN, Color(0.6, 0.95, 1.0)):
		return
	var c := r.get_center()
	var s := r.size.x / 50.0
	match id:
		"mondschnitt":
			_bg(ci, r)
			for i in 3:
				var rr := (10.0 + i * 5.0) * s
				ci.draw_arc(c + Vector2(-6, 4) * s, rr, -1.2, 0.9, 12, Color(CYAN, 0.45 + i * 0.2), (1.5 + i) * s, true)
			_blade(ci, c + Vector2(-14, 14) * s, c + Vector2(12, -14) * s, s)
		"mondsichel":
			_bg(ci, r)
			for i in 3:
				ci.draw_line(c + Vector2(-18, -6 + i * 6) * s, c + Vector2(-6, -6 + i * 6) * s, Color(CYAN, 0.3 + i * 0.1), 1.5 * s)
			_sichel(ci, c + Vector2(-2, 0) * s, Vector2.RIGHT, 15.0 * s)
		"aufsteigender_mond":
			_bg(ci, r)
			_sichel(ci, c + Vector2(0, 2) * s, Vector2(0.3, -1).normalized(), 14.0 * s)
			ci.draw_line(c + Vector2(-12, 18) * s, c + Vector2(-12, 4) * s, Color(CYAN, 0.6), 2.0 * s)
		"entschlossene_abwehr":
			_bg(ci, r, NIGHT)
			ci.draw_arc(c + Vector2(4, 2) * s, 16 * s, -1.2, 1.2, 14, Color(WHITE, 0.4 + 0.2 * sin(t * 4.0)), 3 * s, true)
			_blade(ci, c + Vector2(-4, 18) * s, c + Vector2(-2, -18) * s, s * 1.3)
		"schwarze_spur":
			_bg(ci, r)
			for i in 4:
				ci.draw_rect(Rect2(c + Vector2(-18 + i * 6, -10) * s, Vector2(5, 20) * s), Color(INK, 0.3 + i * 0.15))
			ci.draw_line(c + Vector2(-16, 6) * s, c + Vector2(16, 6) * s, WHITE, 1.5 * s)
			ci.draw_circle(c + Vector2(12, -2) * s, 4 * s, INK)
		"fallender_mond":
			_bg(ci, r)
			_sichel(ci, c + Vector2(0, -2) * s, Vector2(0, 1), 13.0 * s)
			ci.draw_line(c + Vector2(-18, 16) * s, c + Vector2(18, 16) * s, Color(CYAN, 0.8), 2.0 * s)
			for d in [-1.0, 1.0]:
				ci.draw_arc(c + Vector2(d * 12, 16) * s, 5 * s, PI, TAU, 8, Color(WHITE, 0.7), 1.5 * s)
		"blutmond":
			_bg(ci, r, Color("1e0810"))
			ci.draw_circle(c, 17 * s, Color(RED, 0.25 + 0.1 * sin(t * 3.0)))
			_sichel(ci, c, Vector2.RIGHT, 16.0 * s, RED)
		"mondfinsternis":
			_bg(ci, r, Color("050508"))
			ci.draw_circle(c, 12 * s, INK)
			ci.draw_arc(c, 13 * s, 0, TAU, 32, WHITE, 1.6 * s, true)
			for i in 12:
				var a := TAU * i / 12.0 + t * 0.4
				ci.draw_line(c + Vector2(cos(a), sin(a)) * 15 * s, c + Vector2(cos(a), sin(a)) * 20 * s, Color(CYAN, 0.6), 1.0 * s)
		_:  # meisterzug, neumond
			_bg(ci, r, Color("0c0c1c"))
			for i in 10:
				var a2 := t * 1.0 + TAU * i / 10.0
				ci.draw_line(c, c + Vector2(cos(a2), sin(a2)) * 22 * s, Color(CYAN, 0.25), 1.5 * s)
			_sichel(ci, c + Vector2(-2, 0), Vector2(1, -0.3).normalized(), 15.0 * s, WHITE)
