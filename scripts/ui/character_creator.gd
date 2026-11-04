class_name CharacterCreator
extends Control
## Character creator: big animated preview, categories on the left, parts
## and curated colors on the right. Gear slots can show the equipment or
## override it with a cosmetic (switchable transmog). Rare colors are shown
## but locked until unlocked (pass, challenges, shop).
## Opens with C / Start (call_group "character_creator") and on first start.

const CATEGORIES := [
	["body", "Körper"], ["face", "Gesicht"], ["hair", "Haare"], ["top", "Oberteil"], ["pants", "Hose"],
	["shoes", "Schuhe"], ["accessory", "Accessoire"], ["headgear", "Kopf"], ["weapon", "Waffe"],
]
const PREVIEW_ANIMS := [["idle", "Stand"], ["run", "Lauf"], ["attack", "Angriff"], ["cast", "Technik"], ["hit", "Treffer"]]
const PREVIEW_SCALE := 5.0
const SWATCH := Vector2(30, 30)

var target: ChibiVisual
var look: Dictionary = {}

var _original: Dictionary = {}
var _first_time := false
var _category := "hair"
var _preview: ChibiVisual
var _preview_box: Control
var _preview_anim := "idle"
var _anim_clock := 0.0
var _options: VBoxContainer
var _title: Label
var _status: Label
var _cancel_btn: Button
var _cat_buttons: Dictionary = {}
var _anim_buttons: Dictionary = {}


func _ready() -> void:
	add_to_group("character_creator")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()


func open_for(visual: ChibiVisual, first_time := false) -> void:
	if visible or visual == null:
		return
	target = visual
	_first_time = first_time
	_original = visual.look.duplicate(true)
	look = visual.look.duplicate(true)
	_preview.equipment = visual.equipment
	_preview.look = look
	_title.text = "Erstelle deinen Charakter" if first_time else "Charakter anpassen"
	_cancel_btn.visible = not first_time
	_status.text = ""
	visible = true
	get_tree().paused = true
	_select_category(_category)
	(_cat_buttons[_category] as Button).grab_focus()


func _close(apply: bool) -> void:
	if apply:
		target.look = look
		Appearance.save_look(target.look)
	else:
		target.look = _original
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("cycle_look"):
		get_viewport().set_input_as_handled()
		_close(true)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close(_first_time)


func _process(delta: float) -> void:
	if not visible:
		return
	_anim_clock += delta
	if _preview_anim == "attack":
		_preview.set_state("attack")
		_preview.attack_phase = int(_anim_clock / 0.4) % 3
	elif _preview_anim == "hit":
		_preview.set_state("idle" if fmod(_anim_clock, 1.2) > 0.4 else "hit")
	else:
		_preview.set_state(_preview_anim)


# --- layout ---

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.08, 0.94)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	# left: categories
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(170, 0)
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	var group := ButtonGroup.new()
	for c in CATEGORIES:
		var b := Button.new()
		b.text = c[1]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(_select_category.bind(c[0]))
		left.add_child(b)
		_cat_buttons[c[0]] = b

	# middle: preview + actions
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	row.add_child(mid)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 30)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_title)

	_preview_box = Control.new()
	_preview_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_box.custom_minimum_size = Vector2(300, 300)
	_preview_box.clip_contents = true
	mid.add_child(_preview_box)
	var floor_rect := ColorRect.new()
	floor_rect.color = Color(1, 1, 1, 0.06)
	_preview_box.add_child(floor_rect)
	_preview = ChibiVisual.new()
	_preview.scale = Vector2.ONE * PREVIEW_SCALE
	_preview_box.add_child(_preview)
	_preview_box.resized.connect(func():
		_preview.position = Vector2(_preview_box.size.x * 0.5, _preview_box.size.y * 0.86)
		floor_rect.position = Vector2(_preview_box.size.x * 0.5 - 130, _preview_box.size.y * 0.86)
		floor_rect.size = Vector2(260, 8))

	var anims := HBoxContainer.new()
	anims.alignment = BoxContainer.ALIGNMENT_CENTER
	var agroup := ButtonGroup.new()
	for a in PREVIEW_ANIMS:
		var b := Button.new()
		b.text = a[1]
		b.toggle_mode = true
		b.button_group = agroup
		b.button_pressed = a[0] == _preview_anim
		b.pressed.connect(func():
			_preview_anim = a[0]
			_anim_clock = 0.0)
		anims.add_child(b)
		_anim_buttons[a[0]] = b
	var flip := Button.new()
	flip.text = "Drehen"
	flip.pressed.connect(func(): _preview.scale.x = -_preview.scale.x)
	anims.add_child(flip)
	mid.add_child(anims)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.modulate = Color("f2c14e")
	mid.add_child(_status)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	mid.add_child(actions)
	_action(actions, "Zufall", func():
		look = Appearance.random_look()
		_refresh())
	_action(actions, "Zurücksetzen", func():
		look = Appearance.default_look()
		_refresh())
	_cancel_btn = _action(actions, "Abbrechen", func(): _close(false))
	_action(actions, "Fertig", func(): _close(true))

	# right: options
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(400, 0)
	row.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_options = VBoxContainer.new()
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options.add_theme_constant_override("separation", 8)
	scroll.add_child(_options)


