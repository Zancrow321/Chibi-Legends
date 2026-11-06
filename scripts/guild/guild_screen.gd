class_name GuildScreen
extends Control
## Gildenhaus im Akademie-Hof (Endgame Schritt 6): Gilde gründen oder
## beitreten, Stufe, Wochenziele, Mitglieder mit Wochenbeitrag, Ränge und
## Banner. Alles läuft über den Server (supabase/migrations/0002_guilds.sql);
## ohne Verbindung zeigt der Bildschirm nur einen Hinweis.
## Esc schließt.

const INK := UiSkin.INK
const PAPER := UiSkin.PAPER
const RED := UiSkin.RED
## Banner-Farben 0..7 (frei: 2 + Stufe - 1).
const BANNERS := [Color("e83b3b"), Color("4d9be6"), Color("1ebc73"), Color("f9c22b"), Color("a884f3"), Color("fb6b1d"), Color("f04f78"), Color("c7dcd0")]
const GOAL_NAMES := {"boss": "Essenwächter besiegen", "tower": "Turm-Etagen (neue Rekorde)", "marks": "Raid-Marken verdienen", "guard": "Turmwachen besiegen"}
const ROLE_NAMES := {"anfuehrer": "Anführer", "offizier": "Offizier", "mitglied": "Mitglied"}

var font: Font
var is_open := false
var guild = null  # Dictionary from cl_guild_mine, null = no guild
var list: Array = []
var busy := false
## Test/preview: show `guild` / `list` without a server (tools/guild/probe.gd).
var preview := false
var _msg := ""
var _msg_t := 0.0
var _root: PanelContainer
var _body: VBoxContainer


func _ready() -> void:
	add_to_group("guild_screen")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")
	visible = false
	_root = PanelContainer.new()
	_root.add_theme_stylebox_override("panel", UiSkin.box("panel"))
	add_child(_root)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_body)


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	get_tree().paused = true
	Sfx.play("menu_open")
	refresh()


func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	Sfx.play("menu_close")


func _process(delta: float) -> void:
	_msg_t = maxf(0.0, _msg_t - delta)
	position = Vector2.ZERO
	size = get_viewport_rect().size
	var pw := minf(860.0, size.x - 40.0)
	var ph := minf(600.0, size.y - 60.0)
	_root.position = Vector2(size.x * 0.5 - pw * 0.5, size.y * 0.5 - ph * 0.5)
	_root.size = Vector2(pw, ph)
	if is_open:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_B, JOY_BUTTON_BACK]:
		close()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if not is_open:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.72), true)
	draw_rect(Rect2(_root.position + Vector2(6, 6), _root.size), Color(INK, 0.6))
	var keys := "Esc schließen"
	draw_string_outline(font, _root.position + Vector2(6, _root.size.y + 26), keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, INK)
	draw_string(font, _root.position + Vector2(6, _root.size.y + 26), keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, PAPER)
	if _msg_t > 0.0:
		var tw := font.get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 36.0
		var r := Rect2(size.x * 0.5 - tw * 0.5, _root.position.y + _root.size.y - 54, tw, 34)
		draw_rect(r.grow(2), INK)
		draw_rect(r, PAPER)
		draw_string(font, r.position + Vector2(0, 23), _msg, HORIZONTAL_ALIGNMENT_CENTER, tw, 17, INK)


func say(s: String) -> void:
	_msg = s
	_msg_t = 3.0


# --- server --------------------------------------------------------------------------

func refresh() -> void:
	if not Net.is_online():
		guild = null
		_build()
		return
	busy = true
	_build()
	var r: Dictionary = await Net.call_fn("cl_guild_mine")
	guild = r.data if r.ok else null
	GuildState.set_from(guild)
	if guild == null:
		var l: Dictionary = await Net.call_fn("cl_guild_list", {"search": ""})
		list = l.data if l.ok and l.data is Array else []
	busy = false
	if not r.ok:
		say("Server: %s" % r.error)
	_build()


