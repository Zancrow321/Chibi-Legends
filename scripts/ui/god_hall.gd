class_name GodHall
extends Control
## GOD-Halle (Altar im Akademie-Hof): alle 18 GOD-Teile, wer sie besitzt
## (Server, cl_god_hall) und eine Anprobe mit großer Figur und allen Effekten.
## Dazu die Enthüllung, wenn man selbst ein GOD-Teil gewinnt (reveal()).
## Tasten: Pfeile wählen, Enter/A Anprobe an/aus, Esc schließen,
## F9 (nur offline) alle Teile als Testbesitz zum Ausprobieren.

const INK := UiSkin.INK
const PAPER := UiSkin.PAPER

var font: Font
var is_open := false
var sel := 0
var _t := 0.0
var _hits: Array = []
var _hall := {}  # item -> {owner, mine}
var _loading := false
var _toast := ""
var _toast_t := 0.0
var _figure: LayeredBody
# Enthüllung
var _reveal_id := ""
var _reveal_t := 0.0


func _ready() -> void:
	add_to_group("god_hall")
	add_to_group("god_reveal")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")
	visible = false


func open() -> void:
	if is_open:
		return
	Profile.ensure()
	is_open = true
	visible = true
	get_tree().paused = true
	Sfx.play("menu_open")
	_make_figure()
	_fetch()


func close() -> void:
	is_open = false
	GodItems.try_on.clear()
	get_tree().call_group("fighter_sprite", "refresh_god")
	if _figure != null:
		_figure.queue_free()
		_figure = null
	if _reveal_id == "":
		visible = false
		get_tree().paused = false
	get_tree().call_group("profile_user", "apply_profile")
	Sfx.play("menu_close")


func _make_figure() -> void:
	if _figure != null:
		return
	_figure = LayeredBody.new()
	var look := CreatorCatalog.load_look()
	_figure.god_style = str(look.get("style", ""))
	_figure.look = look
	_figure.scale = Vector2.ONE * 4.0
	add_child(_figure)
	_figure.play("idle")
	_update_figure()


func _update_figure() -> void:
	if _figure == null:
		return
	# Waffe in der Anprobe: die Figur nimmt deren Kampfstil und Grundwaffe
	var look := CreatorCatalog.load_look()
	var style := str(look.get("style", ""))
	for id in GodItems.try_on:
		var d := GodItems.info(id)
		if d.has("style"):
			style = str(d.style)
	var st: Dictionary = CreatorCatalog.data.get("styles", {}).get(style, {})
	if style != str(look.get("style", "")):
		var w := str(st.get("weapon", ""))
		look["weapon"] = "" if w == "none" or bool(st.get("unarmed", false)) else w
		look["style"] = style
	_figure.god_style = style
	_figure.look = look
	_figure.god = GodItems.worn()


func _fetch() -> void:
	if not Net.is_online() or _loading:
		return
	_loading = true
	var r: Dictionary = await Net.call_fn("cl_god_hall")
	_loading = false
	if r.ok and r.data is Array:
		_hall.clear()
		for e in r.data:
			_hall[str(e.item)] = e


func _process(delta: float) -> void:
	_t += delta
	_toast_t = maxf(0.0, _toast_t - delta)
	position = Vector2.ZERO
	size = get_viewport_rect().size
	if _reveal_id != "":
		_reveal_t += delta
	if _figure != null:
		_figure.position = Vector2(size.x * 0.5, size.y * 0.5 + 150.0)
		_figure.visible = is_open and _reveal_id == ""
	if is_open or _reveal_id != "":
		queue_redraw()


