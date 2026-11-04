class_name GrenzIcons
extends RefCounted
## Skill icons of Grenzbrecher: the PixelLab icons (assets/combat/icons/
## grenzbrecher, 48 px) on a dark blue plate with a soft breathing Ki glow
## (HUD skill bar and style menu).

const BG := Color("101626")
const EDGE := Color("6fd0ff")
const ICON_DIR := "res://assets/combat/icons/grenzbrecher/%s.png"

static var _tex: Dictionary = {}


static func texture(id: String) -> Texture2D:
	if not _tex.has(id):
		var p := ICON_DIR % id
		_tex[id] = load(p) if ResourceLoader.exists(p) else null
	return _tex[id]


static func draw(ci: CanvasItem, r: Rect2, id: String, t := 0.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(6)
	sb.border_color = Color(EDGE, 0.5)
	sb.set_border_width_all(1)
	ci.draw_style_box(sb, r)
	var tex := texture(id)
	if tex == null:
		return
	var pulse := 0.5 + 0.5 * sin(t * (3.0 if id == "meisterzug" else 2.0) + r.position.x * 0.05)
	var inner := r.grow(-2)
	ci.draw_texture_rect(tex, inner, false)
	ci.draw_texture_rect(tex, inner, false, Color(0.7, 0.9, 1.0, 0.06 + 0.1 * pulse))
