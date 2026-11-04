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
	["Fähigkeiten", "Fähigkeiten-Auswahl und Set-Boni kommen in Phase 2"],
	["Inventar", "Inventar kommt in Phase 2"],
	["Gruppe", "Koop für bis zu 4 Spieler kommt in Phase 4"],
	["Gilde", "Gilden kommen in Phase 3"],
	["Gacha", "Gacha kommt in Phase 5"],
	["Shop", "Shop kommt in Phase 5"],
	["Optionen", "Einstellungen kommen in Phase 2"],
]

var room: TrainingRoom
var font: Font
var show_help := true
var _menu_rects: Array = []
var _hover := -1
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")


func _process(delta: float) -> void:
	_t += delta
	# parent is a CanvasLayer, so anchors alone don't size us: follow the viewport
	position = Vector2.ZERO
	size = get_viewport_rect().size
	if Input.is_action_just_pressed("toggle_help"):
		show_help = not show_help
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _menu_index(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _menu_index(event.position)
		if i >= 0:
			room.toast(MENU[i][1])
			accept_event()


func _menu_index(p: Vector2) -> int:
	for i in _menu_rects.size():
		if (_menu_rects[i] as Rect2).has_point(p):
			return i
	return -1


# --- drawing helpers -------------------------------------------------------

func _panel(r: Rect2, col := PANEL, radius := 10, border := Color(0, 0, 0, 0)) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(2)
	draw_style_box(sb, r)


func _text(pos: Vector2, s: String, size: int, col := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 4) -> void:
	if outline > 0:
		draw_string_outline(font, pos, s, align, width, size, outline, Color(0.05, 0.03, 0.1, 0.9))
	draw_string(font, pos, s, align, width, size, col)


func _bar(r: Rect2, frac: float, col: Color, label: String) -> void:
	_panel(r, Color(0.05, 0.04, 0.1, 0.95), int(r.size.y / 2), Color(1, 1, 1, 0.15))
	var inner := r.grow(-3)
	inner.size.x *= clampf(frac, 0.0, 1.0)
	if inner.size.x > 2:
		_panel(inner, col, int(inner.size.y / 2))
		_panel(Rect2(inner.position + Vector2(4, 2), Vector2(maxf(inner.size.x - 8, 0), inner.size.y * 0.3)), Color(1, 1, 1, 0.25), 3)
	_text(Vector2(r.position.x, r.position.y + r.size.y * 0.72), label, int(r.size.y * 0.62), TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


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
	_draw_status()
	_draw_notice(W)
	_draw_right_column(W)
	_draw_skill_bar(W, H)
	_draw_menu(W, H)
	_draw_bottom_left(H)
	_draw_training()
	if show_help:
		_draw_help()
	if room.toast_time > 0.0:
		var a := minf(1.0, room.toast_time * 3.0)
		var tw := font.get_string_size(room.toast_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 48
		_panel(Rect2(W / 2 - tw / 2, H * 0.24, tw, 44), Color(0.09, 0.07, 0.16, 0.9 * a), 22, Color(TRIM, a))
		_text(Vector2(W / 2 - tw / 2, H * 0.24 + 29), room.toast_text, 22, Color(TEXT, a), HORIZONTAL_ALIGNMENT_CENTER, tw)


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
	_text(Vector2(x, 35), "Akademie-Schüler", 17, TEXT, HORIZONTAL_ALIGNMENT_CENTER, 310)
	_bar(Rect2(x, 48, 310, 26), p.hp / p.max_hp, HP, "%s / %s" % [_fmt(p.hp), _fmt(p.max_hp)])
	_bar(Rect2(x, 80, 310, 22), p.aura / p.max_aura, AURA, "Aura %d / %d%s" % [int(p.aura), int(p.max_aura), "  (unendlich)" if p.infinite_aura else ""])
	_panel(Rect2(x, 108, 240, 26), PANEL, 13, Color(TRIM, 0.7))
	_text(Vector2(x + 14, 127), "Kampfkraft", 16, TRIM)
	_text(Vector2(x + 124, 127), _fmt(p.combat_power()), 18, TEXT)


func _draw_notice(W: float) -> void:
	var r := Rect2(480, 16, maxf(W - 480 - 352 - 16, 160), 26)
	_panel(r, PANEL, 13)
	var tips := [
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
	_text(Vector2(x + 14, 35), "Akademie  ·  Trainingswald", 17, TEXT)
	# minimap
	var mm := Rect2(x, 50, w, 108)
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
	# quests
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
	var s := Rect2(x, 146, w, 132)
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
	_text(Vector2(x + 16, 266), "[U] Unendlich Aura   [R] Abklingzeiten", 15, MUTED)


func _draw_skill_bar(W: float, H: float) -> void:
	var p := room.player
	var slots := [
		{"label": "Angriff", "key": GameInput.key_label("attack"), "icon": "attack", "cd": 0.0, "max": 1.0},
		{"label": "Dash", "key": "Shift", "icon": "dash", "cd": p.dash_cd, "max": Player.DASH_COOLDOWN},
	]
	for i in p.build.size():
		var s: Dictionary = GameData.SKILLS[p.build[i]]
		slots.append({"label": s.name, "key": GameInput.key_label("skill_%d" % (i + 1)), "icon": p.build[i], "cd": p.cooldowns[i], "max": s.cooldown, "cost": s.cost})
	var slot := 62.0
	var gap := 8.0
	var total := slots.size() * (slot + gap) - gap + 24
	var bar := Rect2(W - 16 - total, H - 156, total, slot + 24)
	_panel(bar, PANEL, int(bar.size.y / 2), Color(TRIM, 0.55))
	for i in slots.size():
		var sl: Dictionary = slots[i]
		var r := Rect2(bar.position.x + 12 + i * (slot + gap), bar.position.y + 12, slot, slot)
		_panel(r, Color(0.04, 0.03, 0.08, 0.95), 8, Color(1, 1, 1, 0.18))
		_draw_icon(r.grow(-6), sl.icon)
		if sl.cd > 0.0:
			var frac: float = clampf(sl.cd / sl.max, 0.0, 1.0)
			draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * frac)), Color(0, 0, 0, 0.62))
			_text(Vector2(r.position.x, r.position.y + 40), "%.1f" % sl.cd, 20, TEXT, HORIZONTAL_ALIGNMENT_CENTER, slot)
		elif sl.has("cost") and not p.infinite_aura and p.aura < sl.cost:
			draw_rect(r, Color(0.1, 0.2, 0.6, 0.45))
		var kw := maxf(24.0, font.get_string_size(sl.key, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 10)
		_panel(Rect2(r.position + Vector2(-4, -6), Vector2(kw, 20)), Color("2a2140"), 5, Color(TRIM, 0.8))
		_text(Vector2(r.position.x - 4, r.position.y + 10), sl.key, 15, TEXT, HORIZONTAL_ALIGNMENT_CENTER, kw, 0)


func _draw_icon(r: Rect2, icon: String) -> void:
	var c := r.get_center()
	match icon:
		"attack":
			_panel(r, Color("4a4d6a"), 6)
			draw_line(c + Vector2(-14, 14), c + Vector2(14, -14), Color("e8eef2"), 5)
			draw_line(c + Vector2(-14, 14), c + Vector2(14, -14), Color.WHITE, 2)
			draw_line(c + Vector2(-16, 6), c + Vector2(-6, 16), TRIM, 4)
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
	_panel(Rect2(16, H - 66, 170, 32), PANEL, 16)
	draw_colored_polygon(PackedVector2Array([Vector2(36, H - 61), Vector2(46, H - 50), Vector2(36, H - 39), Vector2(26, H - 50)]), Color("ff8fc8"))
	_text(Vector2(56, H - 43), "0  Sternkristalle", 16, TEXT)
	_panel(Rect2(194, H - 66, 140, 32), PANEL, 16)
	draw_circle(Vector2(214, H - 50), 8, Color("7fd8ff"))
	_text(Vector2(230, H - 43), "0  Splitter", 16, TEXT)
	# EXP bar
	_panel(Rect2(0, H - 22, size.x, 22), Color(0.05, 0.04, 0.1, 0.95), 0)
	_text(Vector2(10, H - 5), "EXP 0,00 %", 15, TRIM, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
	var x := 110.0
	var seg := (size.x - x - 10) / 10.0
	for i in 10:
		draw_rect(Rect2(x + i * seg + 1, H - 16, seg - 3, 10), Color(1, 1, 1, 0.12))


func _draw_help() -> void:
	var r := Rect2(16, 286, 360, 228)
	_panel(r, PANEL, 10)
	_text(Vector2(32, 312), "Steuerung", 17, TRIM)
	var lines := [
		["A / D", "Laufen"], ["Leertaste", "Springen, 2x Doppelsprung"], ["S + Leertaste", "Durch Plattform fallen"],
		["Shift", "Dash"], ["J", "Katana-Combo (3 Hiebe)"], ["K L I O", "Fähigkeiten 1–4"],
		["C", "Look wechseln"], ["H", "Hilfe ein/aus"],
	]
	var y := 338.0
	for l in lines:
		_text(Vector2(32, y), l[0], 15, TEXT)
		_text(Vector2(160, y), l[1], 15, MUTED)
		y += 22.0
