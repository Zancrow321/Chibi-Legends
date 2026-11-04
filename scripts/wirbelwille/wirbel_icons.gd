class_name WirbelIcons
extends RefCounted
## Skill icons of Wirbelwille: PixelLab icons (assets/combat/icons/wirbelwille)
## on a dark plate with a soft breathing turquoise glow. Missing icons fall
## back to a frame of the matching effect.

const BG := Color("101826")
const EDGE := Color("5fe3e0")
const ICON_DIR := "res://assets/combat/icons/wirbelwille/%s.png"
const FX_FALLBACK := {
	"wirbelansturm": "windstoss", "kreiselfaust": "kreiselfaust", "klon_aufsteiger": "windschatten_entstehen",
	"wechselhuelle": "strohpuppe", "klonschleuder": "windstoss", "wirbelsturz": "wirbelsturz_aufprall",
	"meisterzug": "sturmrad", "sturmrad": "sturmrad", "hundert_schatten": "windschatten_entstehen",
	"orkanmantel": "orkanmantel",
}
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
	ci.draw_style_box(sb, r.grow(1))
	var pulse := 0.5 + 0.5 * sin(t * (3.0 if id == "meisterzug" else 2.0) + r.position.x * 0.05)
	var tex := texture(id)
	if tex != null:
		ci.draw_texture_rect(tex, r, false)
		ci.draw_texture_rect(tex, r, false, Color(0.6, 1.0, 1.0, 0.08 + 0.1 * pulse))
	else:
		var fid: String = FX_FALLBACK.get(id, "")
		var ft := WirbelFx.tex(fid)
		var inf := WirbelFx.info(fid)
		if ft != null and not inf.is_empty():
			var fw := float(inf.frame_w)
			var fr := WirbelFx.frame_at(fid, t, true)
			ci.draw_texture_rect_region(ft, r.grow(-2), Rect2(fr * fw, 0, fw, float(inf.frame_h)))
	var edge := StyleBoxFlat.new()
	edge.draw_center = false
	edge.set_corner_radius_all(6)
	edge.set_border_width_all(2)
	edge.border_color = Color(EDGE, 0.45 + 0.4 * pulse)
	ci.draw_style_box(edge, r.grow(1))
