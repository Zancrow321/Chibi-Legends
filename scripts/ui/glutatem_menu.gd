class_name GlutatemMenu
extends Control
## Style menu (Tab): the seven skills of the fighting style, for each the
## Grundform and its three alternatives (exactly one is active, chosen
## before the fight), the four slots of the special button and the
## Meisterzug variant. Pauses the game while open.
## Keys: up/down skill, left/right alternative, 1-4 slot, Tab/Esc close.
## Mouse: click a skill, an alternative or a slot.

const PANEL := Color(0.07, 0.05, 0.1, 0.96)
const CARD := Color(0.13, 0.08, 0.1, 0.95)
const TRIM := Color("ffb347")
const TEXT := Color("fbf3e4")
const MUTED := Color("b9a8a0")
const HOT := Color("ff9a2a")
const SLOT_KEYS := {"neutral": "L", "forward": "→ L", "up": "↑ L", "down": "↓ L"}
const SLOT_NAMES := {"neutral": "Neutral", "forward": "Vor", "up": "Oben", "down": "Unten"}

var room: TrainingRoom
var font: Font
var is_open := false
var _row := 0
var _rows: Array = []  # zug ids + "meisterzug"
var _row_rects: Array = []
var _card_rects: Array = []  # [Rect2, alt id]
var _slot_rects: Array = []  # [Rect2, dir]
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _style() -> FightingStyle:
	return room.player.style


func open() -> void:
	if room.player.in_super or _style() == null:
		return
	is_open = true
	visible = true
	_rows = _style().zug_order.duplicate()
	_rows.append("meisterzug")
	get_tree().paused = true


func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = room.fx.is_frozen()
	room.toast("Kampfstil gespeichert")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("style_menu"):
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = event.physical_keycode
		match k:
			KEY_ESCAPE:
				close()
			KEY_UP, KEY_W:
				_row = (_row - 1 + _rows.size()) % _rows.size()
			KEY_DOWN, KEY_S:
				_row = (_row + 1) % _rows.size()
			KEY_LEFT, KEY_A:
				_cycle_alt(-1)
			KEY_RIGHT, KEY_D:
				_cycle_alt(1)
			KEY_1, KEY_2, KEY_3, KEY_4:
				_assign(FightingStyle.DIRS[k - KEY_1])
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		for i in _row_rects.size():
			if (_row_rects[i] as Rect2).has_point(p):
				_row = i
		for cr in _card_rects:
			if (cr[0] as Rect2).has_point(p):
				_pick(cr[1])
		for sr in _slot_rects:
			if (sr[0] as Rect2).has_point(p):
				_assign(sr[1])
		get_viewport().set_input_as_handled()
	elif event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func _options(id: String) -> Array:
	var st := _style()
	if id == "meisterzug":
		var out: Array = []
		for v in st.variants():
			out.append({"id": v.id, "name": v.name, "desc": v.desc, "sp": v.get("sp", 0)})
		return out
	var z := st.zug(id)
	var opts: Array = [{"id": "", "name": "Grundform", "desc": z.desc, "sp": z.get("sp", 1)}]
	for a in z.get("alts", []):
		opts.append({"id": a.id, "name": a.name, "desc": a.desc, "sp": a.get("sp", 2)})
	return opts


func _active(id: String) -> String:
	if id == "meisterzug":
		return _style().super_variant
	return _style().active_alt.get(id, "")


func _pick(alt_id: String) -> void:
	var id: String = _rows[_row]
	if id == "meisterzug":
		_style().set_variant(alt_id)
	else:
		_style().set_alt(id, alt_id)


func _cycle_alt(d: int) -> void:
	var id: String = _rows[_row]
	var opts := _options(id)
	var i := 0
	for j in opts.size():
		if opts[j].id == _active(id):
			i = j
	_pick(opts[(i + d + opts.size()) % opts.size()].id)


func _assign(dir: String) -> void:
	var id: String = _rows[_row]
	if id == "meisterzug":
		return
	_style().assign(id, dir)


func _process(delta: float) -> void:
	_t += delta
	if is_open:
		position = Vector2.ZERO
		size = get_parent().size if get_parent() is Control else get_viewport_rect().size
		queue_redraw()


# --- drawing -------------------------------------------------------------------

func _panel(r: Rect2, col: Color, radius := 10, border := Color(0, 0, 0, 0), bw := 2) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	draw_style_box(sb, r)


