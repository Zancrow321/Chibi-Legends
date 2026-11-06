class_name Hud
extends Control
## Whole HUD drawn in one Control: status bars (top left), notice bar,
## minimap + quests + training stats (top right), skill bar and menu bar
## (bottom right), currencies (bottom left), EXP bar, help and toasts.

const PANEL := Color(0.09, 0.07, 0.16, 0.86)
const PANEL_LIGHT := Color(0.16, 0.13, 0.27, 0.92)
const TRIM := Color("f2c14e")
const TEXT := Color("fbf3e4")
const MUTED := Color("b9b0cf")
const HP := Color("e8433a")
const AURA := Color("36b8f0")
const BADGE := Color("ff7a59")

const MENU := [
	["Charakter", "Customizing und Ausrüstung kommen in Phase 2"],
	["Pass", "Herausforderungen und Saison-Pass (P)"],
	["Inventar", "Inventar kommt in Phase 2"],
	["Gruppe", "Koop für bis zu 4 Spieler kommt in Phase 4"],
	["Gilde", "Gilden kommen in Phase 3"],
	["Gacha", "Gacha kommt in Phase 5"],
	["Shop", "Shop kommt in Phase 5"],
	["Optionen", "Einstellungen kommen in Phase 2"],
]

var room: TrainingRoom
var font: Font
## Steuerungshilfe: standardmaessig aus, H oder Optionen schalten sie ein (gespeichert).
var show_help: bool:
	get:
		GameSettings.ensure()
		return GameSettings.controls_help
	set(v):
		GameSettings.ensure()
		GameSettings.controls_help = v
## Manga-Panel-Skin (PixelLab-Teile, Taste I oder ?ui=alt schaltet zurueck auf das alte UI)
var manga := true
var _menu_rects: Array = []
var _hover := -1
var _t := 0.0
var _cutin_text := ""
var _cutin_color := Color.WHITE
var _cutin_t := -1.0  # seconds since the super cut-in started, <0 = off
var menu: GlutatemMenu
var _gauge_shown := 0.0

const CUTIN_TIME := 1.0
const FEED_TIME := TrainingRoom.FEED_TIME


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")
	menu = GlutatemMenu.new()
	menu.room = room
	add_child(menu)
	if OS.has_feature("web") and "ui=alt" in str(JavaScriptBridge.eval("window.location.search", true)):
		manga = false


