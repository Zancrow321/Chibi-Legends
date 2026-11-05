class_name BollwerkIcons
extends RefCounted
## Skill icons of Bollwerk: the PixelLab effect sprites on a dark graphite
## plate with an amber edge and a soft breathing glow (HUD and style menu).

const BG := Color("1a1d23")
const EDGE := Color("ffb02e")
const MAP := {
	"salve": "salve", "durchbruch": "durchbruch", "splitterwurf": "explosion",
	"schildprotokoll": "schildwand", "kettenhaken": "kettenhaken", "orbitalsturz": "staubstoss",
	"meisterzug": "zwillingsrohr", "zwillingsrohr": "zwillingsrohr", "lanzenstrahl": "plasmatreffer",
	"letzter_befehl": "schrotladung",
}


static func draw(ci: CanvasItem, r: Rect2, id: String, t := 0.0) -> void:
	if PixelSkillIcon.try_draw(ci, r, "bollwerk", id, t, BG, EDGE, Color(1.0, 0.85, 0.5)):
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(6)
	sb.border_color = Color(EDGE, 0.5)
	sb.set_border_width_all(1)
	ci.draw_style_box(sb, r)
	var tex := FederFx.tex(BollwerkFx.bw(MAP.get(id, "")))
	if tex == null:
		return
	var pulse := 0.5 + 0.5 * sin(t * (3.0 if id == "meisterzug" else 2.0) + r.position.x * 0.05)
	var inner := r.grow(-2)
	ci.draw_texture_rect(tex, inner, false)
	ci.draw_texture_rect(tex, inner, false, Color(1, 1, 1, 0.1 + 0.12 * pulse))