func _action(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(130, 44)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# --- options ---

func _select_category(cat: String) -> void:
	_category = cat
	(_cat_buttons[cat] as Button).button_pressed = true
	_status.text = ""
	_rebuild_options()


func _refresh() -> void:
	look = Appearance.normalized(look)
	_preview.look = look
	_rebuild_options()


func _rebuild_options() -> void:
	for c in _options.get_children():
		c.queue_free()
	var cat := _category
	_heading(Appearance.SLOT_NAMES.get(cat, cat))
	if cat == "body":
		_color_rows(Appearance.item(look.body))
		_note("Ein Basis-Körper für alle. Rüstungen passen dadurch immer.")
	elif cat == "face" or cat == "hair":
		var opts: Array = []
		for id in Appearance.items_for_slot(cat):
			opts.append([id, Appearance.item(id).name])
		_choice_grid(opts, look[cat], func(id: String): look[cat] = id)
		_color_rows(Appearance.item(look[cat]))
	else:
		_gear_options(cat)
	_note("Seltene Farben (abgedunkelt) schaltest du über Saison-Pass, Herausforderungen oder den Shop frei.")


func _gear_options(slot: String) -> void:
	var equipped: String = target.equipment.get(slot, "") if target else ""
	var equipped_name: String = Appearance.item(equipped).get("name", "Nichts")
	_note("Ausgerüstet: %s" % equipped_name)
	var opts: Array = [["", "Ausrüstung zeigen"]]
	for id in Appearance.items_for_slot(slot):
		opts.append([id, Appearance.item(id).name])
	if slot in Appearance.HIDEABLE:
		opts.append(["none", "Nichts"])
	var current: String = look.cosmetics.get(slot, "")
	_choice_grid(opts, current, func(id: String): look.cosmetics[slot] = id)
	var shown: String = Appearance.resolve(look, target.equipment if target else {}).get(slot, "")
	if shown != "":
		_color_rows(Appearance.item(shown))


func _heading(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	_options.add_child(l)


func _note(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = Color(1, 1, 1, 0.65)
	_options.add_child(l)


func _choice_grid(opts: Array, current: String, apply: Callable) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for o in opts:
		var b := Button.new()
		b.text = o[1]
		b.toggle_mode = true
		b.button_pressed = o[0] == current
		b.custom_minimum_size = Vector2(180, 38)
		b.pressed.connect(func():
			apply.call(o[0])
			_refresh())
		grid.add_child(b)
	_options.add_child(grid)


func _color_rows(it: Dictionary) -> void:
	if it.is_empty():
		return
	var channels: Array = it.channels
	for i in channels.size():
		var ch: Dictionary = channels[i]
		var l := Label.new()
		l.text = ch.label
		_options.add_child(l)
		var current := Appearance.channel_color(it, i, look)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 4)
		for e in Appearance.palette_group(ch.group):
			flow.add_child(_swatch(e, e.id == current, _set_channel.bind(it.id, i)))
		_options.add_child(flow)


func _set_channel(color_id: String, item_id: String, index: int) -> void:
	var it := Appearance.item(item_id)
	var ch: Dictionary = it.channels[index]
	if ch.get("appearance", false):
		look.colors[ch.key] = color_id
		return
	var cols: Array = look.item_colors.get(item_id, [])
	while cols.size() < it.channels.size():
		cols.append("")
	cols[index] = color_id
	look.item_colors[item_id] = cols


func _swatch(entry: Dictionary, selected: bool, apply: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = SWATCH
	b.focus_mode = Control.FOCUS_ALL
	var locked := Appearance.is_locked(entry.id)
	var col := Color(String(entry.color))
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.6) if locked else col
	sb.set_border_width_all(3 if selected else 1)
	sb.border_color = Color.WHITE if selected else Color(0, 0, 0, 0.6)
	sb.set_corner_radius_all(3)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.border_color = Color("f2c14e")
	hover.set_border_width_all(3)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", sb)
	if locked:
		b.text = "?"
		b.tooltip_text = "%s – %s" % [entry.name, Appearance.lock_text(entry.id)]
	else:
		b.tooltip_text = entry.name
	b.pressed.connect(func():
		if locked:
			_status.text = "%s ist noch gesperrt. %s" % [entry.name, Appearance.lock_text(entry.id)]
			return
		_status.text = entry.name
		apply.call(entry.id)
		_refresh())
	return b