func _input(event: InputEvent) -> void:
	if _reveal_id != "":
		if _reveal_t > 1.5 and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.pressed:
			_end_reveal()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	var n := GodItems.ORDER.size()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				close()
			KEY_LEFT, KEY_A:
				_pick(posmod(sel - 1, n))
			KEY_RIGHT, KEY_D:
				_pick(posmod(sel + 1, n))
			KEY_UP, KEY_W:
				_pick(posmod(sel - 8, n))
			KEY_DOWN, KEY_S:
				_pick(posmod(sel + 8, n))
			KEY_ENTER, KEY_SPACE, KEY_J:
				_toggle_try()
			KEY_F9:
				_test_all()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for h in _hits:
			if (h[0] as Rect2).has_point(event.position):
				(h[1] as Callable).call()
				break
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_B, JOY_BUTTON_BACK:
				close()
			JOY_BUTTON_A:
				_toggle_try()
			JOY_BUTTON_DPAD_LEFT:
				_pick(posmod(sel - 1, n))
			JOY_BUTTON_DPAD_RIGHT:
				_pick(posmod(sel + 1, n))
	get_viewport().set_input_as_handled()


func _pick(i: int) -> void:
	if i != sel:
		sel = i
		Sfx.play("ui_click", -4.0)


func _toggle_try() -> void:
	var id: String = GodItems.ORDER[sel]
	if id in GodItems.try_on:
		GodItems.try_on.erase(id)
	else:
		# eine Krone, ein Oberteil ... je Platz; Flügel dürfen beide
		var slot := str(GodItems.info(id).slot)
		for o in GodItems.try_on.duplicate():
			if str(GodItems.info(o).slot) == slot and slot != "talisman":
				GodItems.try_on.erase(o)
		GodItems.try_on.append(id)
		Sfx.play("rare_drop", -6.0)
	_update_figure()
	get_tree().call_group("fighter_sprite", "refresh_god")


func _test_all() -> void:
	if Net.is_online():
		_say("Testbesitz nur offline. Online vergibt der Server jedes Teil genau einmal.")
		Sfx.play("ui_error")
		return
	GodItems.grant_all_test()
	_say("Testbesitz: alle GOD-Teile in der Tasche (fällt beim nächsten Login weg)")
	Sfx.play("rare_drop")


func _say(s: String) -> void:
	_toast = s
	_toast_t = 3.0


func _ink(pos: Vector2, s: String, sz: int, col := PAPER, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := INK) -> void:
	draw_string_outline(font, pos, s, align, width, sz, 6, Color(outline, 0.95))
	draw_string(font, pos, s, align, width, sz, col)


func _owner_line(id: String) -> Array:
	if id in GodItems.owned():
		return ["DEIN" + (" (Test)" if not Net.is_online() else ""), Color("fff1b8")]
	if _hall.has(id):
		var e: Dictionary = _hall[id]
		if e.get("owner") != null:
			return ["Besitz: %s" % str(e.owner), Color("c7cfcc")]
		return ["noch frei", Color("9be6a0")]
	return ["offline: Besitz unbekannt" if not Net.is_online() else "…", Color("a0a0b0")]


