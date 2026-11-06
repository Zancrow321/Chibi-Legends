class_name FormIcons
extends RefCounted
## Skill icons of the Baukasten fighting styles (HUD skill bar and style
## menu): the PixelLab icon (assets/combat/icons/<style>/<id>.png) on a plate
## in the style's dark colour with a breathing edge in its main colour.

static var _info: Dictionary = {}


static func _load(style_id: String) -> Dictionary:
	if _info.has(style_id):
		return _info[style_id]
	var res := {"form": false, "colors": {}}
	var f := FileAccess.open("res://assets/combat/styles/%s.json" % style_id, FileAccess.READ)
	if f != null:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary and str(d.get("caster", "")) == "form":
			res = {"form": true, "colors": d.get("colors", {})}
	_info[style_id] = res
	return res


## True when the style is a Baukasten style (its icons are drawn here).
static func handles(style_id: String) -> bool:
	return bool(_load(style_id).form)


static func _col(style_id: String, key: String, def: String) -> Color:
	return Color(str(_load(style_id).colors.get(key, def)))


static func draw(ci: CanvasItem, r: Rect2, style_id: String, id: String, t := 0.0) -> void:
	var dark := _col(style_id, "dark", "1a1a2a")
	var main := _col(style_id, "main", "8fd3ff")
	var light := _col(style_id, "light", "ffffff")
	if PixelSkillIcon.try_draw(ci, r, style_id, id, t, dark, main, light):
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = dark
	sb.set_corner_radius_all(6)
	sb.border_color = main
	sb.set_border_width_all(2)
	ci.draw_style_box(sb, r)
	var c := r.get_center()
	var pulse := 0.5 + 0.5 * sin(t * 3.0 + r.position.x * 0.05)
	ci.draw_circle(c, r.size.x * (0.22 + 0.04 * pulse), Color(main, 0.8))
	ci.draw_circle(c, r.size.x * 0.1, light)
