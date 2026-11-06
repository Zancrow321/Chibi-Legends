class_name RaidBossBar
extends Control
## The boss bar of a raid at the top of the screen: name, phase pips, HP
## (with a white trail of lost HP), the Wucht-Leiste below it (orange,
## red rim while locked, golden BRUCH countdown while broken) and the
## shield timer with the crystals left during a shield phase.

const INK := Color("1a1020")
const HP_COL := Color("e8433a")
const WUCHT_COL := Color("ffb347")

var director: RaidDirector
var font: Font
var _trail := 1.0
var _show := 0.0
var _t := 0.0


func _ready() -> void:
	font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	var b: Boss = director.boss if director != null else null
	var on := b != null and is_instance_valid(b) and director.is_fighting()
	_show = move_toward(_show, 1.0 if on else 0.0, delta * 3.0)
	if on:
		_trail = move_toward(_trail, b.hp / b.max_hp, delta * (0.0 if b.flash > 0.0 else 0.5))
	queue_redraw()


func _draw() -> void:
	if _show <= 0.0 or director == null or director.boss == null or not is_instance_valid(director.boss):
		return
	var b := director.boss
	var W := get_viewport_rect().size.x
	# in the gap between the HUD's player panels (left, ~464 px) and its
	# right column (map, starts at W - 352)
	var x := 480.0
	var w := maxf(260.0, W - 352.0 - 16.0 - x)
	var y := 14.0 - (1.0 - _show) * 40.0
	var a := _show
	# name + phase pips
	_text(Vector2(x, y + 16), b.label.to_upper(), 18, Color(1.0, 0.85, 0.45, a))
	for i in 3:
		var pr := Rect2(x + w - 14.0 - 16.0 * (2 - i), y + 4, 10, 10)
		draw_rect(pr.grow(1), Color(INK, a))
		draw_rect(pr, Color(Color("ffd25c") if b.phase > i else Color("4a3a40"), a))
	if RaidScaling.players > 1:
		_text(Vector2(x + w - 70.0, y + 16), "%d Sp." % RaidScaling.players, 12, Color(0.8, 0.75, 0.7, a), HORIZONTAL_ALIGNMENT_RIGHT, 0.0)
	# HP
	var hr := Rect2(x, y + 22, w, 14)
	draw_rect(hr.grow(2), Color(INK, a))
	draw_rect(hr, Color(0.25, 0.08, 0.1, a))
	draw_rect(Rect2(hr.position, Vector2(w * _trail, hr.size.y)), Color(1, 0.95, 0.85, a))
	var frac := b.hp / b.max_hp
	draw_rect(Rect2(hr.position, Vector2(w * frac, hr.size.y)), Color(HP_COL, a))
	draw_rect(Rect2(hr.position, Vector2(w * frac, 3)), Color(HP_COL.lightened(0.35), a))
	for t in Boss.SHIELD_AT:
		draw_rect(Rect2(x + w * t - 1, hr.position.y - 2, 2, hr.size.y + 4), Color(Color("ffd25c"), a * 0.9))
	_text(Vector2(x + w / 2.0 - 60, hr.position.y + 12), "%d / %d" % [int(ceil(b.hp)), int(b.max_hp)], 12, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	# Wucht-Leiste
	var wr := Rect2(x + 60, y + 42, w - 120, 8)
	draw_rect(wr.grow(2), Color(Color("ff3a2a") if b.wucht_locked else INK, a * (0.6 + 0.4 * sin(_t * 18.0) if b.wucht_locked else 1.0)))
	draw_rect(wr, Color(0.18, 0.12, 0.1, a))
	if b.is_broken():
		var k := b.bruch / Boss.BRUCH_TIME
		draw_rect(Rect2(wr.position, Vector2(wr.size.x * k, wr.size.y)), Color(Color("fff4d0"), a))
		_text(Vector2(wr.position.x, wr.end.y + 15), "BRUCH! +50 % Schaden", 14, Color(Color("fff4d0"), a), HORIZONTAL_ALIGNMENT_CENTER, wr.size.x)
	elif b.shielded:
		draw_rect(Rect2(wr.position, Vector2(wr.size.x * b._wucht_shown, wr.size.y)), Color(WUCHT_COL.darkened(0.4), a))
		var left := maxi(0, b.crystals.size())
		_text(Vector2(wr.position.x, wr.end.y + 15), "GLUTSCHILD  ·  %d Kristall%s  ·  %d s" % [left, "" if left == 1 else "e", int(ceil(b.shield_left))], 14, Color(Color("ffd25c"), a), HORIZONTAL_ALIGNMENT_CENTER, wr.size.x)
	else:
		draw_rect(Rect2(wr.position, Vector2(wr.size.x * b._wucht_shown, wr.size.y)), Color(WUCHT_COL, a))
		draw_rect(Rect2(wr.position, Vector2(wr.size.x * b._wucht_shown, 2)), Color(WUCHT_COL.lightened(0.4), a))
		_text(Vector2(wr.position.x - 58, wr.end.y), "WUCHT", 11, Color(0.9, 0.8, 0.65, a), HORIZONTAL_ALIGNMENT_LEFT, 0.0)
		if b.wucht_locked:
			_text(Vector2(wr.position.x, wr.end.y + 15), "Gesperrt: ausweichen!", 13, Color(Color("ff7a5a"), a), HORIZONTAL_ALIGNMENT_CENTER, wr.size.x)


func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	if width == 0.0:
		width = -1.0
	draw_string_outline(font, pos, s, align, width, size, 4, Color(INK, col.a))
	draw_string(font, pos, s, align, width, size, col)
