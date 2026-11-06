class_name WorldBossPanel
extends Control
## Weltenriss: small best list under the quest line of the combat HUD.
## Who fights right now, the own damage and place, the top five.

const INK := Color("1a1020")
const PAPER := Color("f4ead8")
const BLUE := Color("7fd8ff")

var director: WorldBossDirector
var font: Font


func _ready() -> void:
	font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


## 12345 -> "12.345"
static func num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _draw() -> void:
	if director == null:
		return
	var W := get_viewport_rect().size.x
	var x := W - 352.0
	var w := 336.0
	var y := 162.0
	var rows: Array = director.top.slice(0, 5)
	var h := 64.0 + 20.0 * rows.size()
	draw_rect(Rect2(x + 3, y + 3, w, h), Color(INK, 0.55))
	draw_rect(Rect2(x, y, w, h), Color(0.08, 0.1, 0.16, 0.86))
	draw_rect(Rect2(x, y, w, h), Color(BLUE, 0.7), false, 2.0)
	var head := "Weltenriss"
	if director.online:
		head += "  ·  %d kämpfen gerade" % maxi(director.fighters_now, 1 if director.is_fighting() else 0)
	else:
		head += "  ·  offline"
	_text(Vector2(x + 12, y + 20), head, 15, BLUE)
	var mine := director.own_damage()
	var share := 100.0 * float(mine) / maxf(1.0, float(director.max_hp))
	var line := "Dein Schaden: %s  (%.1f %%)" % [num(mine), share]
	if director.my_rank > 0:
		line += "  ·  Platz %d" % director.my_rank
	var enough := share >= WorldBossDirector.MIN_SHARE * 100.0
	_text(Vector2(x + 12, y + 42), line, 14, PAPER if enough else Color(PAPER, 0.7))
	if not enough and director.status == "aktiv":
		_text(Vector2(x + w - 12, y + 42), "Beute ab 0,5 %", 12, Color(1.0, 0.75, 0.5), HORIZONTAL_ALIGNMENT_RIGHT, 0.0)
	var ry := y + 64.0
	for i in rows.size():
		var r: Dictionary = rows[i]
		var col := Color("ffd25c") if bool(r.get("me", false)) else PAPER
		_text(Vector2(x + 12, ry), "%d. %s" % [i + 1, str(r.get("name", "?"))], 14, col)
		_text(Vector2(x + w - 12, ry), num(int(r.get("damage", 0))), 14, col, HORIZONTAL_ALIGNMENT_RIGHT, 0.0)
		ry += 20.0


func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	if width == 0.0:
		pos.x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		width = -1.0
		align = HORIZONTAL_ALIGNMENT_LEFT
	draw_string_outline(font, pos, s, align, width, size, 4, Color(INK, col.a))
	draw_string(font, pos, s, align, width, size, col)
