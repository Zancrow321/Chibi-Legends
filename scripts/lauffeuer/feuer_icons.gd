class_name FeuerIcons
extends RefCounted
## Skill icons of Lauffeuer (HUD skill bar and style menu): a frame of the
## Zug's PixelLab effect strip on a dark ember background, softly pulsing.

const BG := Color("2a1210")
const EDGE := Color("ff8a2a")
## Zug or Meisterzug -> [strip, frame]
const ICON := {
	"flammenknoechel": ["flammenfaust_knoechel", 6],
	"flammenfaust": ["flammenfaust", 7],
	"steigflamme": ["steigflamme", 4],
	"flammenleib": ["feuerschirm", 3],
	"feuerstrom": ["feuerstrom", 2],
	"niederschlag": ["einschlag", 4],
	"meisterzug": ["brandgestirn", 0],
	"grosser_brand": ["flammenfaust", 8],
	"brandgestirn": ["brandgestirn", 3],
	"leuchtfeuer": ["zunderflocke", 2],
}


static func draw(ci: CanvasItem, r: Rect2, id: String, t := 0.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(6)
	ci.draw_style_box(sb, r)
	var e: Array = ICON.get(id, ["brandherd", 0])
	var tex := FeuerStrip.texture(e[0])
	var pulse := 0.5 + 0.5 * sin(t * (3.0 if id == "meisterzug" else 2.0) + r.position.x * 0.05)
	if tex != null:
		var inf := FeuerStrip.info(e[0])
		var w := float(inf.get("w", 32))
		var h := float(inf.get("h", 32))
		var s := minf(r.size.x / w, r.size.y / h) * (1.5 if id == "leuchtfeuer" else 1.15)
		var dst := Rect2(r.get_center() - Vector2(w, h) * s * 0.5, Vector2(w, h) * s)
		var src := Rect2(int(e[1]) * w, 0, w, h)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		ci.draw_texture_rect_region(tex, dst, src, Color(1, 1, 1, 0.95))
	var sb2 := StyleBoxFlat.new()
	sb2.draw_center = false
	sb2.set_corner_radius_all(6)
	sb2.set_border_width_all(2)
	sb2.border_color = Color(EDGE.lerp(Color("ffc94a"), pulse), 0.85)
	ci.draw_style_box(sb2, r.grow(1))