func _draw() -> void:
	if _reveal_id != "":
		_draw_reveal()
		return
	if not is_open:
		return
	_hits.clear()
	var W := size.x
	var H := size.y
	draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.02, 0.05, 0.92))
	# Hintergrund: Licht links, Glut rechts, Strahlen aus der Mitte
	var c := Vector2(W * 0.5, H * 0.5 + 60.0)
	for k in 24:
		var a := _t * 0.12 + k * TAU / 24.0
		var col := Color("ffe9a0") if cos(a) < 0.0 else Color("ff2d4a")
		var p := PackedVector2Array([c, c + Vector2.from_angle(a - 0.05) * W, c + Vector2.from_angle(a + 0.05) * W])
		draw_colored_polygon(p, Color(col, 0.05 + 0.03 * sin(_t * 2.0 + k)))
	_ink(Vector2(0, 54), "G O D - H A L L E", 40, Loot.god_color(_t), HORIZONTAL_ALIGNMENT_CENTER, W)
	_ink(Vector2(0, 80), "Jedes Teil existiert genau einmal auf der Welt. Wer es hat, hat es allein.", 16, Color("e8e0f0"), HORIZONTAL_ALIGNMENT_CENTER, W)
	# zwei Spalten: Heilig links, Dämon rechts, Waffen darunter
	var per_row := 8
	var cell := minf(60.0, (W * 0.5 - 170.0) / per_row)
	var cols := [[], []]
	for i in GodItems.ORDER.size():
		var id: String = GodItems.ORDER[i]
		cols[0 if GodItems.info(id).series == GodItems.HOLY else 1].append(i)
	for side in 2:
		var series: String = GodItems.HOLY if side == 0 else GodItems.DEMON
		var sd: Dictionary = GodItems.SERIES[series]
		var x0 := 30.0 if side == 0 else W - 30.0 - per_row * cell
		_ink(Vector2(x0, 122), str(sd.title), 22, sd.color)
		for j in cols[side].size():
			var i: int = cols[side][j]
			var r := Rect2(x0 + (j % per_row) * cell, 136 + (j / per_row) * (cell + 4), cell - 6, cell - 6)
			_item_box(r, i)
			var idx := i
			_hits.append([r, func(): _pick(idx)])
	# Auswahl: Name, Spruch, Besitz
	var id: String = GodItems.ORDER[sel]
	var d := GodItems.info(id)
	var sd2: Dictionary = GodItems.SERIES[d.series]
	var by := H - 150.0
	_ink(Vector2(0, by), str(d.name), 30, sd2.color, HORIZONTAL_ALIGNMENT_CENTER, W)
	var kind := str(Profile.SLOT_NAMES.get(str(d.slot), ""))
	if d.has("style"):
		var st: Dictionary = CreatorCatalog.data.get("styles", {}).get(str(d.style), {})
		kind = "Waffe für %s" % str(st.get("name", d.style))
	_ink(Vector2(0, by + 26), "%s · %s" % [sd2.title, kind], 16, Color("d8d0e8"), HORIZONTAL_ALIGNMENT_CENTER, W)
	_ink(Vector2(0, by + 50), "„%s“" % str(d.line), 16, Color("f0e6ff"), HORIZONTAL_ALIGNMENT_CENTER, W)
	var ol := _owner_line(id)
	_ink(Vector2(0, by + 76), ol[0], 18, ol[1], HORIZONTAL_ALIGNMENT_CENTER, W)
	var on := id in GodItems.try_on
	var br := Rect2(W * 0.5 - 120, by + 88, 240, 38)
	draw_rect(br.grow(2), INK)
	draw_rect(br, Loot.god_color(_t).darkened(0.1) if on else Color("4a3a5a"))
	_ink(Vector2(br.position.x, br.position.y + 26), "Anprobe beenden" if on else "Anprobieren", 18, INK if on else PAPER, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, PAPER if on else INK)
	_hits.append([br, func(): _toggle_try()])
	var keys := "Pfeile wählen   Enter anprobieren   Esc schließen" + ("   F9 Testbesitz" if not Net.is_online() else "")
	_ink(Vector2(16, H - 12), keys, 14, Color("c0b8d0"))
	if _toast_t > 0.0:
		_ink(Vector2(0, 112), _toast, 17, Color(1, 1, 0.8, minf(1.0, _toast_t * 2.0)), HORIZONTAL_ALIGNMENT_CENTER, W)


