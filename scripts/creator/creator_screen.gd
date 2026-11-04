class_name CreatorScreen
extends Control
## Character Creator: eigene Figur zusammenstellen.
## Links die Teile (Frisur, Oberteil, Hose, Schuhe, Waffe, Haut) mit Pfeilen
## und Farbfeldern, in der Mitte die große Vorschau auf einer Bühne, rechts die
## Animationen zum Durchprobieren. Gespeichert wird in user://figur.json.
## Steuerung: Maus, oder Hoch/Runter = Zeile, Links/Rechts = Teil, Q/E = Farbe,
## Enter = Fertig, Esc = Abbrechen. Öffnen: call_group("creator", "open").

signal finished(look: Dictionary)

const ROWS := [["hair", "Frisur"], ["top", "Oberteil"], ["pants", "Hose"], ["shoes", "Schuhe"], ["weapon", "Waffe"], ["skin", "Haut"]]
const ANIMS := [["idle", "Stehen"], ["walk", "Gehen"], ["run", "Sprint"], ["combo", "Kombo"], ["slash", "Schwert"],
	["twohand", "Zweihand"], ["cast", "Technik"], ["knockdown", "Treffer"], ["win", "Sieg"]]
const PREVIEW_SCALE := 5.0
const INK := Color("2e222f")
const PAPER := Color("fbf6ec")
const ACCENT := Color("e83b3b")

var look: Dictionary = {}
var _body: LayeredBody
var _row := 0
var _row_nodes: Array = []
var _value_labels := {}
var _swatches := {}
var _anim_buttons := {}
var _font: Font
var _t := 0.0
var _stage: Control
var _turn := 1


func _ready() -> void:
	add_to_group("creator")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	CreatorCatalog.ensure()
	_font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")
	look = CreatorCatalog.load_look()
	_build()
	visible = false


func open() -> void:
	look = CreatorCatalog.load_look()
	_body.look = look.duplicate(true)
	_refresh()
	visible = true
	get_tree().paused = true
	_select_row(0)


func close(save: bool) -> void:
	if save:
		CreatorCatalog.save_look(look)
		finished.emit(look)
	visible = false
	get_tree().paused = false


# --- Aufbau ---------------------------------------------------------------

func _build() -> void:
	var left := VBoxContainer.new()
	left.position = Vector2(48, 116)
	left.size = Vector2(400, 520)
	left.add_theme_constant_override("separation", 8)
	add_child(left)
	for r in ROWS:
		var row := _make_row(r[0], r[1])
		left.add_child(row)
		_row_nodes.append(row)

	_stage = Control.new()
	_stage.position = Vector2(470, 90)
	_stage.size = Vector2(500, 560)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_body = LayeredBody.new()
	_body.scale = Vector2.ONE * PREVIEW_SCALE
	_body.position = Vector2(250, 470)
	_stage.add_child(_body)
	_body.play("idle")

	var right := VBoxContainer.new()
	right.position = Vector2(1000, 112)
	right.size = Vector2(230, 520)
	right.add_theme_constant_override("separation", 6)
	add_child(right)
	var head := Label.new()
	head.text = "Bewegung testen"
	_style_label(head, 20, PAPER)
	right.add_child(head)
	for a in ANIMS:
		var b := _button(a[1], 18)
		b.custom_minimum_size = Vector2(220, 40)
		b.pressed.connect(_play.bind(a[0]))
		right.add_child(b)
		_anim_buttons[a[0]] = b
		b.custom_minimum_size = Vector2(220, 36)
	var turn := _button("Umdrehen", 18)
	turn.custom_minimum_size = Vector2(220, 36)
	turn.pressed.connect(func(): _turn = -_turn; _body.facing = _turn)
	right.add_child(turn)

	var done := _button("Fertig", 24)
	done.position = Vector2(1000, 640)
	done.size = Vector2(230, 52)
	done.pressed.connect(close.bind(true))
	add_child(done)
	var rnd := _button("Zufall", 20)
	rnd.position = Vector2(48, 640)
	rnd.size = Vector2(190, 52)
	rnd.pressed.connect(_randomize)
	add_child(rnd)
	var back := _button("Abbrechen", 20)
	back.position = Vector2(258, 640)
	back.size = Vector2(190, 52)
	back.pressed.connect(close.bind(false))
	add_child(back)


