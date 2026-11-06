class_name FederIcons
extends RefCounted
## Skill icons of Spannkraft: the PixelLab effect sprites on a dark plate
## with a soft breathing glow (HUD skill bar and style menu).

const BG := Color("1d1626")
const EDGE := Color("ff5a4a")
const MAP := {
	"schnappfaust": "schnappfaust", "fegebein": "fegebein", "katapult": "katapult",
	"prallbauch": "prallbauch", "spannzug": "spannzug", "fallbeilferse": "fallbeil",
	"meisterzug": "grenzenlos", "dampfhagel": "dampfhagel", "federkanone": "federkanone",
	"grenzenlos": "grenzenlos",
}


static func draw(ci: CanvasItem, r: Rect2, id: String, t := 0.0) -> void:
	if PixelSkillIcon.try_draw(ci, r, "spannkraft", id, t, BG, EDGE, Color(1.0, 0.8, 0.6)):
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(6)
	sb.border_color = Color(EDGE, 0.5)
	sb.set_border_width_all(1)
	ci.draw_style_box(sb, r)
	var tex := FederFx.tex(MAP.get(id, ""))
	if tex == null:
		return
	var pulse := 0.5 + 0.5 * sin(t * (3.0 if id == "meisterzug" else 2.0) + r.position.x * 0.05)
	var inner := r.grow(-2)
	ci.draw_texture_rect(tex, inner, false)
	ci.draw_texture_rect(tex, inner, false, Color(1, 1, 1, 0.1 + 0.12 * pulse))