func show_cutin(text: String, col: Color) -> void:
	_cutin_text = text
	_cutin_color = col
	_cutin_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _cutin_t >= 0.0:
		_cutin_t += delta
		if _cutin_t > CUTIN_TIME:
			_cutin_t = -1.0
	# parent is a CanvasLayer, so anchors alone don't size us: follow the viewport
	position = Vector2.ZERO
	size = get_viewport_rect().size
	if Input.is_action_just_pressed("toggle_help"):
		show_help = not show_help
		GameSettings.save()
	if Input.is_action_just_pressed("toggle_ui"):
		manga = not manga
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _menu_index(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _menu_index(event.position)
		if i >= 0:
			match str(MENU[i][0]):
				"Charakter":
					get_tree().call_group("game_menu", "open", 0)
				"Inventar":
					get_tree().call_group("game_menu", "open", 1)
				"Optionen":
					get_tree().call_group("game_menu", "open", GameMenu.OPTIONS_TAB)
				"Gacha":
					get_tree().call_group("gacha", "open")
				"Pass":
					get_tree().call_group("season_pass", "open")
				_:
					room.toast(MENU[i][1])
			accept_event()


func _menu_index(p: Vector2) -> int:
	for i in _menu_rects.size():
		if (_menu_rects[i] as Rect2).has_point(p):
			return i
	return -1


# --- drawing helpers -------------------------------------------------------

func _panel(r: Rect2, col := PANEL, radius := 10, border := Color(0, 0, 0, 0)) -> void:
	if manga and (col == PANEL or col == PANEL_LIGHT):
		if r.size.y >= 40.0:
			_skin("panel", r)
		else:
			# schmale Leisten: Papier mit Tuscherand und etwas Raster rechts
			var sbs := StyleBoxFlat.new()
			sbs.bg_color = UiSkin.PAPER
			sbs.border_color = UiSkin.INK
			sbs.set_border_width_all(2)
			draw_style_box(sbs, r)
			_halftone(Rect2(r.end.x - minf(60.0, r.size.x * 0.3), r.position.y + 3, minf(60.0, r.size.x * 0.3) - 3, r.size.y - 6), Color(UiSkin.INK, 0.25))
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	if manga:
		# Tusche-Look fuer die kleinen Farbflaechen: eckig, schwarzer Rand
		sb.set_corner_radius_all(mini(radius, 2))
		if col.a > 0.5 and r.size.y > 8:
			border = Color(UiSkin.INK, col.a)
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(2)
	draw_style_box(sb, r)


func _skin(part: String, r: Rect2, tint := Color.WHITE) -> void:
	var sb := UiSkin.box(part)
	sb.modulate_color = tint
	draw_style_box(sb, r)


func _text(pos: Vector2, s: String, size: int, col := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 4) -> void:
	if manga and outline > 0:
		# Manga: Tusche-Schrift mit Papier-Rand, Gold wird Signalrot
		var a := col.a
		if col.is_equal_approx(Color(TEXT, a)) or col.is_equal_approx(Color(MUTED, a)):
			col = Color(UiSkin.INK, a)
		elif col.is_equal_approx(Color(TRIM, a)):
			col = Color(UiSkin.RED.darkened(0.15), a)
		elif col.get_luminance() > 0.55:
			col = Color(col.darkened(0.45), a)
		draw_string_outline(font, pos, s, align, width, size, outline, Color(UiSkin.PAPER, 0.95 * a))
		draw_string(font, pos, s, align, width, size, col)
		return
	if outline > 0:
		draw_string_outline(font, pos, s, align, width, size, outline, Color(0.05, 0.03, 0.1, 0.9))
	draw_string(font, pos, s, align, width, size, col)


func _bar(r: Rect2, frac: float, col: Color, label: String) -> void:
	if manga:
		var fr := Rect2(r.position.x, r.get_center().y - 16, r.size.x, 32)
		var inner := UiSkin.inner("hp_bar", fr)
		_skin("hp_bar", fr)
		inner.size.x *= clampf(frac, 0.0, 1.0)
		if inner.size.x > 1:
			draw_rect(inner, col)
			draw_rect(Rect2(inner.position, Vector2(inner.size.x, 3)), Color(1, 1, 1, 0.35))
			_halftone(Rect2(inner.position + Vector2(0, inner.size.y * 0.55), Vector2(inner.size.x, inner.size.y * 0.45)), Color(0, 0, 0, 0.22))
		_text(Vector2(inner.position.x, r.position.y + r.size.y * 0.72), label, int(r.size.y * 0.62), TEXT, HORIZONTAL_ALIGNMENT_CENTER, fr.end.x - inner.position.x - 10)
		return
	_panel(r, Color(0.05, 0.04, 0.1, 0.95), int(r.size.y / 2), Color(1, 1, 1, 0.15))
	var inner := r.grow(-3)
	inner.size.x *= clampf(frac, 0.0, 1.0)
	if inner.size.x > 2:
		_panel(inner, col, int(inner.size.y / 2))
		_panel(Rect2(inner.position + Vector2(4, 2), Vector2(maxf(inner.size.x - 8, 0), inner.size.y * 0.3)), Color(1, 1, 1, 0.25), 3)
	_text(Vector2(r.position.x, r.position.y + r.size.y * 0.72), label, int(r.size.y * 0.62), TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


## Manga-Raster: Punktgitter, jede zweite Reihe versetzt.
func _halftone(r: Rect2, col: Color, step := 4) -> void:
	var row := 0
	var y := r.position.y + 1
	while y < r.end.y:
		var x := r.position.x + (step * 0.5 if row % 2 == 1 else 0.0)
		while x < r.end.x - 1:
			draw_rect(Rect2(x, y, 2, 2), col)
			x += step
		y += step * 0.5
		row += 1


static func _fmt(n: float) -> String:
	var s := str(int(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	return out


func _draw() -> void:
	if room == null or room.player == null:
		return
	var W := size.x
	var H := size.y
	# combat HUD stays slim: no menu row or currencies (they live in the
	# overworld HUD), training stats and controls only with H
	_draw_status()
	_draw_notice(W)
	_draw_right_column(W)
	_draw_skill_bar(W, H)
	_draw_bottom_left(H)
	if show_help:
		_draw_training()
		_draw_help()
	_draw_combo(W, H)
	if _cutin_t >= 0.0:
		_draw_cutin(W, H)
	_draw_loot_feed(H)
	if room.toast_time > 0.0:
		var a := minf(1.0, room.toast_time * 3.0)
		var tw := font.get_string_size(room.toast_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 48
		_panel(Rect2(W / 2 - tw / 2, H * 0.24, tw, 44), Color(0.09, 0.07, 0.16, 0.9 * a), 22, Color(TRIM, a))
		_text(Vector2(W / 2 - tw / 2, H * 0.24 + 29), room.toast_text, 22, Color(TEXT, a), HORIZONTAL_ALIGNMENT_CENTER, tw)


## Beute-Leiste: the last finds slide in at the left edge, each in the
## frame of its rarity (ItemFrame), animated from Episch.
func _draw_loot_feed(H: float) -> void:
	var y := H * 0.36
	for e in room.loot_feed:
		var it: Dictionary = e[0]
		var age := float(e[1])
		var slide := clampf(age * 6.0, 0.0, 1.0)
		var fade := clampf((FEED_TIME - age) * 2.5, 0.0, 1.0)
		var x := -260.0 * (1.0 - slide * (2.0 - slide)) + 14.0
		var col := Loot.color(it)
		var w := 250.0
		var card := Rect2(x, y, w, 58)
		draw_rect(card.grow(2), Color(0, 0, 0, 0.55 * fade))
		draw_rect(card, Color(PANEL, 0.9 * fade))
		draw_rect(Rect2(card.position, Vector2(4, card.size.y)), Color(col, fade))
		var box := Rect2(x + 10, y + 5, 48, 48)
		if fade > 0.05:
			ItemFrame.box(self, box, it, _t)
		_text(Vector2(x + 68, y + 25), Loot.display_name(it), 17, Color(col.lightened(0.25), fade), HORIZONTAL_ALIGNMENT_LEFT, w - 74)
		_text(Vector2(x + 68, y + 46), Loot.rarity_info(it).name + " · " + Profile.SLOT_NAMES.get(str(it.get("slot", "")), ""), 13, Color(MUTED, fade), HORIZONTAL_ALIGNMENT_LEFT, w - 74)
		y += 66.0


## Combo counter at the right edge while a combo runs.
func _draw_combo(W: float, H: float) -> void:
	if room.combo < 3:
		return
	var fade := clampf((TrainingRoom.COMBO_GAP - room.combo_time) * 3.0, 0.0, 1.0)
	var pop := 1.0 + 0.25 * maxf(0.0, 0.15 - room.combo_time) / 0.15
	var x := W - 190.0
	var y := H * 0.42
	var col := Color("ffd25c") if room.combo < 10 else Color("ff7a2a") if room.combo < 20 else Color("fff4d0")
	_text(Vector2(x, y), str(room.combo), int(52 * pop), Color(col, fade), HORIZONTAL_ALIGNMENT_RIGHT, 110, 6)
	_text(Vector2(x + 116, y - 4), "HITS", 22, Color(TEXT, fade), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	var bar := Rect2(x + 10, y + 10, 160, 5)
	draw_rect(bar, Color(0, 0, 0, 0.5 * fade))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * (1.0 - room.combo_time / TrainingRoom.COMBO_GAP), bar.size.y)), Color(col, fade))


func _draw_status() -> void:
	var p := room.player
	# level badge
	_panel(Rect2(16, 16, 124, 92), BADGE, 12, Color("ffd7a8"))
	_panel(Rect2(16, 16, 124, 30), BADGE.darkened(0.18), 12)
	_text(Vector2(16, 38), "Schüler", 18, TEXT, HORIZONTAL_ALIGNMENT_CENTER, 124)
	_text(Vector2(26, 94), "Lv.", 24, Color("5a1d10"), HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
	_text(Vector2(64, 98), str(p.level), 46, TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)
	# bars
	var x := 152.0
	_panel(Rect2(x, 16, 310, 26), PANEL, 13)
	if p.glut != null:
		_text(Vector2(x + 14, 35), "Akademie-Schüler", 17, TEXT)
		_text(Vector2(x + 180, 35), "KK " + _fmt(p.combat_power()), 16, TRIM)
	else:
		_text(Vector2(x, 35), "Akademie-Schüler", 17, TEXT, HORIZONTAL_ALIGNMENT_CENTER, 310)
	var dy := 4.0 if manga else 0.0  # Manga-Rahmen sind etwas hoeher
	_bar(Rect2(x, 48 + dy, 310, 26), p.hp / p.max_hp, HP, "%s / %s" % [_fmt(p.hp), _fmt(p.max_hp)])
	if p.glut == null:
		_bar(Rect2(x, 80 + 2 * dy, 310, 22), p.aura / p.max_aura, AURA, "Aura %d / %d%s" % [int(p.aura), int(p.max_aura), "  (unendlich)" if p.infinite_aura else ""])
		_panel(Rect2(x, 108 + 3 * dy, 240, 26), PANEL, 13, Color(TRIM, 0.7))
		_text(Vector2(x + 14, 127 + 3 * dy), "Kampfkraft", 16, TRIM)
		_text(Vector2(x + 124, 127 + 3 * dy), _fmt(p.combat_power()), 18, TEXT)
		return
	_draw_gauge(Rect2(x, 80 + 2 * dy, 310, 22))
	_draw_style_panel(Rect2(x, 108 + 3 * dy, 310, 26))


## Legendenleiste: three Stufen of 100; full Stufen glow, a full bar pulses.
func _draw_gauge(r: Rect2) -> void:
	var p := room.player
	_gauge_shown = move_toward(_gauge_shown, p.gauge, get_process_delta_time() * 400.0)
	var frame := Rect2(r.position.x, r.get_center().y - 17, r.size.x, 34)
	var inner := r.grow(-3)
	if manga:
		inner = UiSkin.inner("super_bar", frame)
		_skin("super_bar", frame)
	else:
		_panel(r, Color(0.05, 0.04, 0.1, 0.95), int(r.size.y / 2), Color(1, 1, 1, 0.15))
	var seg := inner.size.x / 3.0
	var full := int(p.gauge / 100.0)
	for i in 3:
		var sr := Rect2(inner.position.x + i * seg + (1 if i > 0 else 0), inner.position.y, seg - 2, inner.size.y)
		var f := clampf((_gauge_shown - i * 100.0) / 100.0, 0.0, 1.0)
		if f <= 0.0:
			continue
		var fr := Rect2(sr.position, Vector2(sr.size.x * f, sr.size.y))
		var col := Color("ff7a2a") if i < full else Color("c2331f")
		if full >= 3:
			col = Color("ff9a2a").lerp(Color("fff4d0"), 0.3 + 0.3 * sin(_t * 8.0))
		_panel(fr, col, 6)
		_panel(Rect2(fr.position + Vector2(3, 2), Vector2(maxf(fr.size.x - 6, 0), fr.size.y * 0.3)), Color(1, 1, 1, 0.25), 3)
	if manga:
		for i in range(1, 3):
			# schraege Tusche-Trennstriche wie Panel-Kanten
			var bx := inner.position.x + i * seg
			draw_line(Vector2(bx + 4, inner.position.y), Vector2(bx - 4, inner.end.y), Color(UiSkin.INK), 3)
			draw_line(Vector2(bx + 6, inner.position.y), Vector2(bx - 2, inner.end.y), Color(1, 1, 1, 0.5), 1)
	else:
		for i in range(1, 3):
			draw_rect(Rect2(inner.position.x + i * seg - 1, inner.position.y - 1, 2, inner.size.y + 2), Color(0.05, 0.04, 0.1))
	var label := "Legendenleiste  %d / 3%s" % [full, "  (unendlich)" if p.infinite_aura else ""]
	_text(Vector2(r.position.x, r.position.y + r.size.y * 0.72), label, int(r.size.y * 0.62), TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


## Style, Atemrhythmus (glow stage of the blade) and the Weißglut timer.
func _draw_style_panel(r: Rect2) -> void:
	if room.player.glut is MondCaster:
		_draw_mond_panel(r, room.player.glut)
		return
	var g := room.player.glut
	if g is KlangCaster:
		_draw_klang_panel(r, g)
		return
	if g is FeuerCaster:
		_draw_feuer_panel(r, g)
		return
	if g is FederCaster:
		_draw_feder_panel(r, g)
		return
	if g is GrenzCaster:
		_draw_grenz_panel(r, g)
		return
	if g is WirbelCaster:
		_draw_wirbel_panel(r, g)
		return
	if g is BollwerkCaster:
		_draw_bollwerk_panel(r, g)
		return
	if g is FormCaster:
		_draw_form_panel(r, g)
		return
	_panel(r, PANEL, 13, Color("ff9a2a", 0.6))
	_text(Vector2(r.position.x + 14, r.position.y + 19), room.player.style.style_name(), 16, Color("ffb347"))
	var names := ["Rot", "Orange", "Weiß"]
	var cols := [Color("ff3b1f"), Color("ff9a2a"), Color("fff4d0")]
	for i in 3:
		var c := Vector2(r.position.x + 106 + i * 22, r.get_center().y)
		var on := g.stage > i
		draw_circle(c, 7, Color(0.05, 0.03, 0.06))
		if on:
			draw_circle(c, 9 + (2 if i == 2 and g.stage == 3 else 0) * (0.5 + 0.5 * sin(_t * 12.0)), Color(cols[i], 0.25))
			draw_circle(c, 5.5, cols[i])
		else:
			draw_arc(c, 5.5, 0, TAU, 12, Color(cols[i], 0.35), 1.5)
	var info: String = names[g.stage - 1] if g.stage > 0 else "kalt"
	if g.buff_time > 0.0:
		var br := Rect2(r.position.x + 176, r.position.y + 8, 120, 10)
		draw_rect(br, Color(0.05, 0.03, 0.06))
		draw_rect(Rect2(br.position, Vector2(br.size.x * g.buff_time / maxf(0.01, g.buff_max), br.size.y)), Color("fff4d0").lerp(Color("ffd25c"), 0.5 + 0.5 * sin(_t * 10.0)))
		_text(Vector2(br.position.x, r.position.y + r.size.y - 2), "Weißglut +%d %%" % int(round(g.buff_bonus * 100.0)), 11, TEXT, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 3)
	else:
		_text(Vector2(r.position.x + 176, r.position.y + 19), "Klinge: " + info, 15, MUTED)


## Baukasten styles: the Kern (name, pips, state text) in the style colours.
func _draw_form_panel(r: Rect2, g: FormCaster) -> void:
	var main := g.col("main")
	var light := g.col("light")
	_panel(r, PANEL, 13, Color(main, 0.6))
	_text(Vector2(r.position.x + 14, r.position.y + 19), room.player.style.style_name(), 16, light)
	var n := int(g.kern_max) if g.kern_type != "fokus" else 1
	var v := g.kern_pips()
	var x0 := r.position.x + 132.0
	if g.kern_type == "fokus":
		var br := Rect2(x0, r.get_center().y - 4, 60, 8)
		draw_rect(br, Color(main, 0.25))
		draw_rect(Rect2(br.position, Vector2(br.size.x * clampf(v, 0.0, 1.0), br.size.y)), light if v >= 0.99 else main)
		x0 += 66.0
	else:
		for i in n:
			var c := Vector2(x0 + i * 15, r.get_center().y)
			if v > float(i) + 0.01:
				draw_circle(c, 7.0, Color(main, 0.3))
				draw_circle(c, 4.6, light if v >= float(n) else main)
			else:
				draw_arc(c, 4.6, 0, TAU, 12, Color(main, 0.35), 1.5)
		x0 += n * 15 + 4
	var info := g.kern_info()
	var label := str(g.kern.get("name", ""))
	_text(Vector2(x0, r.position.y + 19), info if info != "" else label, 13, light if info != "" else MUTED)


## Lauffeuer: the Brandherde on the field (at most 3) as little flames.
func _draw_feuer_panel(r: Rect2, g: FeuerCaster) -> void:
	_panel(r, PANEL, 13, Color("ff8a2a", 0.6))
	_text(Vector2(r.position.x + 14, r.position.y + 19), room.player.style.style_name(), 16, Color("ffc94a"))
	var n := g.herd_count()
	for i in FeuerCaster.MAX_HERDE:
		var c := Vector2(r.position.x + 112 + i * 22, r.get_center().y + 2)
		var on := n > i
		var col := Color("ff8a2a") if on else Color("ff8a2a", 0.3)
		var fl := 1.0 + (0.15 * sin(_t * 14.0 + i) if on else 0.0)
		var pts := PackedVector2Array([c + Vector2(-5, 4), c + Vector2(5, 4), c + Vector2(3, -2) * fl, c + Vector2(0, -9) * fl, c + Vector2(-3, -2) * fl])
		if on:
			draw_circle(c + Vector2(0, -1), 9, Color(col, 0.22))
			draw_colored_polygon(pts, col)
			draw_circle(c + Vector2(0, 1), 2.5, Color("fff3c8"))
		else:
			draw_polyline(pts + PackedVector2Array([pts[0]]), col, 1.5)
	var info := "Brandherde: %d / %d" % [n, FeuerCaster.MAX_HERDE]
	if g.normal_element() == "feuer":
		info = "Fäuste brennen!"
	_text(Vector2(r.position.x + 182, r.position.y + 19), info, 15, MUTED if g.normal_element() == "" else Color("ffc94a"))


## Schwarzmond: the Mondphase as a moon that fills, plus the timers of the
## Schattenlarve, the Neumond form or the Erschöpfung.
func _draw_mond_panel(r: Rect2, g: MondCaster) -> void:
	var cyan := Color("6fe3ff")
	_panel(r, PANEL, 13, Color(cyan, 0.55))
	_text(Vector2(r.position.x + 14, r.position.y + 19), room.player.style.style_name(), 16, Color("cfe9ff"))
	var c := Vector2(r.position.x + 132, r.get_center().y)
	var rad := 8.0
	draw_circle(c, rad + 1.5, Color(0.02, 0.02, 0.05))
	draw_circle(c, rad, Color("1c1b33"))
	# lit part of the moon: Sichel, Halbmond, Vollmond
	if g.stage >= 3:
		var pulse := 0.5 + 0.5 * sin(_t * 10.0)
		draw_circle(c, rad + 3.0 * pulse, Color(cyan, 0.25))
		draw_circle(c, rad, Color("f4f8ff"))
	elif g.stage == 1:
		draw_colored_polygon(MondFx.crescent(c, Vector2.RIGHT, rad, 1.5, 1.0), Color("f4f8ff"))
	elif g.stage == 2:
		var pts := PackedVector2Array()
		for i in 17:
			var a := -PI / 2.0 + PI * i / 16.0
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
		draw_colored_polygon(pts, Color("f4f8ff"))
	draw_arc(c, rad, 0, TAU, 20, Color(cyan, 0.7), 1.2)
	var info := g.phase_name()
	var bx := r.position.x + 150
	var timer := 0.0
	var tmax := 1.0
	var tcol := cyan
	var tname := ""
	if g.larve_time > 0.0:
		timer = g.larve_time; tmax = MondCaster.LARVE_TIME; tcol = Color("ff3b4a"); tname = "Schattenlarve"
	elif g.neumond_time > 0.0:
		timer = g.neumond_time; tmax = g.neumond_max; tcol = Color("f4f8ff"); tname = "Neumond"
	elif g.erschoepft > 0.0:
		timer = g.erschoepft; tmax = 10.0; tcol = Color("8a8fa8"); tname = "Erschöpft"
	if timer > 0.0:
		var br := Rect2(bx, r.position.y + 8, 146, 10)
		draw_rect(br, Color(0.05, 0.03, 0.06))
		draw_rect(Rect2(br.position, Vector2(br.size.x * timer / maxf(0.01, tmax), br.size.y)), tcol)
		_text(Vector2(br.position.x, r.position.y + r.size.y - 2), "%s · %s" % [tname, info], 11, TEXT, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 3)
	else:
		_text(Vector2(bx, r.position.y + 19), "Mondphase: " + info, 15, MUTED)


## Wirbelwille: three Teamwork-Marken (small kites), the clones out and
## the Orkanmantel timer.
func _draw_wirbel_panel(r: Rect2, g: WirbelCaster) -> void:
	var turq := Color("5fe3e0")
	var gold := Color("ffd36a")
	var ice := Color("bff6ff")
	_panel(r, PANEL, 13, Color(turq, 0.55))
	_text(Vector2(r.position.x + 14, r.position.y + 19), room.player.style.style_name(), 16, TEXT)
	var full := g.marks >= WirbelCaster.MAX_MARKS
	for i in WirbelCaster.MAX_MARKS:
		var c := Vector2(r.position.x + 118 + i * 18, r.get_center().y)
		var kite := PackedVector2Array([c + Vector2(0, -8), c + Vector2(5, -1), c + Vector2(0, 8), c + Vector2(-5, -1)])
		var col := gold if full else turq
		if g.marks > i:
			if full:
				draw_circle(c, 9.0 + 1.5 * sin(_t * 12.0), Color(gold, 0.25))
			draw_colored_polygon(kite, col)
			draw_line(c + Vector2(0, -8), c + Vector2(0, 8), Color(1, 1, 1, 0.5), 1.0)
			draw_line(c + Vector2(0, 8), c + Vector2(-3, 12), Color(col, 0.8), 1.0)
		else:
			kite.append(kite[0])
			draw_polyline(kite, Color(turq, 0.35), 1.5)
	var x := r.position.x + 178
	for i in WirbelCaster.MAX_CLONES:
		var cc := Vector2(x + i * 14, r.get_center().y)
		var out := i < g.clone_count()
		draw_circle(cc + Vector2(0, -4), 3.0, Color(ice, 0.9 if out else 0.2))
		draw_rect(Rect2(cc + Vector2(-3, -1), Vector2(6, 7)), Color(ice, 0.9 if out else 0.2))
	var info := "Marken %d" % g.marks
	if g.mantle_time > 0.0:
		info = "MANTEL %.1f s" % g.mantle_time
	elif full:
		info = "Gemeinsam!"
	_text(Vector2(x + WirbelCaster.MAX_CLONES * 14 + 4, r.position.y + 19), info, 13, gold if g.mantle_time > 0.0 or full else MUTED)


## Spannkraft: Spannung (3 pips while holding), Federringe (Übergänge left)
## and the Grenzenlos timer.
func _draw_feder_panel(r: Rect2, g: FederCaster) -> void:
	var coral := Color("ff5a4a")
	var yellow := Color("ffd23c")
	var sky := Color("3f9fd8")
	_panel(r, PANEL, 13, Color(coral, 0.55))
	_text(Vector2(r.position.x + 14, r.position.y + 19), room.player.style.style_name(), 16, TEXT)
	var tens: int = g.tension if g.busy() else 0
	for i in 3:
		var c := Vector2(r.position.x + 116 + i * 16, r.get_center().y)
		var on := tens > i
		var col := yellow if tens >= 3 else coral
		if on:
			draw_circle(c, 7.5 + (1.5 * sin(_t * 14.0) if tens >= 3 else 0.0), Color(col, 0.3))
			draw_circle(c, 5.0, col)
		else:
			draw_arc(c, 5.0, 0, TAU, 12, Color(coral, 0.35), 1.5)
	var n := g.max_chain()
	for i in n:
		var c2 := Vector2(r.position.x + 176 + i * 14, r.get_center().y)
		var full := i < g.chain_left
		draw_arc(c2, 5.0, 0, TAU, 14, Color(sky, 0.95 if full else 0.25), 2.2 if full else 1.2)
	var info := ""
	if g.is_free():
		info = "FREI %.1f s" % g.free_time
	elif g.phase == "charge":
		info = ["", "Gespannt I", "Gespannt II", "VOLL"][tens]
	elif g._snap_t > 0.0 and g.chain_left > 0:
		info = "Schwung!"
	_text(Vector2(r.position.x + 176 + n * 14 + 4, r.position.y + 19), info, 13, yellow if g.is_free() else MUTED)


## Grenzbrecher: the Ki-Leiste in 5 Abschnitte, Überhitzung and state.
func _draw_grenz_panel(r: Rect2, g: GrenzCaster) -> void:
	var sky := Color("6fd0ff")
	var white := Color("f4fbff")
	var orange := Color("ff9a3c")
	_panel(r, PANEL, 13, Color(sky, 0.55))
	_text(Vector2(r.position.x + 12, r.position.y + 19), room.player.style.style_name(), 13, TEXT)
	var bar := Rect2(r.position.x + 108, r.get_center().y - 7, r.size.x - 118, 14)
	draw_rect(bar.grow(2), Color(0.02, 0.03, 0.08))
	var seg := bar.size.x / 5.0
	for i in 5:
		var fill := clampf((g.ki - i * 20.0) / 20.0, 0.0, 1.0)
		var sr := Rect2(bar.position.x + i * seg + 1, bar.position.y, seg - 2, bar.size.y)
		draw_rect(sr, Color(sky, 0.12))
		if fill > 0.0:
			var col := sky if fill >= 1.0 else sky.darkened(0.3)
			if g.burst_time > 0.0:
				col = white.lerp(sky, 0.3 + 0.3 * sin(_t * 10.0))
			elif g.gathering():
				col = sky.lerp(white, 0.3 + 0.3 * sin(_t * 14.0))
			draw_rect(Rect2(sr.position, Vector2(sr.size.x * fill, sr.size.y)), col)
			draw_rect(Rect2(sr.position, Vector2(sr.size.x * fill, 3)), Color(1, 1, 1, 0.35))
	# the 20 Ki line (below it: no Ki-Züge)
	draw_line(Vector2(bar.position.x + seg, bar.position.y - 3), Vector2(bar.position.x + seg, bar.end.y + 3), Color(white, 0.6), 1.0)
	var info := "Ki %d" % int(g.ki)
	var col2 := MUTED
	if g.burst_time > 0.0:
		info = "GRENZBRUCH %.1f s" % g.burst_time
		col2 = white
	elif g.gathering():
		info = "SAMMELN…"
		col2 = sky
	elif g.heat > 0:
		info = "ÜBERHITZT +%d %%" % (g.heat * 50)
		col2 = orange
	elif g.exhaust > 0.0:
		info = "erschöpft"
	elif g.ki < 20.0:
		info = "KI-MANGEL"
		col2 = orange
	_text(Vector2(bar.position.x, bar.end.y - 2), info, 11, col2 if col2 != MUTED else TEXT, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 4)


## Bollwerk: shield bar, three Einsatzenergie cells, magazine and grenades.
func _draw_bollwerk_panel(r: Rect2, g: BollwerkCaster) -> void:
	var shield_col := Color("5fb8ff")
	var gold := Color("ffd36a")
	var amber := Color("ffb02e")
	_panel(r, PANEL, 13, Color(amber, 0.55))
	_text(Vector2(r.position.x + 14, r.position.y + 19), room.player.style.style_name(), 16, TEXT)
	var cy := r.get_center().y
	# shield bar with hexagon ticks; red blink while broken
	var sb := Rect2(r.position.x + 100, cy - 5, 64, 10)
	draw_rect(sb.grow(1), Color(0.03, 0.04, 0.07))
	var k := g.shield / maxf(1.0, g.shield_max)
	var broken := g.shield <= 0.0
	if broken:
		draw_rect(sb, Color(1.0, 0.25, 0.2, 0.25 + 0.25 * sin(_t * 12.0)))
	else:
		draw_rect(Rect2(sb.position, Vector2(sb.size.x * k, sb.size.y)), shield_col)
		draw_rect(Rect2(sb.position, Vector2(sb.size.x * k, 3)), Color(1, 1, 1, 0.35))
		if g._since_hit >= 3.5 and k < 1.0:
			draw_rect(Rect2(sb.position.x + sb.size.x * k - 2, sb.position.y, 2, sb.size.y), Color(1, 1, 1, 0.5 + 0.5 * sin(_t * 18.0)))
	for i in range(1, 4):
		draw_line(Vector2(sb.position.x + sb.size.x * i / 4.0, sb.position.y), Vector2(sb.position.x + sb.size.x * i / 4.0, sb.end.y), Color(0, 0, 0, 0.45), 1)
	# energy cells
	var emax := int(g.rules.get("energy_max", 3))
	for i in emax:
		var cr := Rect2(r.position.x + 172 + i * 13, cy - 6, 10, 12)
		if g.energy > i:
			if g.energy >= emax:
				draw_rect(cr.grow(2), Color(gold, 0.25 + 0.15 * sin(_t * 12.0)))
			draw_rect(cr, gold)
			draw_rect(Rect2(cr.position, Vector2(cr.size.x, 3)), Color(1, 1, 1, 0.4))
		else:
			draw_rect(cr, Color(gold, 0.3), false, 1.2)
	# magazine (or reload bar) and grenade pips
	var mx := r.position.x + 214
	if g.reload_t > 0.0:
		var rk := 1.0 - g.reload_t / maxf(0.01, g.reload_max)
		draw_rect(Rect2(mx, cy - 3, 40, 6), Color(0.03, 0.04, 0.07))
		draw_rect(Rect2(mx, cy - 3, 40 * rk, 6), amber)
		_text(Vector2(mx, r.position.y + 12), "LADEN", 10, amber)
	else:
		var low := g.ammo <= int(g.mag * 0.25)
		_text(Vector2(mx, r.position.y + 19), "%d/%d" % [g.ammo, g.mag], 13, Color("ff6a5a") if low else TEXT)
	for i in int(g.rules.get("grenades", 2)):
		var c := Vector2(r.position.x + 266 + i * 12, cy)
		var part := clampf(g.grenades - i, 0.0, 1.0)
		if part >= 1.0:
			draw_circle(c, 4.5, Color("8fd16a"))
			draw_circle(c + Vector2(-1, -1), 1.5, Color(1, 1, 1, 0.5))
		else:
			draw_arc(c, 4.5, 0, TAU, 14, Color("8fd16a", 0.3), 1.2)
			if part > 0.0:
				draw_arc(c, 4.5, -PI / 2.0, -PI / 2.0 + TAU * part, 14, Color("8fd16a"), 2.0)


## Gleichklang: Einklang as six small bells, a beat dot and the state.
func _draw_klang_panel(r: Rect2, g: KlangCaster) -> void:
	var ink := Color("2f5d9e")
	var full_col := Color("6a3fc0")
	_panel(r, PANEL, 13, Color("8fd3ff", 0.6))
	_text(Vector2(r.position.x + 14, r.position.y + 19), room.player.style.style_name(), 16, TEXT)
	var full := g.klang >= KlangCaster.MAX_KLANG
	for i in KlangCaster.MAX_KLANG:
		var c := Vector2(r.position.x + 124 + i * 17, r.get_center().y + 1)
		var on := g.klang > i
		var col := full_col if full else ink
		var bell := PackedVector2Array([c + Vector2(-5, 4), c + Vector2(-4, -2), c + Vector2(-2, -5), c + Vector2(2, -5), c + Vector2(4, -2), c + Vector2(5, 4)])
		if on:
			if full:
				draw_circle(c, 8 + 1.5 * sin(_t * 12.0 + i), Color(Color("a884f3"), 0.35))
			draw_colored_polygon(bell, col)
			draw_circle(c + Vector2(0, 5), 1.6, Color("c07a30"))
		else:
			bell.append(bell[0])
			draw_polyline(bell, Color(ink, 0.35), 1.2)
	# beat: a dot that flashes on every beat (grey while the beat is lost)
	var bp := 1.0 - g.beat_progress()
	var bc := Vector2(r.position.x + 236, r.get_center().y)
	var lost := g._lost > 0.0
	draw_circle(bc, 3.0 + 4.0 * pow(bp, 6.0), Color(0.5, 0.5, 0.55) if lost else Color(ink, 0.45 + 0.55 * pow(bp, 6.0)))
	var info := "EINKLANG" if full else ("Takt weg" if lost else "Takt")
	_text(Vector2(r.position.x + 246, r.position.y + 19), info, 13, full_col if full else MUTED)


func _draw_notice(W: float) -> void:
	var wv := room.waves
	var msg2 := ""
	if room.tower != null:
		msg2 = "" if room.tower.is_fighting() else room.tower.notice()  # the boss bar takes the spot
	elif room.raid is WorldBossDirector:
		msg2 = "" if room.raid.is_fighting() else (room.raid as WorldBossDirector).notice()
	elif wv != null and wv.wave >= 0:
		var left := wv.alive.filter(func(e): return is_instance_valid(e) and e.state != "dead").size() + wv.pending()
		msg2 = "Welle %d  ·  %d Gegner" % [wv.wave + 1 + wv.round_no * EnemyWaves.WAVES.size(), left] if left > 0 else "Welle geschafft!"
	elif wv != null:
		msg2 = "Gegner warten rechts hinter den Puppen  →"
	if msg2 != "":
		var tw := font.get_string_size(msg2, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 36
		var wr := Rect2(W / 2 - tw / 2, 16, tw, 30)
		_panel(wr, PANEL, 15, Color("a46bff", 0.7) if room.tower != null else (Color("4dc8ff", 0.7) if room.is_worldboss else Color("ff9a2a", 0.6)))
		_text(Vector2(wr.position.x, 37), msg2, 18, TEXT, HORIZONTAL_ALIGNMENT_CENTER, tw)
	return
	var r := Rect2(480, 16, maxf(W - 480 - 352 - 16, 160), 26)
	_panel(r, PANEL, 13)
	var klang := room.player.glut is KlangCaster
	var tips := [
		"%s: L + Richtung, L halten = verstärkt" % room.player.style.style_name() if room.player.style != null else "L + Richtung = Zug",
		"Treffer im Takt füllen den Einklang" if klang else ("Brandherde legen, mit der Flammenfaust zünden" if room.player.glut is FeuerCaster else ("Verschiedene Züge im Combo geben Teamwork-Marken" if room.player.glut is WirbelCaster else "Verschiedene Züge im Combo heizen die Klinge")),
		"Tab: Kampfstil, Alternativen und Slots",
		"Der Sparringspfahl rechts schlägt zurück!",
		"Willkommen im Trainingswald der Akademie!",
		"Frost + Blitz ergibt einen Kristallbruch.",
		"Wind verteilt Brand als Feuersturm.",
		"Mit U bekommst du unendlich Aura.",
		"Mit C probierst du andere Looks aus.",
	]
	var msg: String = tips[int(_t / 5.0) % tips.size()]
	_text(Vector2(r.position.x + 12, 35), msg, 16, MUTED, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24, 0)


func _draw_right_column(W: float) -> void:
	var x := W - 352.0
	var w := 336.0
	_panel(Rect2(x, 16, w, 26), PANEL, 13)
	_text(Vector2(x + 14, 35), "Akademie  ·  " + str(GameFlow.area_info(GameFlow.area).title), 17, TEXT)
	# minimap
	var mm := Rect2(x, 50, w, 70)
	_panel(mm, PANEL, 10, Color(TRIM, 0.5))
	var inner := mm.grow(-8)
	var sx := inner.size.x / TrainingRoom.WIDTH
	var sy := inner.size.y / 260.0
	var to_map := func(v: Vector2) -> Vector2: return inner.position + Vector2(v.x * sx, (v.y - 120.0) * sy)
	for g in TrainingRoom.GROUND:
		var a: Vector2 = to_map.call(Vector2(g[0], g[1]))
		draw_rect(Rect2(a, Vector2(g[2] * sx, inner.end.y - a.y)), Color("4a8a3e"))
		draw_rect(Rect2(a, Vector2(g[2] * sx, 2)), Color("8fd968"))
	for pl in TrainingRoom.PLATFORMS:
		var a: Vector2 = to_map.call(Vector2(pl[0], pl[1]))
		draw_rect(Rect2(a, Vector2(pl[2] * sx, 3)), Color("8fd968"))
	for t in room.get_tree().get_nodes_in_group("targets"):
		var d: Vector2 = to_map.call(t.global_position)
		draw_rect(Rect2(d - Vector2(3, 7), Vector2(6, 7)), Color("e8433a"))
	var pp: Vector2 = to_map.call(room.player.global_position)
	var blink := 1.0 if fmod(_t, 0.8) < 0.6 else 0.6
	draw_rect(Rect2(pp - Vector2(4, 10), Vector2(8, 10)), Color(1.0, 0.85, 0.3, blink))
	# quest: one line in the fight, the full list with H
	if not show_help:
		_panel(Rect2(x, 128, w, 26), PANEL, 13)
		var quest := ("Quest: Erreiche Etage %d" % (room.tower.best + 1)) if room.is_tower else "Quest: Bezwingt Donnerhorn gemeinsam" if room.is_worldboss else "Quest: Besiege den Essenwächter" if room.is_raid else "Quest: Alle Reaktionen (%d/4)" % room.reactions_found.size()
		_text(Vector2(x + 14, 147), quest, 15, MUTED)
		return
	var q := Rect2(x, 166, w, 168)
	_panel(q, PANEL, 10)
	_panel(Rect2(x, 166, w, 30), PANEL_LIGHT, 10)
	_text(Vector2(x + 16, 187), "Hauptquest", 17, TRIM)
	_text(Vector2(x + 128, 187), "|", 17, MUTED)
	_text(Vector2(x + 146, 187), "Tagesquest", 17, MUTED)
	_text(Vector2(x + 16, 218), "Erste Lektion: Alle Reaktionen (%d/4)" % room.reactions_found.size(), 16, TEXT)
	var y := 244.0
	for id in GameData.REACTIONS:
		var info: Dictionary = GameData.REACTIONS[id]
		var done := room.reactions_found.has(id)
		_panel(Rect2(x + 18, y - 13, 16, 16), Color(0.05, 0.04, 0.1), 3, Color(info.color, 0.8))
		if done:
			draw_polyline(PackedVector2Array([Vector2(x + 21, y - 5), Vector2(x + 25, y - 1), Vector2(x + 32, y - 10)]), Color("8fd968"), 3)
		_text(Vector2(x + 44, y), info.name, 16, info.color if done else TEXT)
		_text(Vector2(x + 178, y), info.recipe, 15, MUTED)
		y += 22.0


func _draw_training() -> void:
	var x := 16.0
	var w := 360.0
	var s := Rect2(x, 146, w, 152)
	_panel(s, PANEL, 10)
	_text(Vector2(x + 16, 170), "Training", 17, TRIM)
	_text(Vector2(x + 16, 196), "Schaden pro Sek.", 16, MUTED)
	_text(Vector2(x + 190, 196), _fmt(room.dps()), 18, TEXT)
	_text(Vector2(x + 16, 218), "Gesamtschaden", 16, MUTED)
	_text(Vector2(x + 190, 218), _fmt(room.total_damage), 18, TEXT)
	_text(Vector2(x + 16, 240), "Letzte Reaktion", 16, MUTED)
	var lr := "–"
	var lc := TEXT
	if room.last_reaction != "":
		lr = GameData.REACTIONS[room.last_reaction].name
		lc = GameData.REACTIONS[room.last_reaction].color
	_text(Vector2(x + 190, 240), lr, 17, lc)
	_text(Vector2(x + 16, 266), "[U] Unendlich Leiste   [R] Abklingzeiten" if room.player.glut != null else "[U] Unendlich Aura   [R] Abklingzeiten", 15, MUTED)
	_text(Vector2(x + 16, 286), "[0] Kampf-Debug   [9] Zeitlupe", 15, MUTED)


func _draw_skill_bar(W: float, H: float) -> void:
	var p := room.player
	var slots := [
		{"label": "Leicht", "key": GameInput.key_label("light"), "icon": "faust" if (room.player.glut is FeuerCaster or room.player.glut is WirbelCaster or room.player.glut is GrenzCaster) else "attack", "cd": 0.0, "max": 1.0},
		{"label": "Schwer", "key": GameInput.key_label("heavy"), "icon": "tritt" if (room.player.glut is FeuerCaster or room.player.glut is WirbelCaster or room.player.glut is GrenzCaster) else "heavy", "cd": 0.0, "max": 1.0},
		{"label": "Dash", "key": "Shift", "icon": "dash", "cd": p.dash_cd, "max": Player.DASH_COOLDOWN},
	]
	var arrows := ["", "→", "↑", "↓"]
	var sk := GameInput.key_label("special")
	if p.glut != null:
		_draw_style_slots(slots, arrows, sk)
		return
	for i in p.build.size():
		var s: Dictionary = GameData.SKILLS[p.build[i]]
		slots.append({"label": s.name, "key": arrows[i] + sk, "icon": p.build[i], "cd": p.cooldowns[i], "max": s.cooldown, "cost": s.cost})
	var sup: Dictionary = GameData.SUPER
	slots.append({"label": sup.name, "key": GameInput.key_label("super"), "icon": sup.id, "cd": p.super_cd, "max": sup.cooldown, "cost": sup.cost})
	var slot := 46.0
	var gap := 8.0
	var total := slots.size() * (slot + gap) - gap + 24
	var bar := Rect2(W / 2 - total / 2, H - 22 - slot - 30, total, slot + 24)
	_panel(bar, Color(PANEL, 0.6), int(bar.size.y / 2), Color(TRIM, 0.35))
	for i in slots.size():
		var sl: Dictionary = slots[i]
		var r := Rect2(bar.position.x + 12 + i * (slot + gap), bar.position.y + 12, slot, slot)
		_slot(r)
		_draw_icon(r.grow(-6), sl.icon)
		if sl.cd > 0.0:
			var frac: float = clampf(sl.cd / sl.max, 0.0, 1.0)
			draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * frac)), Color(0, 0, 0, 0.62))
			_text(Vector2(r.position.x, r.position.y + 31), "%.1f" % sl.cd, 17, TEXT, HORIZONTAL_ALIGNMENT_CENTER, slot)
		elif sl.has("cost") and not p.infinite_aura and p.aura < sl.cost:
			draw_rect(r, Color(0.1, 0.2, 0.6, 0.45))
		var kw := maxf(24.0, font.get_string_size(sl.key, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 10)
		_panel(Rect2(r.position + Vector2(-4, -6), Vector2(kw, 20)), Color("2a2140"), 5, Color(TRIM, 0.8))
		_text(Vector2(r.position.x - 4, r.position.y + 10), sl.key, 15, TEXT, HORIZONTAL_ALIGNMENT_CENTER, kw, 0)


## Skill bar with the style: J, K, dash, the four Züge of the special
## button and the Meisterzug.
func _draw_style_slots(slots: Array, arrows: Array, sk: String) -> void:
	var p := room.player
	var g := p.glut
	var W := size.x
	var H := size.y
	for i in FightingStyle.DIRS.size():
		var z: String = p.style.zug_in(FightingStyle.DIRS[i])
		if z == "":
			slots.append({"label": "leer", "key": arrows[i] + sk, "icon": "", "cd": 0.0, "max": 1.0})
			continue
		slots.append({"label": p.style.zug(z).name, "key": arrows[i] + sk, "icon": z, "cd": g.cooldowns.get(z, 0.0), "max": p.style.cooldown(z), "zug": true})
	slots.append({"label": p.style.variant().get("name", "Meisterzug"), "key": GameInput.key_label("super"), "icon": "meisterzug", "cd": 0.0, "max": 1.0, "super": true})
	var slot := 46.0
	var gap := 8.0
	var total := slots.size() * (slot + gap) - gap + 24
	var bar := Rect2(W / 2 - total / 2, H - 22 - slot - 30, total, slot + 24)
	_panel(bar, Color(PANEL, 0.6), 18, Color("8fd3ff", 0.35) if p.glut is KlangCaster else Color("ff9a2a", 0.35))
	for i in slots.size():
		var sl: Dictionary = slots[i]
		var r := Rect2(bar.position.x + 12 + i * (slot + gap), bar.position.y + 12, slot, slot)
		_slot(r)
		if sl.has("zug") or sl.has("super") or sl.icon == "":
			GlutIcons.draw(self, r.grow(-6), sl.icon, _t)
		else:
			_draw_icon(r.grow(-6), sl.icon)
		if sl.cd > 0.0:
			var frac: float = clampf(sl.cd / sl.max, 0.0, 1.0)
			draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * frac)), Color(0, 0, 0, 0.62))
			_text(Vector2(r.position.x, r.position.y + 31), "%.1f" % sl.cd, 17, TEXT, HORIZONTAL_ALIGNMENT_CENTER, slot)
		if sl.has("super"):
			if p.gauge < p.style.super_cost() and not p.infinite_aura:
				draw_rect(r, Color(0.05, 0.02, 0.05, 0.55))
			else:
				var pulse := 0.5 + 0.5 * sin(_t * 8.0)
				_panel(r.grow(2), Color(0, 0, 0, 0), 9, Color(Color("ffd25c"), 0.5 + 0.5 * pulse))
		elif sl.has("zug") and (p.gauge >= 100.0 or p.infinite_aura) and sl.cd <= 0.0:
			# enough Leiste for a verstärkt Zug: small flame mark
			draw_circle(r.end - Vector2(9, 9), 6, Color(0.05, 0.02, 0.02))
			draw_circle(r.end - Vector2(9, 9), 4, Color("ff9a2a").lerp(Color("fff4d0"), 0.5 + 0.5 * sin(_t * 9.0)))
		var kw := maxf(24.0, font.get_string_size(sl.key, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 10)
		_panel(Rect2(r.position + Vector2(-4, -6), Vector2(kw, 20)), Color("2a2140"), 5, Color(TRIM, 0.8))
		_text(Vector2(r.position.x - 4, r.position.y + 10), sl.key, 15, TEXT, HORIZONTAL_ALIGNMENT_CENTER, kw, 0)


func _slot(r: Rect2) -> void:
	if manga:
		_skin("skill_slot", r.grow(6))
	else:
		_panel(r, Color(0.04, 0.03, 0.08, 0.95), 8, Color(1, 1, 1, 0.18))


func _draw_icon(r: Rect2, icon: String) -> void:
	var c := r.get_center()
	match icon:
		"heavy":
			_panel(r, Color("6a3a4a"), 6)
			draw_line(c + Vector2(-14, 14), c + Vector2(14, -14), Color("e8eef2"), 9)
			draw_line(c + Vector2(-14, 14), c + Vector2(14, -14), Color.WHITE, 4)
			draw_line(c + Vector2(-17, 5), c + Vector2(-5, 17), TRIM, 6)
		"attack":
			_panel(r, Color("4a4d6a"), 6)
			draw_line(c + Vector2(-14, 14), c + Vector2(14, -14), Color("e8eef2"), 5)
			draw_line(c + Vector2(-14, 14), c + Vector2(14, -14), Color.WHITE, 2)
			draw_line(c + Vector2(-16, 6), c + Vector2(-6, 16), TRIM, 4)
		"faust", "tritt":
			# Lauffeuer is unarmed: a fist / a kicking boot instead of a sword
			_panel(r, Color("6a2a1a"), 6)
			var hot := Color("ffc94a") if room.player.glut != null and room.player.glut.normal_element() == "feuer" else Color("e8d6c0")
			if icon == "faust":
				draw_rect(Rect2(c + Vector2(-10, -8), Vector2(18, 16)), hot)
				for k in 4:
					draw_line(c + Vector2(-10 + k * 4.5, -8), c + Vector2(-10 + k * 4.5, -3), Color("6a2a1a"), 1.5)
				draw_rect(Rect2(c + Vector2(-16, -4), Vector2(6, 10)), hot)
				draw_line(c + Vector2(10, -6), c + Vector2(17, -6), Color("ff8a2a"), 2)
				draw_line(c + Vector2(10, 0), c + Vector2(19, 0), Color("ff8a2a"), 2)
				draw_line(c + Vector2(10, 6), c + Vector2(17, 6), Color("ff8a2a"), 2)
			else:
				draw_colored_polygon(PackedVector2Array([c + Vector2(-14, -14), c + Vector2(-6, -14), c + Vector2(-4, 4), c + Vector2(14, 6), c + Vector2(14, 13), c + Vector2(-14, 13)]), hot)
				draw_arc(c + Vector2(4, 0), 18, -2.2, -0.6, 10, Color("ff8a2a"), 3)
		"dash":
			_panel(r, Color("3a5a7a"), 6)
			for k in 3:
				var o := Vector2(-12 + k * 9, 0)
				draw_polyline(PackedVector2Array([c + o + Vector2(-4, -10), c + o + Vector2(4, 0), c + o + Vector2(-4, 10)]), Color(0.8, 0.95, 1.0, 0.5 + k * 0.25), 4)
		"flammenschnitt":
			_panel(r, Color("7a2a1a"), 6)
			draw_arc(c + Vector2(-6, 2), 16, -1.4, 1.4, 12, Color("ff7a3d"), 7)
			draw_arc(c + Vector2(-6, 2), 14, -1.2, 1.2, 12, Color("ffe08a"), 3)
		"frostlanze":
			_panel(r, Color("1f4a6a"), 6)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-16, 12), c + Vector2(12, -14), c + Vector2(16, -16), c + Vector2(14, -10), c + Vector2(-12, 16)]), Color("7fd8ff"))
			draw_line(c + Vector2(-12, 12), c + Vector2(12, -12), Color.WHITE, 2)
		"kettenblitz":
			_panel(r, Color("5a4a14"), 6)
			draw_polyline(PackedVector2Array([c + Vector2(4, -18), c + Vector2(-8, 2), c + Vector2(4, 0), c + Vector2(-6, 18)]), Color("ffe45c"), 5)
			draw_polyline(PackedVector2Array([c + Vector2(4, -18), c + Vector2(-8, 2), c + Vector2(4, 0), c + Vector2(-6, 18)]), Color.WHITE, 2)
		"legendenstrahl":
			_panel(r, Color("1a2a5a"), 6, Color(TRIM, 0.9))
			for k in 8:
				var ang := _t * 1.5 + TAU * k / 8.0
				draw_line(c, c + Vector2(cos(ang), sin(ang)) * 20.0, Color(1.0, 0.85, 0.35, 0.5), 2)
			draw_rect(Rect2(c + Vector2(-6, -5), Vector2(24, 10)), Color("5cc8ff"))
			draw_rect(Rect2(c + Vector2(-6, -2), Vector2(24, 4)), Color.WHITE)
			draw_circle(c + Vector2(-8, 0), 8, Color("5cc8ff"))
			draw_circle(c + Vector2(-8, 0), 5, Color.WHITE)
		"sturmklinge":
			_panel(r, Color("1f5a3a"), 6)
			draw_arc(c + Vector2(-8, 0), 16, -1.1, 1.1, 12, Color("4fd18a"), 6)
			draw_arc(c + Vector2(-2, 0), 12, -1.0, 1.0, 12, Color("d8ffe6"), 3)