func _item_box(r: Rect2, i: int) -> void:
	var id: String = GodItems.ORDER[i]
	var d := GodItems.info(id)
	var sc: Color = GodItems.SERIES[d.series].color
	var on := i == sel
	draw_rect(r.grow(3 if on else 1), Loot.god_color(_t * 2.0, i * 0.07) if on else INK)
	draw_rect(r, Color(sc, 0.18))
	var cc := r.get_center()
	for k in 8:  # Strahlen
		var a := _t * (1.2 if k % 2 == 0 else -0.7) + k * TAU / 8.0 + i
		draw_line(cc, cc + Vector2.from_angle(a) * r.size.x * 0.55, Color(sc, 0.25), r.size.x * 0.06)
	var t := GodItems.texture(id)
	var bob := sin(_t * 2.4 + i) * 2.0
	if t != null:
		draw_texture_rect(t, Rect2(r.position + Vector2(4, 4 + bob), r.size - Vector2(8, 8)), false)
	if id in GodItems.owned():
		draw_circle(r.position + Vector2(r.size.x - 8, 8), 6, Color("fff1b8"))
	elif _hall.has(id) and _hall[id].get("owner") != null:
		draw_rect(r, Color(0, 0, 0, 0.45))
	if id in GodItems.try_on:
		draw_rect(r, Color(1, 1, 1, 0.12 + 0.08 * sin(_t * 6.0)))


# Enthüllung ----------------------------------------------------------------

## Eigenes GOD-Teil gewonnen: Bildschirm gehört für ein paar Sekunden ihm.
func reveal(id: String) -> void:
	_reveal_id = id
	_reveal_t = 0.0
	visible = true
	get_tree().paused = true
	Sfx.play("rare_drop")
	get_tree().call_group("fighter_sprite", "refresh_god")


func _end_reveal() -> void:
	_reveal_id = ""
	if not is_open:
		visible = false
		get_tree().paused = false
	get_tree().call_group("profile_user", "apply_profile")


func _draw_reveal() -> void:
	var W := size.x
	var H := size.y
	var d := GodItems.info(_reveal_id)
	var sc: Color = GodItems.SERIES.get(str(d.get("series", "")), {}).get("color", Color.WHITE)
	var t := _reveal_t
	# 1) weißer Blitz, 2) Strahlen, 3) Text
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.01, 0.04, minf(0.94, t * 3.0)))
	var c := Vector2(W * 0.5, H * 0.45)
	var grow := minf(1.0, t * 1.5)
	for k in 36:
		var a := t * 0.5 + k * TAU / 36.0
		var col := Loot.god_color(t, k / 36.0) if k % 3 == 0 else sc
		var len := W * grow * (0.7 + 0.3 * sin(t * 3.0 + k))
		draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - 0.04) * len, c + Vector2.from_angle(a + 0.04) * len]), Color(col, 0.22))
	for k in 3:  # Schockwellen
		var rr := fposmod(t * 260.0 + k * 140.0, 600.0)
		draw_arc(c, rr, 0, TAU, 64, Color(sc, maxf(0.0, 0.5 - rr / 1200.0)), 6.0)
	var tx := GodItems.texture(_reveal_id)
	if tx != null:
		var s := 160.0 * minf(1.0, t * 2.0) * (1.0 + 0.04 * sin(t * 5.0))
		draw_circle(c, s * 0.75, Color(sc, 0.35))
		draw_texture_rect(tx, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
	if t < 0.25:
		draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, 1.0 - t * 4.0))
	if t > 0.5:
		var big := int(64 + 8 * sin(t * 4.0))
		_ink(Vector2(0, H * 0.45 - 120), "GOD-ITEM", big, Loot.god_color(t * 2.0), HORIZONTAL_ALIGNMENT_CENTER, W)
	if t > 0.9:
		_ink(Vector2(0, H * 0.45 + 130), str(d.get("name", "")), 34, sc, HORIZONTAL_ALIGNMENT_CENTER, W)
		_ink(Vector2(0, H * 0.45 + 162), "Weltweit einzigartig. Ab jetzt gehört es nur dir.", 18, PAPER, HORIZONTAL_ALIGNMENT_CENTER, W)
		_ink(Vector2(0, H * 0.45 + 188), "„%s“" % str(d.get("line", "")), 16, Color("e0d8f0"), HORIZONTAL_ALIGNMENT_CENTER, W)
	if t > 1.5:
		_ink(Vector2(0, H - 30), "Taste drücken", 14, Color(1, 1, 1, 0.5 + 0.5 * sin(t * 4.0)), HORIZONTAL_ALIGNMENT_CENTER, W)
