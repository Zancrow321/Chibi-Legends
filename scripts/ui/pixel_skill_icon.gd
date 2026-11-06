class_name PixelSkillIcon
extends RefCounted
## Shared drawing of PixelLab skill icons (assets/combat/icons/<style>/<id>.png,
## 48 px, Resurrect 64) on a dark plate with a breathing glow and an edge in
## the style colour. Used by the style icon scripts; returns false when the
## icon does not exist so the caller can draw its own fallback.

const ICON_DIR := "res://assets/combat/icons/%s/%s.png"
static var _tex: Dictionary = {}


static func texture(style: String, id: String) -> Texture2D:
	var key := style + "/" + id
	if not _tex.has(key):
		var p := ICON_DIR % [style, id]
		_tex[key] = load(p) if ResourceLoader.exists(p) else null
	return _tex[key]


static func try_draw(ci: CanvasItem, r: Rect2, style: String, id: String, t: float,
		bg: Color, edge: Color, glow: Color) -> bool:
	var tex := texture(style, id)
	if tex == null:
		return false
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(6)
	ci.draw_style_box(sb, r.grow(1))
	var pulse := 0.5 + 0.5 * sin(t * (3.0 if id == "meisterzug" else 2.0) + r.position.x * 0.05)
	ci.draw_texture_rect(tex, r, false)
	ci.draw_texture_rect(tex, r, false, Color(glow, 0.06 + 0.1 * pulse))
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.set_corner_radius_all(6)
	frame.set_border_width_all(2)
	frame.border_color = Color(edge, 0.45 + 0.4 * pulse)
	ci.draw_style_box(frame, r.grow(1))
	return true