func _draw_menu(W: float, H: float) -> void:
	_menu_rects.clear()
	var bw := 84.0
	var gap := 4.0
	var total := MENU.size() * (bw + gap) - gap
	var x0 := W - 16 - total
	var y := H - 72.0
	for i in MENU.size():
		var r := Rect2(x0 + i * (bw + gap), y, bw, 50)
		_menu_rects.append(r)
		var hover := i == _hover
		if manga:
			_skin("button", r.grow(2), Color(1.0, 0.72, 0.66) if hover else Color.WHITE)
		else:
			_panel(r, PANEL_LIGHT if hover else PANEL, 8, Color(TRIM, 0.9 if hover else 0.35))
		_draw_menu_icon(Vector2(r.get_center().x, y + 17), i)
		_text(Vector2(r.position.x, y + 44), MENU[i][0], 14, TEXT, HORIZONTAL_ALIGNMENT_CENTER, bw)


func _draw_menu_icon(c: Vector2, i: int) -> void:
	var col := Color("ffd7a8")
	match i:
		0:  # character: head
			draw_circle(c, 8, col)
			draw_rect(Rect2(c + Vector2(-8, -9), Vector2(16, 6)), Color("e8553a"))
		1:  # skills: book
			draw_rect(Rect2(c + Vector2(-9, -9), Vector2(18, 18)), Color("8b45c8"))
			draw_rect(Rect2(c + Vector2(-1, -9), Vector2(2, 18)), col)
		2:  # bag
			draw_rect(Rect2(c + Vector2(-9, -5), Vector2(18, 14)), Color("a8693f"))
			draw_arc(c + Vector2(0, -5), 6, PI, TAU, 8, Color("a8693f"), 3)
		3:  # party: two heads
			draw_circle(c + Vector2(-6, 0), 6, col)
			draw_circle(c + Vector2(6, 0), 6, Color("7fd8ff"))
		4:  # guild: banner
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -10), c + Vector2(8, -10), c + Vector2(8, 8), c + Vector2(0, 3), c + Vector2(-8, 8)]), Color("2f5fd0"))
			draw_circle(c + Vector2(0, -3), 3, TRIM)
		5:  # gacha: star crystal
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -11), c + Vector2(9, 0), c + Vector2(0, 11), c + Vector2(-9, 0)]), Color("ff8fc8"))
			draw_rect(Rect2(c + Vector2(-2, -6), Vector2(3, 6)), Color.WHITE)
		6:  # shop: coin
			draw_circle(c, 9, TRIM)
			draw_circle(c, 6, Color("d89a2a"))
		7:  # settings: gear
			draw_circle(c, 9, MUTED)
			draw_circle(c, 4, PANEL)


