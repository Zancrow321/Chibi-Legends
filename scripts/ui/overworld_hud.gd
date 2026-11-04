class_name OverworldHud
extends Control
## The quiet HUD of the overworld (Manga-Panel-Skin from UiSkin, like the
## combat HUD, but much less of it): a name plate with the place, a route
## strip with the spots of the courtyard, a prompt bubble over whatever is in
## reach, the speech panel for NPCs and signs, and a few menu buttons that
## fade out while you walk. No HP, no skills, no combat numbers.

## [label, key, toast or "" , menu tab (-1 = none)]
const MENU := [
	["Sammlung", "C", "", -1],
	["Charakter", "Esc", "", 0],
	["Inventar", "", "", 1],
	["Kampfstil", "", "Den Kampfstil stellst du im Kampfareal ein (Tab)", -1],
	["Optionen", "", "", 2],
]
const TYPE_SPEED := 52.0  # characters per second

var world: Overworld
var select: CharacterSelect  # set by Main
var menu: GameMenu  # set by Main
var font: Font
var show_help := true

var _t := 0.0
var _menu_rects: Array = []
var _hover := -1
var _menu_alpha := 1.0
var _toast := ""
var _toast_t := 0.0
# speech panel
var _dlg_name := ""
var _dlg_lines: Array = []
var _dlg_i := -1
var _dlg_chars := 0.0
var _dlg_accent := Color.WHITE
var _dlg_portrait: Texture2D
var _dlg_open_t := 0.0
var _closed_t := 0.0
var _prompt_alpha := 0.0
var _prompt_spot: OverworldSpot


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")


func dialog_open() -> bool:
	return _dlg_i >= 0


## False right after a dialogue closed, so mashing the key doesn't reopen it.
func can_interact() -> bool:
	return _dlg_i < 0 and _closed_t <= 0.0


func open_dialog(name: String, lines: Array, accent: Color, portrait: Texture2D) -> void:
	if lines.is_empty():
		return
	_dlg_name = name
	_dlg_lines = lines
	_dlg_i = 0
	_dlg_chars = 0.0
	_dlg_accent = accent
	_dlg_portrait = portrait
	_dlg_open_t = 0.0


func toast(text: String) -> void:
	_toast = text
	_toast_t = 2.6