func _make_row(slot: String, label: String) -> Control:
	var panel := PanelContainer.new()
	var pb := _ink_box("normal")
	pb.content_margin_left = 12
	pb.content_margin_top = 6
	pb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", pb)
	panel.custom_minimum_size = Vector2(400, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	var name_l := Label.new()
	name_l.text = label
	name_l.custom_minimum_size = Vector2(92, 0)
	_style_label(name_l, 18, INK)
	h.add_child(name_l)
	var prev := _button("<", 18)
	prev.custom_minimum_size = Vector2(34, 28)
	prev.pressed.connect(_cycle.bind(slot, -1))
	h.add_child(prev)
	var val := Label.new()
	val.custom_minimum_size = Vector2(170, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(val, 18, INK)
	h.add_child(val)
	_value_labels[slot] = val
	var nxt := _button(">", 18)
	nxt.custom_minimum_size = Vector2(34, 28)
	nxt.pressed.connect(_cycle.bind(slot, 1))
	h.add_child(nxt)
	# Farbfelder (Haut hat eigene Töne, Waffe keine)
	if slot != "weapon":
		var sw := HBoxContainer.new()
		sw.add_theme_constant_override("separation", 4)
		v.add_child(sw)
		var list: Array = CreatorCatalog.data["skins"] if slot == "skin" else CreatorCatalog.data["colors"]
		var buttons := []
		for i in list.size():
			var b := Button.new()
			b.custom_minimum_size = Vector2(30, 18)
			b.focus_mode = Control.FOCUS_NONE
			b.tooltip_text = list[i]["name"]
			b.pressed.connect(_set_color.bind(slot, i))
			sw.add_child(b)
			buttons.append(b)
		_swatches[slot] = buttons
	return panel


func _button(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", size)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, _ink_box(st))
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	return b


## Manga-Knopf: Papier mit Tuscherand und versetztem Schatten.
func _ink_box(state: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER if state != "pressed" else Color("f2d7cf")
	if state == "hover":
		sb.bg_color = Color("fff0df")
	sb.border_color = INK
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_offset = Vector2(3, 3) if state != "pressed" else Vector2(1, 1)
	sb.shadow_size = 0
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb


func _style_label(l: Label, size: int, col: Color) -> void:
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)


# --- Logik ----------------------------------------------------------------

func _cycle(slot: String, dir: int) -> void:
	if slot == "skin":
		var n: int = CreatorCatalog.data["skins"].size()
		look["skin"] = (int(look.get("skin", 1)) + dir + n) % n
	else:
		var items: Array = CreatorCatalog.slot_items(slot)
		var opts: Array = [""] + items if slot in ["hair", "weapon", "top", "pants", "shoes"] else items
		var i := opts.find(str(look.get(slot, "")))
		look[slot] = opts[(i + dir + opts.size()) % opts.size()]
		if slot == "weapon":
			_play("twohand_idle" if look[slot] != "" else "idle")
	_apply()


func _set_color(slot: String, i: int) -> void:
	if slot == "skin":
		look["skin"] = i
	else:
		var c: Dictionary = look.get("colors", {})
		c[slot] = i
		look["colors"] = c
	_apply()


func _randomize() -> void:
	for slot in ["hair", "top", "pants", "shoes"]:
		var items: Array = CreatorCatalog.slot_items(slot)
		look[slot] = items[randi() % items.size()]
		look["colors"][slot] = randi() % CreatorCatalog.data["colors"].size()
	look["skin"] = randi() % CreatorCatalog.data["skins"].size()
	_apply()


func _apply() -> void:
	_body.look = look.duplicate(true)
	_refresh()


func _play(a: String) -> void:
	_body.play(a, true)
	for k in _anim_buttons:
		(_anim_buttons[k] as Button).modulate = Color(1, 0.75, 0.75) if k == a else Color.WHITE


func _refresh() -> void:
	for r in ROWS:
		var slot: String = r[0]
		var lbl: Label = _value_labels[slot]
		if slot == "skin":
			lbl.text = CreatorCatalog.data["skins"][int(look.get("skin", 1))]["name"]
		else:
			lbl.text = CreatorCatalog.item_name(slot, str(look.get(slot, "")))
		if _swatches.has(slot):
			var cur := int(look.get("skin", 1)) if slot == "skin" else int(look.get("colors", {}).get(slot, 0))
			var list: Array = CreatorCatalog.data["skins"] if slot == "skin" else CreatorCatalog.data["colors"]
			for i in _swatches[slot].size():
				var b: Button = _swatches[slot][i]
				var sb := StyleBoxFlat.new()
				sb.bg_color = _swatch_color(list[i], slot == "skin")
				sb.border_color = ACCENT if i == cur else INK
				sb.set_border_width_all(3 if i == cur else 2)
				sb.set_corner_radius_all(2)
				for st in ["normal", "hover", "pressed"]:
					b.add_theme_stylebox_override(st, sb)


## Vorschaufarbe eines Farbfelds (ungefähr, wie der Shader eine mittlere Farbe umfärbt).
func _swatch_color(c: Dictionary, skin: bool) -> Color:
	if skin:
		var base := Color("ffc59f")
		return Color.from_hsv(fposmod(base.h + float(c["hue"]), 1.0), clampf(base.s * float(c["sat"]), 0.0, 1.0), clampf(base.v * float(c["val"]), 0.0, 1.0))
	var hex := str(c.get("color", ""))
	return Color(hex) if hex != "" else Color("9a8a7a")


func _select_row(i: int) -> void:
	_row = (i + ROWS.size()) % ROWS.size()
	for k in _row_nodes.size():
		(_row_nodes[k] as Control).modulate = Color.WHITE if k == _row else Color(0.82, 0.82, 0.86)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var slot: String = ROWS[_row][0]
	match event.physical_keycode:
		KEY_UP, KEY_W:
			_select_row(_row - 1)
		KEY_DOWN, KEY_S:
			_select_row(_row + 1)
		KEY_LEFT, KEY_A:
			_cycle(slot, -1)
		KEY_RIGHT, KEY_D:
			_cycle(slot, 1)
		KEY_Q, KEY_E:
			if _swatches.has(slot):
				var n: int = _swatches[slot].size()
				var cur := int(look.get("skin", 1)) if slot == "skin" else int(look.get("colors", {}).get(slot, 0))
				_set_color(slot, (cur + (1 if event.physical_keycode == KEY_E else -1) + n) % n)
		KEY_ENTER, KEY_KP_ENTER:
			close(true)
		KEY_ESCAPE:
			close(false)
		_:
			return
	get_viewport().set_input_as_handled()


# --- Optik ----------------------------------------------------------------

func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var r := get_viewport_rect()
	# Hintergrund: dunkles Tusche-Blau mit Manga-Speedlines hinter der Bühne
	draw_rect(r, Color("1b1726"))
	var c := Vector2(720, 380)
	for i in 72:
		var a := TAU * i / 72.0 + sin(_t * 0.4) * 0.02
		var w := 0.012 + 0.01 * sin(i * 7.3)
		var p1 := c + Vector2(cos(a), sin(a)) * 170.0
		var p2 := c + Vector2(cos(a - w), sin(a - w)) * 900.0
		var p3 := c + Vector2(cos(a + w), sin(a + w)) * 900.0
		draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color(1, 1, 1, 0.045 + 0.03 * ((i * 37) % 5) / 5.0))
	# Leuchtkreis + Bühne
	for k in 6:
		draw_circle(c + Vector2(0, 40), 230.0 - k * 30.0, Color(0.95, 0.35, 0.3, 0.035 + k * 0.012))
	var floor_y := 560.0
	draw_colored_polygon(PackedVector2Array([Vector2(520, floor_y), Vector2(920, floor_y), Vector2(980, floor_y + 60), Vector2(460, floor_y + 60)]), Color("2a2238"))
	draw_line(Vector2(520, floor_y), Vector2(920, floor_y), Color("6b5a8a"), 3.0)
	draw_set_transform(Vector2(720, floor_y + 4), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 120.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Titel
	draw_string_outline(_font, Vector2(48, 72), "CHARACTER CREATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 10, INK)
	draw_string(_font, Vector2(48, 72), "CHARACTER CREATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, PAPER)
	draw_string(_font, Vector2(52, 100), "Pfeile: Teil wählen   Q/E: Farbe   Enter: Fertig", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.55))