func _act(fn: String, args: Dictionary, ok_text: String) -> void:
	if busy:
		return
	busy = true
	var r: Dictionary = await Net.call_fn(fn, args)
	busy = false
	if not r.ok:
		say(_clean(r.error))
		Sfx.play("ui_error")
		return
	say(ok_text)
	Sfx.play("ui_confirm")
	refresh()


## "400 Die Gilde ist voll" -> "Die Gilde ist voll"
func _clean(e: String) -> String:
	var parts := e.split(" ", false, 1)
	return parts[1] if parts.size() == 2 and parts[0].is_valid_int() else e


# --- layout ----------------------------------------------------------------------------

func _build() -> void:
	for c in _body.get_children():
		c.queue_free()
	_title("Gildenhaus")
	if not Net.is_online() and not preview:
		_text("Gilden brauchen eine Online-Verbindung. Oben rechts im Hof steht, ob du verbunden bist.", Color(INK, 0.8))
		return
	if busy and guild == null and list.is_empty():
		_text("Lade…", Color(INK, 0.7))
		return
	if guild == null:
		_build_join()
	else:
		_build_guild()


func _build_join() -> void:
	_text("Du bist in keiner Gilde. Gründe eine eigene oder tritt einer bei.", INK)
	var name_row := _row()
	_label(name_row, "Dein Name")
	var me := _edit(name_row, str(Net.node().profile.get("name", "")) if Net.node() != null and Net.node().get("profile") is Dictionary else "", 16, 180)
	_button(name_row, "Speichern", func(): _act("cl_set_name", {"new_name": me.text}, "Name gespeichert"))
	_title("Gilde gründen", 20)
	var row := _row()
	_label(row, "Name")
	var gname := _edit(row, "", 20, 220)
	_label(row, "Kürzel")
	var gtag := _edit(row, "", 4, 70)
	var col := [0]
	var swatch := _button(row, "  ", func(): pass)
	swatch.add_theme_stylebox_override("normal", _flat(BANNERS[0]))
	swatch.pressed.connect(func():
		col[0] = 1 - col[0]
		swatch.add_theme_stylebox_override("normal", _flat(BANNERS[col[0]])))
	_button(row, "Gründen", func(): _act("cl_guild_create", {"name": gname.text, "tag": gtag.text, "banner": col[0]}, "Gilde gegründet!"))
	_title("Gilden", 20)
	if list.is_empty():
		_text("Noch keine Gilden. Sei die erste!", Color(INK, 0.7))
	for g in list:
		var r := _row()
		_banner_chip(r, int(g.banner))
		_label(r, "%s [%s]   Stufe %d   %d/%d" % [g.name, g.tag, int(g.level), int(g.members), int(g.slots)], 300)
		var gid := int(g.id)
		var full := int(g.members) >= int(g.slots)
		var b := _button(r, "Voll" if full else "Beitreten", func(): _act("cl_guild_join", {"gid": gid}, "Willkommen in der Gilde!"))
		b.disabled = full