func _process(delta: float) -> void:
	_t += delta
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_toast_t = maxf(0.0, _toast_t - delta)
	_closed_t = maxf(0.0, _closed_t - delta)
	if Input.is_action_just_pressed("toggle_help"):
		show_help = not show_help
	if dialog_open():
		_dlg_open_t += delta
		var line: String = _dlg_lines[_dlg_i]
		_dlg_chars = minf(_dlg_chars + delta * TYPE_SPEED, line.length())
		if _dlg_open_t > 0.1 and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("light")):
			if _dlg_chars < line.length():
				_dlg_chars = line.length()
			else:
				_dlg_i += 1
				_dlg_chars = 0.0
				Sfx.play("ui_click", -4.0)
				if _dlg_i >= _dlg_lines.size():
					_dlg_i = -1
					_closed_t = 0.3
	# menu fades while walking, comes back when standing or hovering
	var calm := world == null or world.walker.idle_time > 0.8 or _hover >= 0
	_menu_alpha = move_toward(_menu_alpha, 1.0 if calm else 0.3, delta * (3.0 if calm else 1.5))
	var spot := world.focus if world != null and not dialog_open() else null
	if spot != null:
		_prompt_spot = spot
	_prompt_alpha = move_toward(_prompt_alpha, 1.0 if spot != null else 0.0, delta * 8.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# the collection closes itself on the same key and marks it handled
	if event.is_action_pressed("cycle_look") and select != null and world != null and not dialog_open():
		select.open_for(world.walker.visual)
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _menu_index(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _menu_index(event.position)
		if i >= 0:
			Sfx.play("ui_click")
			if i == 0 and select != null:
				select.open_for(world.walker.visual)
			elif MENU[i][3] >= 0 and menu != null:
				menu.open(MENU[i][3])
			else:
				toast(MENU[i][2])
			accept_event()


func _menu_index(p: Vector2) -> int:
	for i in _menu_rects.size():
		if (_menu_rects[i] as Rect2).has_point(p):
			return i
	return -1


# --- drawing helpers (same ink-and-paper language as the combat HUD) ---------------

func _ink_text(pos: Vector2, s: String, sz: int, col := UiSkin.INK, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, a := 1.0) -> void:
	draw_string_outline(font, pos, s, align, width, sz, 4, Color(UiSkin.PAPER, 0.95 * a))
	draw_string(font, pos, s, align, width, sz, Color(col, col.a * a))


func _paper(r: Rect2, a := 1.0, border := 2) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiSkin.PAPER, a)
	sb.border_color = Color(UiSkin.INK, a)
	sb.set_border_width_all(border)
	draw_style_box(sb, r)


func _halftone(r: Rect2, col: Color, step := 4) -> void:
	var row := 0
	var y := r.position.y + 1
	while y < r.end.y:
		var x := r.position.x + (step * 0.5 if row % 2 == 1 else 0.0)
		while x < r.end.x - 1:
			draw_rect(Rect2(x, y, 2, 2), col)
			x += step
		y += step
		row += 1


func _tag(p: Vector2, text: String, col: Color, sz := 16, a := 1.0) -> float:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + 18.0
	var h := sz + 8.0
	draw_colored_polygon(PackedVector2Array([p, p + Vector2(w, 0), p + Vector2(w - 5, h), p + Vector2(-5, h)]), Color(col, a))
	draw_string(font, p + Vector2(7, h - 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(UiSkin.PAPER, a))
	return w


func _keycap(p: Vector2, key: String, a := 1.0) -> float:
	var w := maxf(22.0, font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 12.0)
	draw_rect(Rect2(p + Vector2(0, 2), Vector2(w, 22)), Color(UiSkin.INK, a))
	draw_rect(Rect2(p, Vector2(w, 21)), Color(UiSkin.RED, a))
	draw_rect(Rect2(p, Vector2(w, 21)), Color(UiSkin.INK, a), false, 2.0)
	draw_string(font, p + Vector2(0, 16), key, HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color(UiSkin.PAPER, a))
	return w


# --- drawing -----------------------------------------------------------------------

func _draw() -> void:
	if world == null:
		return
	var W := size.x
	var H := size.y
	_draw_nameplate()
	_draw_route(W)
	_draw_prompt()
	_draw_menu(W, H)
	if show_help and not dialog_open():
		_draw_help(H)
	if dialog_open():
		_draw_dialog(W, H)
	if _toast_t > 0.0:
		var a := clampf(_toast_t * 2.0, 0.0, 1.0)
		var tw := font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 40.0
		var r := Rect2(W * 0.5 - tw * 0.5, 96, tw, 36)
		_paper(r, a)
		_ink_text(Vector2(r.position.x, r.position.y + 25), _toast, 18, UiSkin.INK, HORIZONTAL_ALIGNMENT_CENTER, tw, a)


func _draw_nameplate() -> void:
	var r := Rect2(16, 20, 284, 92)
	draw_style_box(UiSkin.box("panel"), r)
	var info := GameFlow.area_info(GameFlow.area)
	var tw := _tag(Vector2(r.position.x + 16, r.position.y - 10), "Lv. %d" % Profile.level, UiSkin.RED, 15)
	_tag(Vector2(r.position.x + 24 + tw, r.position.y - 10), "Akademie-Schüler", UiSkin.INK, 15)
	_ink_text(Vector2(r.position.x + 18, r.position.y + 50), info.title, 28)
	# small location pin in the accent colour
	var pin := Vector2(r.end.x - 34, r.position.y + 36)
	draw_circle(pin, 8, UiSkin.INK)
	draw_circle(pin, 6, info.accent)
	draw_colored_polygon(PackedVector2Array([pin + Vector2(-6, 3), pin + Vector2(6, 3), pin + Vector2(0, 15)]), UiSkin.INK)
	draw_circle(pin, 2.5, UiSkin.PAPER)
	_ink_text(Vector2(r.position.x + 18, r.position.y + 72), "Overworld · ruhige Zone", 14, Color(UiSkin.INK, 0.6))


## The route strip: the courtyard from left to right with its spots and you.
func _draw_route(W: float) -> void:
	var r := Rect2(W - 16 - 380, 18, 380, 50)
	_paper(r)
	_halftone(Rect2(r.end.x - 70, r.position.y + 3, 67, r.size.y - 6), Color(UiSkin.INK, 0.18))
	var lx := r.position.x + 18.0
	var lw := r.size.x - 36.0
	var ly := r.position.y + 30.0
	draw_rect(Rect2(lx, ly, lw, 2), UiSkin.INK)
	# terrace bump
	var t0 := lx + lw * (Overworld.GROUND[1][0] / Overworld.WIDTH)
	var t1 := lx + lw * ((Overworld.GROUND[1][0] + Overworld.GROUND[1][2]) / Overworld.WIDTH)
	draw_rect(Rect2(t0, ly - 4, t1 - t0, 2), UiSkin.INK)
	for s in world.spots:
		var x := lx + lw * (s.position.x / Overworld.WIDTH)
		match s.kind:
			OverworldSpot.Kind.DOOR:
				var locked: bool = GameFlow.area_info(s.target_area).get("locked", false)
				draw_rect(Rect2(x - 5, ly - 13, 10, 13), UiSkin.INK)
				draw_rect(Rect2(x - 3, ly - 11, 6, 11), Color("fb6b1d") if locked else Color("0eaf9b"))
			OverworldSpot.Kind.NPC:
				draw_circle(Vector2(x, ly - 5), 4, UiSkin.INK)
				draw_circle(Vector2(x, ly - 5), 2.5, s.accent)
			_:
				draw_rect(Rect2(x - 3, ly - 8, 6, 6), UiSkin.INK)
	var px := lx + lw * clampf(world.walker.global_position.x / Overworld.WIDTH, 0.0, 1.0)
	var bob := 1.0 if fmod(_t, 0.8) < 0.4 else 0.0
	draw_colored_polygon(PackedVector2Array([Vector2(px - 6, ly + 14 + bob), Vector2(px + 6, ly + 14 + bob), Vector2(px, ly + 5 + bob)]), UiSkin.RED)
	_ink_text(Vector2(r.position.x + 10, r.position.y + 16), "Wegleiste", 13, Color(UiSkin.INK, 0.65))
	# currencies, small and quiet under the strip
	var cy := r.end.y + 22.0
	var cx := r.end.x - 8.0
	for c in [[str(Profile.splitter), Color("4d9be6"), "Splitter"], ["0", Color("f04f78"), "Sternkristalle"]]:
		var label := "%s %s" % [c[0], c[2]]
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		cx -= tw
		_ink_text(Vector2(cx, cy), label, 14, Color(UiSkin.INK, 0.85))
		draw_circle(Vector2(cx - 10, cy - 5), 6, UiSkin.INK)
		draw_circle(Vector2(cx - 10, cy - 5), 4.5, c[1])
		cx -= 30.0


## Bubble over the spot in reach: "[E] Sprechen", tail pointing at it.
func _draw_prompt() -> void:
	if _prompt_spot == null or _prompt_alpha <= 0.01 or not is_instance_valid(_prompt_spot):
		return
	var a := _prompt_alpha
	var xf := world.get_viewport().get_canvas_transform()
	var anchor: Vector2 = xf * (_prompt_spot.global_position + _prompt_spot.prompt_offset)
	anchor.y -= (1.0 - a) * 8.0 + (2.0 if fmod(_t, 1.0) < 0.5 else 0.0)
	var verb := _prompt_spot.prompt()
	var name := _prompt_spot.display_name
	var tw := maxf(font.get_string_size(verb, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 38.0, font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x) + 26.0
	var r := Rect2(anchor.x - tw * 0.5, anchor.y - 50, tw, 40)
	draw_colored_polygon(PackedVector2Array([Vector2(anchor.x - 7, r.end.y - 2), Vector2(anchor.x + 7, r.end.y - 2), Vector2(anchor.x, r.end.y + 10)]), Color(UiSkin.INK, a))
	_paper(r, a)
	draw_colored_polygon(PackedVector2Array([Vector2(anchor.x - 5, r.end.y - 2), Vector2(anchor.x + 5, r.end.y - 2), Vector2(anchor.x, r.end.y + 6)]), Color(UiSkin.PAPER, a))
	draw_rect(Rect2(r.position.x + 3, r.position.y + 3, 4, r.size.y - 6), Color(_prompt_spot.accent, a))
	_ink_text(Vector2(r.position.x + 14, r.position.y + 14), name, 13, Color(UiSkin.INK, 0.65), HORIZONTAL_ALIGNMENT_LEFT, -1, a)
	var kw := _keycap(Vector2(r.position.x + 13, r.position.y + 17), "E", a)
	var locked := verb == "Versiegelt"
	_ink_text(Vector2(r.position.x + 20 + kw, r.position.y + 34), verb, 17, UiSkin.RED if locked else UiSkin.INK, HORIZONTAL_ALIGNMENT_LEFT, -1, a)


func _draw_menu(W: float, H: float) -> void:
	_menu_rects.clear()
	var bw := 104.0
	var bh := 40.0
	var x := W - 16.0 - MENU.size() * (bw + 6.0) + 6.0
	var y := H - 16.0 - bh
	for i in MENU.size():
		var r := Rect2(x + i * (bw + 6.0), y, bw, bh)
		_menu_rects.append(r)
		var sb := UiSkin.box("button")
		sb.modulate_color = Color(1, 1, 1, _menu_alpha) if i != _hover else Color(1.0, 0.75, 0.75, 1.0)
		draw_style_box(sb, r)
		_ink_text(Vector2(r.position.x, r.position.y + 26), MENU[i][0], 15, UiSkin.INK, HORIZONTAL_ALIGNMENT_CENTER, bw, _menu_alpha if i != _hover else 1.0)
		if MENU[i][1] != "":
			_keycap(Vector2(r.position.x + 2, r.position.y - 12), MENU[i][1], _menu_alpha)


func _draw_help(H: float) -> void:
	var items := [["A/D", "Laufen"], ["Shift", "Joggen"], ["Leer", "Springen"], ["E", "Sprechen / Betreten"], ["H", "Hilfe"]]
	var x := 18.0
	var y := H - 46.0
	var a := 0.9
	for it in items:
		var kw := _keycap(Vector2(x, y), it[0], a)
		_ink_text(Vector2(x + kw + 6, y + 17), it[1], 15, UiSkin.INK, HORIZONTAL_ALIGNMENT_LEFT, -1, a)
		x += kw + 14.0 + font.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x


## Speech panel: manga panel at the bottom, name tag, portrait, typewriter text.
func _draw_dialog(W: float, H: float) -> void:
	var k := clampf(_dlg_open_t / 0.16, 0.0, 1.0)
	var pw := minf(820.0, W - 40.0)
	var r := Rect2(W * 0.5 - pw * 0.5, H - 176 + (1.0 - k) * 30.0, pw, 150)
	draw_style_box(UiSkin.box("panel"), r)
	var tx := r.position.x + 28.0
	if _dlg_portrait != null:
		var pr := Rect2(r.position.x + 22, r.position.y + 22, 104, 104)
		draw_rect(pr.grow(3), UiSkin.INK)
		draw_rect(pr, Color(_dlg_accent, 0.35))
		_halftone(pr, Color(_dlg_accent, 0.55), 5)
		# head and shoulders of the drawing, pixel-doubled
		var tex := _dlg_portrait
		var src := Rect2(0, 0, tex.get_width(), minf(40.0, tex.get_height()))
		var dw := src.size.x * 2.0
		draw_texture_rect_region(tex, Rect2(pr.get_center().x - dw * 0.5, pr.position.y + 22, dw, src.size.y * 2.0).intersection(pr), Rect2(src.position, Vector2(src.size.x, minf(src.size.y, (pr.end.y - pr.position.y - 22) / 2.0))))
		tx = pr.end.x + 22.0
	_tag(Vector2(tx, r.position.y - 12), _dlg_name, _dlg_accent, 18)
	var line: String = _dlg_lines[_dlg_i]
	var shown := line.substr(0, int(_dlg_chars))
	var tw := r.end.x - tx - 30.0
	var lines := _wrap(shown, line, tw, 21)
	for li in lines.size():
		_ink_text(Vector2(tx, r.position.y + 48 + li * 28), lines[li], 21)
	if _dlg_chars >= line.length() and fmod(_t, 0.7) < 0.45:
		var p := Vector2(r.end.x - 34, r.end.y - 26)
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(14, 0), p + Vector2(7, 9)]), UiSkin.RED)
	_ink_text(Vector2(r.end.x - 140, r.end.y + 20), "%d / %d" % [_dlg_i + 1, _dlg_lines.size()], 13, Color(UiSkin.INK, 0.7), HORIZONTAL_ALIGNMENT_RIGHT, 120)


## Word wrap by the full line (so words don't jump while typing), cut to shown.
func _wrap(shown: String, full: String, width: float, sz: int) -> Array:
	var out: Array = []
	var cur := ""
	var used := 0
	for word in full.split(" "):
		var test := word if cur == "" else cur + " " + word
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > width and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = test
	out.append(cur)
	var res: Array = []
	var left := shown.length()
	for l in out:
		if left <= 0:
			break
		res.append(l.substr(0, left))
		left -= l.length() + 1
		used += 1
	return res