func _draw_bottom_left(H: float) -> void:
	if not show_help:
		_text(Vector2(16, H - 30), "H  Hilfe & Steuerung    Esc  Menü", 14, Color(MUTED, 0.8))
	# EXP bar
	_panel(Rect2(0, H - 22, size.x, 22), Color(0.05, 0.04, 0.1, 0.95), 0)
	# EXP toward the next level (Profile: lasts beyond the fight)
	var frac := Profile.exp_fraction()
	_text(Vector2(10, H - 5), "EXP %.2f %%" % (frac * 100.0), 15, TRIM, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
	var x := 110.0
	var seg := (size.x - x - 10) / 10.0
	for i in 10:
		draw_rect(Rect2(x + i * seg + 1, H - 16, seg - 3, 10), Color(1, 1, 1, 0.12))
		var fill := clampf(frac * 10.0 - i, 0.0, 1.0)
		if fill > 0.0:
			draw_rect(Rect2(x + i * seg + 1, H - 16, (seg - 3) * fill, 10), Color("7fd8ff"))
			draw_rect(Rect2(x + i * seg + 1, H - 16, (seg - 3) * fill, 2), Color("d8f6ff"))


func _draw_help() -> void:
	var glut := room.player.glut != null
	var klang := room.player.glut is KlangCaster
	var r := Rect2(16, 280, 400, 424 if klang else 404)
	_panel(r, PANEL, 10)
	_text(Vector2(32, 312), "Steuerung", 17, TRIM)
	var lines := [
		["A / D", "Laufen"], ["Leertaste", "Springen, 2x Doppelsprung"], ["Shift", "Dash (in der Luft 1x)"],
		["J / K", "Leicht (3er-Kette) / Schwer"], ["W/S/A/D +", "Richtung: oben/unten/vor"],
		["L (+ Richtung)", "Zug von " + room.player.style.style_name()], ["L halten", "Verstärkt (1 Stufe Leiste)"],
		["P", "Meisterzug (3 Stufen)"], ["Tab / M", "Kampfstil: Alternativen, Slots"],
		["J + K", "Griff (Wurf)"], ["Q halten", "Blocken (kurz vorher = Perfekt)"],
		["Shift im Treffer", "Befreiungsstoß (1 Stufe)"], ["U / R", "Unendlich Leiste / Abklingzeiten"],
		["N", "Abendlicht an/aus"], ["V", "Effekt-Stärke"], ["T / C / H", "Figur / Charaktere / Hilfe"],
		["F / I", "Kämpfer wechseln / UI-Stil"],
	] if glut else [
		["A / D", "Laufen"], ["Leertaste", "Springen, 2x Doppelsprung"], ["S + Leertaste", "Durch Plattform fallen"],
		["Shift", "Dash (in der Luft 1x)"], ["J", "Leicht (3er-Kette)"], ["K", "Schwer"],
		["L", "Spezial (Fähigkeit)"], ["W/S/A/D +", "Richtung: oben/unten/vor"],
		["J + K", "Griff (Wurf)"], ["P", "Super: Legendenstrahl"], ["V", "Effekt-Stärke wechseln"],
		["T", "Figur: Testfigur / Sammlung"], ["F", "Kämpfer wechseln (Importe)"], ["C", "Charaktere"],
		["H / I", "Hilfe / UI-Stil"],
	]
	if klang:
		lines.append(["X / Y", "Takt-Hilfe / Klangfarbe"])
	var y := 338.0
	for l in lines:
		_text(Vector2(32, y), l[0], 15, TEXT)
		_text(Vector2(150, y), l[1], 15, MUTED)
		y += 20.0 if glut else 22.0


## Fighting-game super cut-in: a diagonal band slides in with speed lines
## and the move name, holds, then slides out.
func _draw_cutin(W: float, H: float) -> void:
	var t := _cutin_t / CUTIN_TIME
	var slide := 0.0
	if t < 0.15:
		slide = 1.0 - t / 0.15
	elif t > 0.8:
		slide = -(t - 0.8) / 0.2
	var off := slide * W * 1.2
	var cy := H * 0.42
	var bh := 92.0
	var skew := 60.0
	var pts := PackedVector2Array([
		Vector2(-skew + off, cy - bh / 2 + 30), Vector2(W + skew + off, cy - bh / 2 - 30),
		Vector2(W + skew + off, cy + bh / 2 - 30), Vector2(-skew + off, cy + bh / 2 + 30)])
	draw_colored_polygon(pts, Color(0.04, 0.03, 0.12, 0.88))
	# speed lines inside the band
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		var y := cy + rng.randf_range(-bh / 2 + 6, bh / 2 - 6)
		var x := fposmod(rng.randf() * W - _t * 2400.0 * rng.randf_range(0.6, 1.2), W + 300) - 150 + off
		var tilt := -60.0 * (x - W / 2) / W
		draw_line(Vector2(x, y + tilt), Vector2(x + rng.randf_range(80, 220), y + tilt - 10), Color(_cutin_color, 0.35), 2)
	draw_polyline(PackedVector2Array([pts[0], pts[1]]), TRIM, 4)
	draw_polyline(PackedVector2Array([pts[3], pts[2]]), TRIM, 4)
	var fs := 64
	var tw := font.get_string_size(_cutin_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tx := W / 2 - tw / 2 + off
	draw_string_outline(font, Vector2(tx, cy + 22), _cutin_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color("1a1020"))
	draw_string(font, Vector2(tx, cy + 22), _cutin_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE.lerp(_cutin_color, 0.35 + 0.25 * sin(_t * 30.0)))
