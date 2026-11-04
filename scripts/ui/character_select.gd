class_name CharacterSelect
extends Control
## Character collection: list of all fixed characters (rarity, world), a big
## animated preview, details and skins, and "Spielen" to switch the played
## character. Characters you don't own show as dark silhouettes (gacha).
## Opens with C / Start (call_group "character_select"). On the very first
## start it opens in starter mode: pick one of the free starters.

const PREVIEW_ANIMS := [["idle", "Stand"], ["run", "Lauf"], ["attack", "Angriff"], ["cast", "Technik"], ["hit", "Treffer"]]
const PREVIEW_SCALE := 5.0

var target: ChibiVisual

var _char_id := ""
var _skin_id := ""
var _preview: ChibiVisual
var _preview_box: Control
var _preview_anim := "idle"
var _anim_clock := 0.0
var _list: VBoxContainer
var _info: VBoxContainer
var _status: Label
var _play_btn: Button
var _cards: Dictionary = {}
var _head: Label
var _close_btn: Button
var _pick_starter := false


func _ready() -> void:
	add_to_group("character_select")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()


func open_for(visual: ChibiVisual, pick_starter := false) -> void:
	if visible or visual == null:
		return
	target = visual
	_pick_starter = pick_starter
	_head.text = "Wähle deinen Start-Charakter" if pick_starter else "Sammlung"
	_close_btn.visible = not pick_starter
	for id in _cards:
		(_cards[id] as Button).visible = not pick_starter or id in Roster.starters()
	visible = true
	get_tree().paused = true
	_show(Roster.selected(), Roster.selected_skin())
	(_cards[_char_id] as Button).grab_focus()


func _close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _pick_starter:
		return
	if event.is_action_pressed("cycle_look") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


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

	# left: character list
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	row.add_child(left)
	_head = Label.new()
	_head.text = "Sammlung"
	_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_head.add_theme_font_size_override("font_size", 28)
	left.add_child(_head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	var group := ButtonGroup.new()
	for id in Roster.ids():
		var c := Roster.character(id)
		var r: Dictionary = Roster.RARITY.get(int(c.get("rarity", 3)), Roster.RARITY[3])
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 54)
		b.text = "%s\n%s · %s" % [c.name, r.name, Roster.world_name(c.get("world", ""))]
		b.add_theme_color_override("font_color", r.color)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		if not Roster.owns(id):
			b.modulate = Color(1, 1, 1, 0.55)
		b.pressed.connect(func(): _show(id, ""))
		_list.add_child(b)
		_cards[id] = b

	# middle: preview
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	row.add_child(mid)
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
	_play_btn = Button.new()
	_play_btn.custom_minimum_size = Vector2(200, 46)
	_play_btn.pressed.connect(_play)
	actions.add_child(_play_btn)
	_close_btn = Button.new()
	_close_btn.text = "Schließen"
	_close_btn.custom_minimum_size = Vector2(130, 46)
	_close_btn.pressed.connect(_close)
	actions.add_child(_close_btn)

	# right: details + skins
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(360, 0)
	row.add_child(right)
	var rscroll := ScrollContainer.new()
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(rscroll)
	_info = VBoxContainer.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_constant_override("separation", 8)
	rscroll.add_child(_info)


# --- content ---

func _show(char_id: String, skin_id: String) -> void:
	_char_id = char_id
	_skin_id = skin_id
	(_cards[char_id] as Button).button_pressed = true
	var owned := Roster.owns(char_id) or _pick_starter
	_preview.look = Roster.look(char_id, skin_id)
	_preview.shadow = 0.0 if owned else 1.0
	_status.text = ""
	_rebuild_info()
	var c := Roster.character(char_id)
	var playing := not _pick_starter and char_id == Roster.selected() and skin_id == Roster.selected_skin()
	_play_btn.disabled = not owned or not Roster.owns_skin(skin_id) or playing
	if _pick_starter:
		_play_btn.text = "%s nehmen" % c.get("name", "")
		_play_btn.disabled = false
	elif playing:
		_play_btn.text = "Wird gespielt"
	elif not owned:
		_play_btn.text = "Über %s" % Roster.UNLOCK_NAMES.get(c.get("unlock", "gacha"), "Gacha")
	else:
		_play_btn.text = "Spielen"


func _rebuild_info() -> void:
	for n in _info.get_children():
		n.queue_free()
	var c := Roster.character(_char_id)
	var r: Dictionary = Roster.RARITY.get(int(c.get("rarity", 3)), Roster.RARITY[3])
	_label(c.get("name", _char_id), 28)
	var rl := _label("%s · %s" % [r.name, Roster.world_name(c.get("world", ""))], 18)
	rl.modulate = r.color
	var d := _label(c.get("desc", ""), 16)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.modulate = Color(1, 1, 1, 0.8)
	if Roster.owns(_char_id) and not Roster.needs_starter():
		var p := Roster.progress(_char_id)
		var st := _label("Stufe %d/%d · Skilltree-Äste %d/%d · Kopien %d" % [p.level, Roster.MAX_LEVEL, Roster.branches(_char_id), Roster.MAX_BRANCHES, p.copies], 16)
		st.modulate = Color(0.7, 0.9, 1.0)
	if _pick_starter:
		var free := _label("Gratis zum Start. Die anderen bekommst du später über Gacha.", 16)
		free.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		free.modulate = Color("f2c14e")
	elif not Roster.owns(_char_id):
		var lock := _label("Noch nicht in deiner Sammlung.", 16)
		lock.modulate = Color("f2c14e")

	_label("Skins", 22)
	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 6)
	_info.add_child(grid)
	var skins: Array = [{"id": "", "name": "Standard", "unlock": ""}] + c.get("skins", [])
	for s in skins:
		var b := Button.new()
		var sid: String = s.id
		var have := Roster.owns_skin(sid)
		b.toggle_mode = true
		b.button_pressed = sid == _skin_id
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 40)
		var how: String = Roster.UNLOCK_NAMES.get(s.get("unlock", ""), "")
		b.text = s.name if how == "" or sid == "" else "%s  (%s)" % [s.name, how]
		if not have:
			b.modulate = Color(1, 1, 1, 0.55)
		b.pressed.connect(func():
			_show(_char_id, sid)
			if not have:
				_status.text = "%s gibt es über %s." % [s.name, how])
		grid.add_child(b)


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	_info.add_child(l)
	return l


func _play() -> void:
	if _pick_starter:
		Roster.choose_starter(_char_id)
		if target:
			target.look = Roster.look(_char_id)
		_close()
		return
	Roster.select(_char_id, _skin_id)
	if target:
		target.look = Roster.look(_char_id, _skin_id)
	_show(_char_id, _skin_id)
	_status.text = "%s ist jetzt dein Charakter." % Roster.character(_char_id).get("name", "")