func _text(pos: Vector2, s: String, fs: int, col := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(font, pos, s, align, width, fs, 4, Color(0.04, 0.02, 0.05, 0.9))
	draw_string(font, pos, s, align, width, fs, col)


func _text_r(right: Vector2, s: String, fs: int, col := TEXT) -> void:
	var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_text(right - Vector2(tw, 0), s, fs, col)


func _draw() -> void:
	if not is_open:
		return
	var st := _style()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.0, 0.03, 0.6))
	var w := minf(1080.0, size.x - 40.0)
	var h := minf(620.0, size.y - 40.0)
	var box := Rect2((size.x - w) / 2.0, (size.y - h) / 2.0, w, h)
	_panel(box, PANEL, 16, Color(TRIM, 0.7))
	# header with an ember glow line
	var x0 := box.position.x
	var y0 := box.position.y
	_text(Vector2(x0 + 28, y0 + 44), "Kampfstil: " + st.style_name(), 30, TEXT)
	_text(Vector2(x0 + 28, y0 + 70), "Feueratmung · Schmiede  ·  Atemrhythmus: verschiedene Züge im Combo heizen die Klinge (Rot, Orange, Weiß)", 15, MUTED)
	_text_r(Vector2(x0 + w - 28, y0 + 44), "Skillpunkte: alles frei im Training (voller Stil %d SP)" % st.total_sp(), 15, TRIM)
	draw_line(Vector2(x0 + 24, y0 + 84), Vector2(x0 + w - 24, y0 + 84), Color(HOT, 0.5), 2)
	# left: skill list
	_row_rects.clear()
	var lx := x0 + 24
	var ly := y0 + 100
	var lw := 300.0
	var rh := 62.0
	for i in _rows.size():
		var id: String = _rows[i]
		var r := Rect2(lx, ly + i * (rh + 6), lw, rh)
		_row_rects.append(r)
		var sel := i == _row
		_panel(r, CARD.lightened(0.08) if sel else CARD, 10, Color(HOT, 0.9) if sel else Color(1, 1, 1, 0.08))
		GlutIcons.draw(self, Rect2(r.position + Vector2(8, 8), Vector2(46, 46)), id, _t)
		var nm: String = st.data.get("meisterzug", {}).get("name", "Meisterzug") if id == "meisterzug" else st.zug(id).name
		_text(r.position + Vector2(64, 26), nm, 19, TEXT)
		var sub := ""
		for o in _options(id):
			if o.id == _active(id):
				sub = o.name
		_text(r.position + Vector2(64, 49), sub, 14, HOT if _active(id) != "" or id == "meisterzug" else MUTED)
		var badge: String = "P" if id == "meisterzug" else SLOT_KEYS.get(st.slot_of(id), "")
		if badge != "":
			var bw := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 14
			_panel(Rect2(r.end.x - bw - 8, r.position.y + 8, bw, 22), Color("2a1a14"), 6, Color(TRIM, 0.8))
			_text(Vector2(r.end.x - bw - 8, r.position.y + 25), badge, 15, TEXT, HORIZONTAL_ALIGNMENT_CENTER, bw)
	# right: details
	var id2: String = _rows[_row]
	var rx := lx + lw + 24
	var rw := box.end.x - 24 - rx
	var ry := y0 + 100
	var title: String = st.data.get("meisterzug", {}).get("name", "Meisterzug") if id2 == "meisterzug" else st.zug(id2).name
	_text(Vector2(rx, ry + 26), title, 26, TEXT)
	var info := ""
	if id2 == "meisterzug":
		info = "Super für 3 Stufen der Legendenleiste (P). Die Alternativen sind drei verschiedene Supers."
	else:
		var z := st.zug(id2)
		info = "Abklingzeit %.1f s  ·  L halten: verstärkt (1 Stufe Legendenleiste)" % float(z.get("cd", 1.0))
	_text(Vector2(rx, ry + 50), info, 15, MUTED)
	_card_rects.clear()
	var opts := _options(id2)
	var cols := 2
	var cw := (rw - 16) / cols
	var ch := 118.0
	for i in opts.size():
		var o: Dictionary = opts[i]
		var cr := Rect2(rx + (i % cols) * (cw + 16), ry + 66 + int(i / cols) * (ch + 14), cw, ch)
		_card_rects.append([cr, o.id])
		var act: bool = o.id == _active(id2)
		var glow := 0.5 + 0.5 * sin(_t * 5.0)
		_panel(cr, Color(0.22, 0.1, 0.06, 0.95) if act else CARD, 12, Color(HOT, 0.75 + 0.25 * glow) if act else Color(1, 1, 1, 0.1), 3 if act else 2)
		_text(cr.position + Vector2(16, 28), o.name, 19, TEXT if act else Color(TEXT, 0.85))
		var sp := "%d SP" % int(o.sp)
		_text_r(Vector2(cr.end.x - 16, cr.position.y + 28), sp, 15, TRIM)
		if act:
			_panel(Rect2(cr.end.x - 116, cr.position.y + 10, 52, 22), HOT, 6)
			draw_string(font, Vector2(cr.end.x - 116, cr.position.y + 27), "aktiv", HORIZONTAL_ALIGNMENT_CENTER, 52, 14, Color("2a0c08"))
		draw_multiline_string(font, cr.position + Vector2(16, 56), o.desc, HORIZONTAL_ALIGNMENT_LEFT, cw - 32, 15, 4, Color(MUTED.lightened(0.2), 1.0))
	# slots
	_slot_rects.clear()
	var sy := ry + 66 + 2 * (ch + 14) + 6
	if id2 != "meisterzug":
		_text(Vector2(rx, sy + 18), "Slot der Spezial-Taste (1-4):", 16, TEXT)
		var sw := (rw - 3 * 10) / 4.0
		for i in FightingStyle.DIRS.size():
			var d: String = FightingStyle.DIRS[i]
			var sr := Rect2(rx + i * (sw + 10), sy + 30, sw, 58)
			_slot_rects.append([sr, d])
			var holder: String = st.zug_in(d)
			var mine := holder == id2
			_panel(sr, Color(0.22, 0.1, 0.06, 0.95) if mine else CARD, 10, Color(HOT, 0.9) if mine else Color(1, 1, 1, 0.1))
			_text(sr.position + Vector2(10, 22), "%d  %s  (%s)" % [i + 1, SLOT_NAMES[d], SLOT_KEYS[d]], 15, TRIM)
			var hn: String = st.zug(holder).get("name", "leer") if holder != "" else "leer"
			_text(sr.position + Vector2(10, 46), hn, 17, TEXT if mine else MUTED)
	else:
		_text(Vector2(rx, sy + 18), "Die Legendenleiste füllt sich mit jedem Treffer und beim Kontern.", 16, MUTED)
	# footer
	_text(Vector2(x0, box.end.y - 16), "↑↓ Skill   ←→ Alternative   1-4 Slot   Maus geht auch   Tab / Esc schließen", 15, MUTED, HORIZONTAL_ALIGNMENT_CENTER, w)