func _build_guild() -> void:
	var g: Dictionary = guild
	var head := _row()
	_banner_chip(head, int(g.banner), Vector2(34, 46))
	_label(head, "%s [%s]" % [g.name, g.tag], 0, 26)
	_text("Stufe %d   ·   %d/%d Mitglieder   ·   %d Trophäen in der Halle" % [int(g.level), (g.members as Array).size(), int(g.slots), int(g.trophies)], INK)
	_bar(float(g.xp) / maxf(1.0, float(g.xp_next)), "Gilden-XP %d / %d" % [int(g.xp), int(g.xp_next)], Color("f9c22b"))
	_text(GuildState.bonus_text(int(g.level)), Color("1a7a4a"))
	_title("Wochenziele", 20)
	for goal in g.goals:
		var t := "%s: %d / %d%s" % [GOAL_NAMES.get(goal.goal, goal.goal), int(goal.progress), int(goal.target), "  ✓" if goal.done else ""]
		_bar(float(goal.progress) / maxf(1.0, float(goal.target)), t, Color("1ebc73") if goal.done else Color("4d9be6"))
	_text("Jedes erfüllte Ziel: +400 Gilden-XP und eine Trophäe für die Halle.", Color(INK, 0.65))
	_title("Mitglieder (Beitrag diese Woche)", 20)
	var my_role := str(g.role)
	for m in g.members:
		var r := _row()
		_label(r, "%s%s" % [m.name, "  (du)" if m.me else ""], 220)
		_label(r, ROLE_NAMES.get(m.role, m.role), 110)
		_label(r, "%d Punkte" % int(m.points), 110)
		var uid := str(m.id)
		if m.me:
			continue
		if my_role == "anfuehrer":
			if m.role == "mitglied":
				_button(r, "Offizier", func(): _act("cl_guild_manage", {"action": "promote", "target": uid, "value": 0}, "Befördert"))
			elif m.role == "offizier":
				_button(r, "Zurückstufen", func(): _act("cl_guild_manage", {"action": "demote", "target": uid, "value": 0}, "Zurückgestuft"))
		if my_role == "anfuehrer" or (my_role == "offizier" and m.role == "mitglied"):
			_button(r, "Entfernen", func(): _act("cl_guild_manage", {"action": "kick", "target": uid, "value": 0}, "Entfernt"))
	var foot := _row()
	if my_role == "anfuehrer":
		var free := mini(1 + int(g.level), BANNERS.size() - 1)
		_label(foot, "Banner:")
		for i in BANNERS.size():
			var idx := i
			var b := _button(foot, "  ", func(): _act("cl_guild_manage", {"action": "banner", "value": idx}, "Banner geändert"))
			b.add_theme_stylebox_override("normal", _flat(BANNERS[i] if i <= free else Color("8a8590")))
			b.disabled = i > free
			b.tooltip_text = "" if i <= free else "Frei ab Gildenstufe %d" % (i - 1)
	_button(foot, "Gilde verlassen", func(): _act("cl_guild_leave", {}, "Du hast die Gilde verlassen"))


# --- small builders -----------------------------------------------------------------------

func _title(t: String, sz := 28) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", INK)
	_body.add_child(l)


func _text(t: String, col: Color) -> void:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", col)
	_body.add_child(l)


func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	_body.add_child(h)
	return h


func _label(parent: Node, t: String, min_w := 0, sz := 16) -> Label:
	var l := Label.new()
	l.text = t
	l.custom_minimum_size.x = min_w
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", INK)
	parent.add_child(l)
	return l


func _edit(parent: Node, t: String, max_len: int, w: float) -> LineEdit:
	var e := LineEdit.new()
	e.text = t
	e.max_length = max_len
	e.custom_minimum_size.x = w
	e.add_theme_font_override("font", font)
	e.add_theme_font_size_override("font_size", 16)
	parent.add_child(e)
	return e


func _button(parent: Node, t: String, on: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 16)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on)
	parent.add_child(b)
	return b


func _flat(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.border_color = INK
	s.set_border_width_all(2)
	return s


func _banner_chip(parent: Node, idx: int, sz := Vector2(18, 24)) -> void:
	var p := Panel.new()
	p.custom_minimum_size = sz
	p.add_theme_stylebox_override("panel", _flat(BANNERS[clampi(idx, 0, BANNERS.size() - 1)]))
	parent.add_child(p)


func _bar(frac: float, t: String, col: Color) -> void:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf(frac, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 26)
	bar.add_theme_stylebox_override("background", _flat(Color("e8e0d0")))
	var fill := _flat(col)
	bar.add_theme_stylebox_override("fill", fill)
	var l := Label.new()
	l.text = "  " + t
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", INK)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(l)
	_body.add_child(bar)
