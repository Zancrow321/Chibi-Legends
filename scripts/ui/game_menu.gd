class_name GameMenu
extends Control
## The game menu (Esc, or the buttons in the courtyard): three manga panels
## behind tabs.
##   Charakter: the figure, level and EXP, all stats, the three gear slots.
##   Inventar:  the bag (30 places), item card with comparison, equip and
##              salvage into Splitter.
##   Steine:    the Edelstein pouch (fuse 3 into 1 at Hino), the worn sets
##              with their bonus steps and the worn legendary mods.
##   Optionen:  volume, effect strength, graphics, damage numbers, shake,
##              fullscreen (GameSettings, saved at once).
## Pauses the game while open. Keys: Q/E tab, arrows/WASD choose, Space/Enter
## use, X salvage, G set a gem, F Aufwerten (+1..+10), L lock, Z
## Sammel-Zerlegen, Esc close. Mouse works everywhere.
## Every item box sits in the PixelLab frame of its rarity (ItemFrame),
## animated from Episch; the item card gets the matching rim.

const TABS := ["Charakter", "Inventar", "Steine", "Optionen"]
const OPTIONS_TAB := 3
const COLS := 6
const ROWS := 5
const CELL := 66.0
const INK := UiSkin.INK
const PAPER := UiSkin.PAPER
const RED := UiSkin.RED
const GOOD := Color("1ebc73")
const BAD := Color("e83b3b")

var font: Font
var is_open := false
var tab := 0
var _sel := 0  # inventory cell
var _opt := 0  # options row
var _t := 0.0
var _paused_recently := 0
var _figure: FighterSprite
var _hits: Array = []  # [Rect2, Callable] rebuilt every draw
var _drag_opt := -1
var _toast := ""
var _toast_t := 0.0
var _confirm_salvage := ""
var _reforge_stat := ""  # affix picked for Umschmieden on the item card
var _gsel := 0  # Steine tab: gem cell (row = kind, column = tier)
var _confirm_bulk := false  # Sammel-Zerlegen asked once


func _ready() -> void:
	add_to_group("game_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")
	visible = false
	_figure = FighterSprite.new()
	_figure.scale = Vector2(3, 3)
	_figure.visible = false
	add_child(_figure)


func open(which := -1) -> void:
	if is_open:
		if which >= 0:
			tab = which
		return
	Profile.ensure()
	GameSettings.ensure()
	is_open = true
	visible = true
	if which >= 0:
		tab = which
	_sel = clampi(_sel, 0, COLS * ROWS - 1)
	_confirm_salvage = ""
	get_tree().paused = true
	Sfx.play("ui_click")


func close() -> void:
	is_open = false
	visible = false
	_figure.visible = false
	get_tree().paused = false
	get_tree().call_group("profile_user", "apply_profile")
	Sfx.play("ui_click", -4.0)


func _process(delta: float) -> void:
	_t += delta
	_toast_t = maxf(0.0, _toast_t - delta)
	position = Vector2.ZERO
	size = get_viewport_rect().size
	if get_tree().paused and not is_open:
		_paused_recently = 2
	elif _paused_recently > 0:
		_paused_recently -= 1
	if is_open:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open:
		if event.is_action_pressed("game_menu") and not get_tree().paused and _paused_recently == 0:
			open()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_key(event.physical_keycode)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			for h in _hits:
				if (h[0] as Rect2).has_point(event.position):
					(h[1] as Callable).call(event.position)
					break
		else:
			_drag_opt = -1
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drag_opt >= 0:
		_slider_to(_drag_opt, event.position.x)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_B, JOY_BUTTON_BACK:
				close()
			JOY_BUTTON_LEFT_SHOULDER:
				_tab(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				_tab(1)
			JOY_BUTTON_DPAD_LEFT:
				_key(KEY_LEFT)
			JOY_BUTTON_DPAD_RIGHT:
				_key(KEY_RIGHT)
			JOY_BUTTON_DPAD_UP:
				_key(KEY_UP)
			JOY_BUTTON_DPAD_DOWN:
				_key(KEY_DOWN)
			JOY_BUTTON_A:
				_key(KEY_ENTER)
			JOY_BUTTON_X:
				_key(KEY_X)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func _key(k: Key) -> void:
	match k:
		KEY_ESCAPE:
			close()
			return
		KEY_Q:
			_tab(-1)
			return
		KEY_E, KEY_TAB:
			_tab(1)
			return
		KEY_1, KEY_2, KEY_3, KEY_4:
			_set_tab(k - KEY_1)
			return
	if tab == 1:
		match k:
			KEY_LEFT, KEY_A:
				_move_sel(-1)
			KEY_RIGHT, KEY_D:
				_move_sel(1)
			KEY_UP, KEY_W:
				_move_sel(-COLS)
			KEY_DOWN, KEY_S:
				_move_sel(COLS)
			KEY_SPACE, KEY_ENTER, KEY_J:
				_equip_selected()
			KEY_X, KEY_DELETE:
				_salvage_selected()
			KEY_R:
				_sort()
			KEY_U:
				_reforge_selected()
			KEY_G:
				_socket_selected()
			KEY_F:
				_upgrade_selected()
			KEY_L:
				_lock_selected()
			KEY_Z:
				_salvage_bulk()
	elif tab == 2:
		match k:
			KEY_LEFT, KEY_A:
				_move_gsel(-1)
			KEY_RIGHT, KEY_D:
				_move_gsel(1)
			KEY_UP, KEY_W:
				_move_gsel(-3)
			KEY_DOWN, KEY_S:
				_move_gsel(3)
			KEY_SPACE, KEY_ENTER, KEY_F:
				_fuse_selected()
	elif tab == OPTIONS_TAB:
		match k:
			KEY_UP, KEY_W:
				_opt = (_opt - 1 + _options().size()) % _options().size()
				Sfx.play("ui_click", -8.0)
			KEY_DOWN, KEY_S:
				_opt = (_opt + 1) % _options().size()
				Sfx.play("ui_click", -8.0)
			KEY_LEFT, KEY_A:
				_change(_opt, -1)
			KEY_RIGHT, KEY_D, KEY_SPACE, KEY_ENTER:
				_change(_opt, 1)


func _tab(d: int) -> void:
	_set_tab((tab + d + TABS.size()) % TABS.size())


func _set_tab(i: int) -> void:
	if i != tab:
		tab = i
		_confirm_salvage = ""
		_confirm_bulk = false
		Sfx.play("ui_click", -4.0)


func _say(s: String) -> void:
	_toast = s
	_toast_t = 2.2


# --- inventory actions -----------------------------------------------------------

func _move_sel(d: int) -> void:
	_sel = clampi(_sel + d, 0, COLS * ROWS - 1)
	_confirm_salvage = ""
	_confirm_bulk = false
	_reforge_stat = ""
	Sfx.play("ui_click", -10.0)


func _sel_item() -> Dictionary:
	return Profile.items[_sel] if _sel < Profile.items.size() else {}


func _equip_selected() -> void:
	var it := _sel_item()
	if it.is_empty():
		return
	var was := Profile.is_equipped(it.uid)
	Profile.toggle_equip(it.uid)
	get_tree().call_group("profile_user", "apply_profile")
	_say("%s abgelegt" % it.name if was else "%s angelegt" % it.name)
	Sfx.play("hit_blade", -6.0)


## Salvaging asks once (press again), worn items can't be salvaged.
func _salvage_selected() -> void:
	var it := _sel_item()
	if it.is_empty():
		return
	if Profile.is_equipped(it.uid):
		_say("Erst ablegen, dann zerlegen")
		return
	if it.get("locked", false):
		_say("Gesperrt: erst entsperren (L)")
		Sfx.play("ui_error")
		return
	if _confirm_salvage != it.uid and int(it.rarity) >= Loot.EPIC:
		_confirm_salvage = it.uid
		_say("Nochmal drücken: %s wirklich zerlegen?" % it.name)
		return
	var gain := Profile.salvage(it.uid)
	_confirm_salvage = ""
	_sel = mini(_sel, maxi(0, Profile.items.size() - 1))
	_say("+%d Splitter" % gain)
	Sfx.play("hit_light", -4.0)


## Aufwerten: +1 step for Splitter (anywhere), up to the rarity's cap.
func _upgrade_selected() -> void:
	var it := _sel_item()
	if it.is_empty():
		return
	if not Loot.can_upgrade(it):
		_say("%s ist schon auf Höchststufe" % Loot.display_name(it))
		Sfx.play("ui_error")
		return
	var cost := Loot.upgrade_cost(it)
	if Profile.splitter < cost:
		_say("Zu wenig Splitter (%d nötig)" % cost)
		Sfx.play("ui_error")
		return
	Profile.upgrade(it.uid)
	get_tree().call_group("profile_user", "apply_profile")
	_say("Aufgewertet: %s  (−%d Splitter)" % [Loot.display_name(it), cost])
	Sfx.play("hit_heavy" if int(it.plus) >= Loot.max_plus(it) else "hit_blade", -4.0)


func _lock_selected() -> void:
	var it := _sel_item()
	if it.is_empty():
		return
	var on := Profile.toggle_lock(it.uid)
	_confirm_salvage = ""
	_say("%s gesperrt" % it.name if on else "%s entsperrt" % it.name)
	Sfx.play("ui_click", -4.0)


## Sammel-Zerlegen: everything up to Loot.BULK_MAX that is not worn or
## locked, asks once.
func _salvage_bulk() -> void:
	var n := Profile.bulk_candidates().size()
	if n == 0:
		_say("Nichts zum Zerlegen (angelegt und gesperrt bleibt)")
		Sfx.play("ui_error")
		return
	if not _confirm_bulk:
		_confirm_bulk = true
		_say("Nochmal drücken: %d Gegenstände bis %s zerlegen?" % [n, Loot.RARITIES[Loot.BULK_MAX].name])
		return
	_confirm_bulk = false
	var res := Profile.salvage_bulk()
	_sel = mini(_sel, maxi(0, Profile.items.size() - 1))
	_say("%d zerlegt: +%d Splitter" % [res[0], res[1]])
	Sfx.play("hit_heavy", -6.0)


## Umschmieden: only in the courtyard (Schmiedin Hino), rerolls the picked
## affix (default: the last one that isn't the main stat) for Splitter.
func _reforge_selected() -> void:
	var it := _sel_item()
	if it.is_empty():
		return
	if not GameFlow.is_overworld():
		_say("Umschmieden kannst du bei Schmiedin Hino im Akademie-Hof")
		Sfx.play("ui_error")
		return
	var stat := _reforge_target(it)
	if stat == "":
		_say("Dieser Gegenstand hat nur seinen Hauptwert")
		Sfx.play("ui_error")
		return
	var cost := Loot.reforge_cost(it)
	if Profile.splitter < cost:
		_say("Zu wenig Splitter (%d nötig)" % cost)
		Sfx.play("ui_error")
		return
	var new_stat := Profile.reforge(it.uid, stat)
	_reforge_stat = new_stat
	get_tree().call_group("profile_user", "apply_profile")
	_say("Umgeschmiedet: %s  (−%d Splitter)" % [Loot.stat_line(new_stat, Loot.affix(it, new_stat)), cost])
	Sfx.play("hit_blade")


func _reforge_target(it: Dictionary) -> String:
	var main: String = Loot.MAIN_STAT.get(str(it.slot), "")
	if _reforge_stat != "" and _reforge_stat != main and it.stats.has(_reforge_stat):
		return _reforge_stat
	var last := ""
	for s in it.stats:
		if s != main:
			last = s
	return last


## Sets a gem into the first free socket: the gem picked on the Steine tab
## when there is one in the pouch, else the best gem in the pouch.
func _socket_selected() -> void:
	var it := _sel_item()
	if it.is_empty():
		return
	if not it.has("sockets"):
		_say("Dieser Gegenstand hat keinen Sockel")
		Sfx.play("ui_error")
		return
	if Loot.free_socket(it) < 0:
		_say("Alle Sockel belegt (Hino kann Steine lösen)")
		Sfx.play("ui_error")
		return
	var gem := _socket_gem()
	if gem == "":
		_say("Keine Edelsteine im Beutel. Gegner lassen sie fallen.")
		Sfx.play("ui_error")
		return
	Profile.socket_gem(it.uid, gem)
	get_tree().call_group("profile_user", "apply_profile")
	_say("%s eingesetzt: %s" % [Gems.display_name(gem), Gems.line(gem)])
	Sfx.play("rare_drop", -6.0)


func _socket_gem() -> String:
	var picked := _gsel_gem()
	if Gems.count(picked) > 0:
		return picked
	var owned := Gems.owned()
	return owned[0] if not owned.is_empty() else ""


## Hino takes a gem back out of a socket (courtyard only, costs Splitter).
func _unsocket(i: int) -> void:
	var it := _sel_item()
	var sockets: Array = it.get("sockets", [])
	if i >= sockets.size() or str(sockets[i]) == "":
		_socket_selected()
		return
	if not GameFlow.is_overworld():
		_say("Steine lösen kann Schmiedin Hino im Akademie-Hof")
		Sfx.play("ui_error")
		return
	var gem := str(sockets[i])
	var cost := Gems.unsocket_cost(gem)
	if not Profile.unsocket_gem(it.uid, i):
		_say("Zu wenig Splitter (%d nötig)" % cost)
		Sfx.play("ui_error")
		return
	get_tree().call_group("profile_user", "apply_profile")
	_say("%s zurück im Beutel (−%d Splitter)" % [Gems.display_name(gem), cost])
	Sfx.play("hit_blade", -6.0)


func _gsel_gem() -> String:
	return Gems.make_id(Gems.ORDER[_gsel / 3], _gsel % 3 + 1)


func _move_gsel(d: int) -> void:
	_gsel = clampi(_gsel + d, 0, Gems.ORDER.size() * 3 - 1)
	Sfx.play("ui_click", -10.0)


func _fuse_selected() -> void:
	var gem := _gsel_gem()
	if Gems.tier_of(gem) >= Gems.MAX_TIER:
		_say("Strahlende Steine sind die höchste Stufe")
		Sfx.play("ui_error")
		return
	if not GameFlow.is_overworld():
		_say("Verschmelzen kann Schmiedin Hino im Akademie-Hof")
		Sfx.play("ui_error")
		return
	if Gems.count(gem) < Gems.FUSE_COUNT:
		_say("Du brauchst %d × %s" % [Gems.FUSE_COUNT, Gems.display_name(gem)])
		Sfx.play("ui_error")
		return
	var cost := Gems.fuse_cost(gem)
	var up := Profile.fuse_gem(gem)
	if up == "":
		_say("Zu wenig Splitter (%d nötig)" % cost)
		Sfx.play("ui_error")
		return
	_gsel += 1
	_say("Verschmolzen: %s  (−%d Splitter)" % [Gems.display_name(up), cost])
	Sfx.play("super_flash", -8.0)


func _sort() -> void:
	Profile.items.sort_custom(func(a, b):
		if int(a.rarity) != int(b.rarity):
			return int(a.rarity) > int(b.rarity)
		return Loot.score(a) > Loot.score(b))
	Profile.save()
	_sel = 0
	_say("Sortiert nach Seltenheit")


# --- options -----------------------------------------------------------------------

## [label, kind, getter-text, value 0..1 for sliders]
func _options() -> Array:
	return [
		["Gesamtlautstärke", "slider", "%d %%" % int(round(GameSettings.master * 100.0)), GameSettings.master],
		["Effektlautstärke", "slider", "%d %%" % int(round(GameSettings.sfx * 100.0)), GameSettings.sfx],
		["Effektstärke", "choice", FxSettings.level_name(), 0.0],
		["Schadenszahlen", "toggle", "an" if GameSettings.numbers else "aus", 0.0],
		["Bildschirmwackeln", "toggle", "an" if GameSettings.shake else "aus", 0.0],
		["Vollbild", "toggle", "an" if GameSettings.fullscreen else "aus", 0.0],
		["Steuerungshilfe (H)", "toggle", "an" if GameSettings.controls_help else "aus", 0.0],
	]


func _change(i: int, d: int) -> void:
	match i:
		0:
			GameSettings.master = clampf(snappedf(GameSettings.master + d * 0.1, 0.1), 0.0, 1.0)
		1:
			GameSettings.sfx = clampf(snappedf(GameSettings.sfx + d * 0.1, 0.1), 0.0, 1.0)
		2:
			FxSettings.level = (FxSettings.level + d + FxSettings.LEVELS.size()) % FxSettings.LEVELS.size()
			get_tree().call_group("bloom", "apply_level")
		3:
			GameSettings.numbers = not GameSettings.numbers
		4:
			GameSettings.shake = not GameSettings.shake
		5:
			GameSettings.fullscreen = not GameSettings.fullscreen
		6:
			GameSettings.controls_help = not GameSettings.controls_help
	GameSettings.apply()
	GameSettings.save()
	Sfx.play("ui_click", -2.0)


var _slider_rects := {}
func _slider_to(i: int, x: float) -> void:
	var r: Rect2 = _slider_rects.get(i, Rect2())
	if r.size.x <= 0.0:
		return
	var v := clampf((x - r.position.x) / r.size.x, 0.0, 1.0)
	v = snappedf(v, 0.05)
	if i == 0:
		GameSettings.master = v
	else:
		GameSettings.sfx = v
	GameSettings.apply()
	GameSettings.save()


# --- drawing helpers ---------------------------------------------------------------

func _ink(pos: Vector2, s: String, sz: int, col := INK, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(font, pos, s, align, width, sz, 4, Color(PAPER, 0.95))
	draw_string(font, pos, s, align, width, sz, col)


func _paper(r: Rect2, fill := PAPER, border := 2, border_col := INK) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border_col
	sb.set_border_width_all(border)
	draw_style_box(sb, r)


func _halftone(r: Rect2, col: Color, step := 5) -> void:
	var row := 0
	var y := r.position.y + 2
	while y < r.end.y - 1:
		var x := r.position.x + 2 + (step * 0.5 if row % 2 == 1 else 0.0)
		while x < r.end.x - 2:
			draw_rect(Rect2(x, y, 2, 2), col)
			x += step
		y += step
		row += 1


func _keycap(p: Vector2, key: String) -> float:
	var w := maxf(22.0, font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 12.0)
	draw_rect(Rect2(p + Vector2(0, 2), Vector2(w, 21)), INK)
	draw_rect(Rect2(p, Vector2(w, 20)), RED)
	draw_rect(Rect2(p, Vector2(w, 20)), INK, false, 2.0)
	draw_string(font, p + Vector2(0, 15), key, HORIZONTAL_ALIGNMENT_CENTER, w, 14, PAPER)
	return w


## Slanted manga button; returns its rect and registers the click.
func _button(r: Rect2, label: String, key: String, on: Callable, hot := false) -> void:
	var pts := PackedVector2Array([r.position + Vector2(6, 0), Vector2(r.end.x, r.position.y), r.end - Vector2(6, 0), Vector2(r.position.x, r.end.y)])
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(3, 3))
	draw_colored_polygon(shadow, INK)
	draw_colored_polygon(pts, RED if hot else PAPER)
	pts.append(pts[0])
	draw_polyline(pts, INK, 2.0)
	var x := r.position.x + 14.0
	if key != "":
		x += _keycap(Vector2(x, r.position.y + r.size.y * 0.5 - 10), key) + 8.0
	draw_string(font, Vector2(x, r.position.y + r.size.y * 0.5 + 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, PAPER if hot else INK)
	_hits.append([r, func(_p): on.call()])


func _bar(r: Rect2, frac: float, col: Color) -> void:
	draw_rect(r.grow(2), INK)
	draw_rect(r, Color(INK, 0.35))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), 2)), Color(1, 1, 1, 0.5))


func _pct(v: float) -> String:
	return ("%.1f %%" % (v * 100.0)).replace(".", ",")


# --- drawing ---------------------------------------------------------------------

func _draw() -> void:
	if not is_open:
		return
	_hits.clear()
	var W := size.x
	var H := size.y
	draw_rect(Rect2(0, 0, W, H), Color(INK, 0.6))
	_halftone(Rect2(0, 0, W, H), Color(0, 0, 0, 0.18), 6)
	var pw := minf(1000.0, W - 40.0)
	var ph := minf(590.0, H - 90.0)
	var R := Rect2(W * 0.5 - pw * 0.5, H * 0.5 - ph * 0.5 + 18.0, pw, ph)
	# speed lines behind the panel, a manga "page" feel
	for i in 18:
		var a := TAU * i / 18.0 + _t * 0.05
		var c := R.get_center()
		draw_line(c + Vector2(cos(a), sin(a)) * (pw * 0.55), c + Vector2(cos(a), sin(a)) * (pw * 0.9), Color(PAPER, 0.05), 6.0)
	draw_style_box(UiSkin.box("panel"), R)
	_draw_tabs(R)
	_figure.visible = tab == 0
	match tab:
		0:
			_draw_character(R)
		1:
			_draw_inventory(R)
		2:
			_draw_gems(R)
		_:
			_draw_options(R)
	# footer: keys
	var fx := R.position.x + 6.0
	var fy := R.end.y + 14.0
	var keys := [["Q/E", "Reiter"], ["Esc", "Schließen"]]
	if tab == 1:
		keys = [["Q/E", "Reiter"], ["Pfeile", "Wählen"], ["Leer", "Anlegen"], ["F", "Aufwerten"], ["G", "Stein"], ["L", "Sperren"], ["X", "Zerlegen"], ["Z", "Sammeln"], ["R", "Sortieren"], ["Esc", "Schließen"]]
	elif tab == 2:
		keys = [["Q/E", "Reiter"], ["Pfeile", "Wählen"], ["F", "Verschmelzen (Hof)"], ["Esc", "Schließen"]]
	elif tab == OPTIONS_TAB:
		keys = [["Q/E", "Reiter"], ["↑↓", "Wählen"], ["←→", "Ändern"], ["Esc", "Schließen"]]
	for k in keys:
		var kw := _keycap(Vector2(fx, fy), k[0])
		draw_string_outline(font, Vector2(fx + kw + 6, fy + 15), k[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, INK)
		draw_string(font, Vector2(fx + kw + 6, fy + 15), k[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, PAPER)
		fx += kw + 18.0 + font.get_string_size(k[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	if _toast_t > 0.0:
		var tw := font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 36.0
		var tr := Rect2(R.get_center().x - tw * 0.5, R.end.y - 54, tw, 34)
		_paper(tr, Color(PAPER, minf(1.0, _toast_t * 3.0)))
		_ink(Vector2(tr.position.x, tr.position.y + 23), _toast, 17, INK, HORIZONTAL_ALIGNMENT_CENTER, tw)


func _draw_tabs(R: Rect2) -> void:
	var x := R.position.x + 22.0
	for i in TABS.size():
		var label: String = TABS[i]
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 40.0
		var on := i == tab
		var h := 38.0 if on else 32.0
		var p := Vector2(x, R.position.y - h + 6)
		var pts := PackedVector2Array([p, p + Vector2(w, 0), p + Vector2(w - 8, h), p + Vector2(-8, h)])
		draw_colored_polygon(pts, RED if on else PAPER)
		pts.append(pts[0])
		draw_polyline(pts, INK, 2.5)
		draw_string(font, p + Vector2(12, h - 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, PAPER if on else INK)
		var idx := i
		_hits.append([Rect2(p.x - 8, p.y, w, h), func(_p): _set_tab(idx)])
		x += w + 6.0
	# close cross
	var cr := Rect2(R.end.x - 44, R.position.y - 30, 34, 30)
	_paper(cr, PAPER, 2)
	draw_line(cr.position + Vector2(10, 8), cr.end - Vector2(10, 8), INK, 3.0)
	draw_line(Vector2(cr.end.x - 10, cr.position.y + 8), Vector2(cr.position.x + 10, cr.end.y - 8), INK, 3.0)
	_hits.append([cr, func(_p): close()])


# Charakter ------------------------------------------------------------------------

func _draw_character(R: Rect2) -> void:
	var inner := R.grow(-26)
	# portrait panel
	var pr := Rect2(inner.position + Vector2(0, 8), Vector2(300, inner.size.y - 8))
	_paper(pr, Color("4d9be6").lerp(PAPER, 0.55), 3)
	_halftone(pr, Color("4d9be6", 0.45), 6)
	for i in 9:  # focus lines toward the figure
		var a := -PI * 0.5 + (i - 4) * 0.22
		var c := Vector2(pr.get_center().x, pr.position.y + 300)
		draw_line(c + Vector2(cos(a), sin(a)) * 150, c + Vector2(cos(a), sin(a)) * 290, Color(PAPER, 0.5), 4.0)
	draw_rect(Rect2(pr.position.x + 40, pr.position.y + 298, pr.size.x - 80, 6), Color(INK, 0.25))
	_figure.position = Vector2(pr.get_center().x - 6, pr.position.y + 300)
	_figure.scale = Vector2(3, 3)
	_tagged(Vector2(pr.position.x + 14, pr.position.y - 12), "Lv. %d" % Profile.level, RED)
	_ink(Vector2(pr.position.x + 18, pr.position.y + 344), "Akademie-Schüler", 22)
	_ink(Vector2(pr.position.x + 18, pr.position.y + 368), "EXP %d / %d" % [int(Profile.xp), int(Profile.exp_needed())], 14, Color(INK, 0.75))
	_bar(Rect2(pr.position.x + 18, pr.position.y + 378, pr.size.x - 36, 12), Profile.exp_fraction(), Color("7fd8ff"))
	_button(Rect2(pr.position.x + 18, pr.end.y - 50, pr.size.x - 36, 36), "Aussehen ändern", "O", func():
		close()
		get_tree().call_group("creator", "open"))

	# stats
	var sx := pr.end.x + 26.0
	var sr := Rect2(sx, inner.position.y + 8, 260, inner.size.y - 8)
	_paper(sr)
	_ink(Vector2(sr.position.x + 16, sr.position.y + 32), "Werte", 22, RED)
	var hp := roundf(1200.0 * (1.0 + Profile.bonus("hp")))
	var rows := [
		["Stufe", str(Profile.level)],
		["Leben", str(int(hp))],
		["Schaden", "+" + _pct(Profile.bonus("atk"))],
		["Krit-Chance", _pct(0.05 + Profile.bonus("crit"))],
		["Krit-Schaden", _pct(1.5 + Profile.bonus("critdmg"))],
		["Schadensminderung", _pct(minf(Loot.DEF_CAP, Profile.bonus("def")))],
		["Leistenladung", "+" + _pct(Profile.bonus("gauge"))],
		["Abklingzeit", "−" + _pct(1.0 - ItemSets.cooldown_factor())],
		["Lauftempo", "+" + _pct(minf(Loot.SPEED_CAP, Profile.bonus("speed")))],
		["Lebensraub", _pct(minf(Loot.LIFESTEAL_CAP, Profile.bonus("lifesteal")))],
		["Elementarschaden", "+" + _pct(Profile.bonus("elem"))],
		["Ausrüstungswert", str(Profile.gear_score())],
		["Splitter", str(Profile.splitter)],
		["Edelsteine", str(Gems.total())],
		["Gegenstände", "%d / %d" % [Profile.items.size(), Profile.BAG_SIZE]],
	]
	var y := sr.position.y + 62.0
	var step := minf(32.0, (sr.size.y - 100.0) / rows.size())
	for i in rows.size():
		if i % 2 == 0:
			draw_rect(Rect2(sr.position.x + 8, y - step * 0.62, sr.size.x - 16, step), Color(INK, 0.06))
		_ink(Vector2(sr.position.x + 18, y), rows[i][0], 15, Color(INK, 0.8))
		_ink(Vector2(sr.position.x + 18, y), rows[i][1], 16, INK, HORIZONTAL_ALIGNMENT_RIGHT, sr.size.x - 36)
		y += step
	_ink(Vector2(sr.position.x + 16, sr.end.y - 22), "Pro Stufe: +3 % Leben, +2 % Schaden", 13, Color(INK, 0.6))

	# gear slots
	var gx := sr.end.x + 26.0
	var gw := inner.end.x - gx
	_ink(Vector2(gx, inner.position.y + 32), "Ausrüstung", 22, RED)
	var gy0 := inner.position.y + 48.0
	var gap := 8.0
	var cw := (gw - gap) * 0.5
	var gh := (inner.end.y - gy0 - 3 * gap) / 4.0
	for i in Profile.SLOTS.size():
		var s: String = Profile.SLOTS[i]
		var r := Rect2(gx + (i % 2) * (cw + gap), gy0 + (i / 2) * (gh + gap), cw, gh)
		var it := Profile.equipped_item(s)
		_slot_card(r, s, it)
		_hits.append([r, func(_p): _set_tab(1)])


func _tagged(p: Vector2, text: String, col: Color, sz := 16) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + 18.0
	var h := sz + 8.0
	draw_colored_polygon(PackedVector2Array([p, p + Vector2(w, 0), p + Vector2(w - 5, h), p + Vector2(-5, h)]), col)
	draw_string(font, p + Vector2(7, h - 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, PAPER)


func _slot_card(r: Rect2, slot: String, it: Dictionary) -> void:
	var col := Loot.color(it) if not it.is_empty() else Color(INK, 0.3)
	_paper(r, PAPER, 2)
	draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(5, r.size.y - 6)), col)
	var isz := minf(48.0, r.size.y - 30.0)
	var ic := Rect2(r.position.x + 14, r.position.y + 26, isz, isz)
	_icon_box(ic, it, slot)
	_ink(Vector2(r.position.x + 14, r.position.y + 18), Profile.SLOT_NAMES[slot], 13, Color(INK, 0.6))
	var tx := ic.end.x + 8.0
	var tw := r.end.x - tx - 6.0
	if it.is_empty():
		_ink(Vector2(tx, r.position.y + 50), "leer", 16, Color(INK, 0.45))
		return
	draw_string(font, Vector2(tx, r.position.y + 42), Loot.display_name(it), HORIZONTAL_ALIGNMENT_LEFT, tw, 14, col.darkened(0.3))
	var y := r.position.y + 60.0
	for st in it.stats:
		draw_string(font, Vector2(tx, y), Loot.stat_line(st, Loot.affix(it, st)), HORIZONTAL_ALIGNMENT_LEFT, tw, 11, INK)
		y += 13.0
		if y > r.end.y - 4:
			break


func _icon_box(r: Rect2, it: Dictionary, slot := "") -> void:
	if not it.is_empty():  # rarity frame (PixelLab), animated from Episch
		ItemFrame.box(self, r, it, _t)
		_badges(r, it)
		return
	var col := Color(INK, 0.25)
	draw_rect(r.grow(2), INK)
	draw_rect(r, col.lerp(PAPER, 0.7))
	_halftone(r, Color(col, 0.5), 5)
	if slot != "":
		var ghost := {"slot": "talisman" if slot == "talisman2" else slot, "rarity": 0, "icon": 0}
		_ghost(r, ghost)


## Small marks on an item box: sockets (bottom left), set (green corner),
## legendary mod (rune, bottom right).
func _badges(r: Rect2, it: Dictionary) -> void:
	var d := clampf(r.size.x * 0.13, 6.0, 12.0)
	var sockets: Array = it.get("sockets", [])
	for i in sockets.size():
		var c := Vector2(r.position.x + d * 0.7 + i * (d + 2.0), r.end.y - d * 0.7)
		draw_circle(c, d * 0.5 + 1.5, INK)
		var g := str(sockets[i])
		draw_circle(c, d * 0.5, Gems.color(g) if g != "" else Color("4a3a4a"))
		if g != "":
			draw_circle(c + Vector2(-d, -d) * 0.15, d * 0.15, Color(1, 1, 1, 0.8))
	if it.has("set"):
		var col: Color = ItemSets.info(str(it.set)).get("color", ItemSets.COLOR)
		var p := r.position
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(d * 1.8, 0), p + Vector2(0, d * 1.8)]), col)
		draw_polyline(PackedVector2Array([p + Vector2(d * 1.8, 0), p + Vector2(0, d * 1.8)]), INK, 1.5)
	var p := int(it.get("plus", 0))
	if p > 0:  # upgrade step, top right
		var txt := "+%d" % p
		var fs := int(clampf(r.size.x * 0.24, 11.0, 22.0))
		var tp := Vector2(r.end.x - 3.0 - font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, r.position.y + fs + 1.0)
		draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, INK)
		draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f9c22b") if p >= Loot.max_plus(it) else PAPER)
	if it.get("locked", false):
		_lock(Vector2(r.get_center().x, r.position.y + d * 0.9), d * 0.75)
	if it.has("mod"):
		var mr := Rect2(r.end - Vector2(d * 2.0, d * 2.0), Vector2(d * 2.0, d * 2.0))
		var t := ItemMods.texture(str(it.mod))
		if t != null:
			draw_texture_rect(t, mr, false)
		else:
			draw_circle(mr.get_center(), d * 0.8, Color("f9c22b"))
			draw_arc(mr.get_center(), d * 0.8, 0, TAU, 12, INK, 1.5)


## Small padlock (locked items).
func _lock(c: Vector2, s: float) -> void:
	draw_arc(c + Vector2(0, -s * 0.35), s * 0.55, PI, TAU, 10, INK, s * 0.55)
	draw_arc(c + Vector2(0, -s * 0.35), s * 0.55, PI, TAU, 10, Color("c7dcd0"), s * 0.25)
	var b := Rect2(c + Vector2(-s * 0.8, -s * 0.3), Vector2(s * 1.6, s * 1.2))
	draw_rect(b.grow(1.5), INK)
	draw_rect(b, Color("f9c22b"))
	draw_circle(b.get_center(), s * 0.18, INK)


## Faint outline of an empty slot's item kind.
func _ghost(r: Rect2, ghost: Dictionary) -> void:
	ItemIcon.draw_icon(self, r.get_center(), ghost, r.size.x / 26.0)
	draw_rect(r, Color(PAPER, 0.6))


# Inventar ------------------------------------------------------------------------

func _draw_inventory(R: Rect2) -> void:
	var inner := R.grow(-26)
	var gx := inner.position.x
	var gy := inner.position.y + 30.0
	_ink(Vector2(gx, gy - 6), "Tasche", 22, RED)
	_ink(Vector2(gx + 90, gy - 6), "%d / %d" % [Profile.items.size(), Profile.BAG_SIZE], 16, Color(INK, 0.7))
	_ink(Vector2(gx, gy - 6), "%d Splitter" % Profile.splitter, 16, INK, HORIZONTAL_ALIGNMENT_RIGHT, COLS * CELL)
	gy += 12.0
	for i in COLS * ROWS:
		var r := Rect2(gx + (i % COLS) * CELL, gy + (i / COLS) * CELL, CELL - 8, CELL - 8)
		var it: Dictionary = Profile.items[i] if i < Profile.items.size() else {}
		if it.is_empty():
			draw_rect(r.grow(1), Color(INK, 0.25))
			draw_rect(r, Color(INK, 0.06))
		else:
			_icon_box(r, it)
			if Profile.is_equipped(it.uid):
				var b := Rect2(r.position.x - 4, r.position.y - 6, 22, 18)
				draw_rect(b.grow(1), INK)
				draw_rect(b, GOOD)
				draw_string(font, b.position + Vector2(0, 14), "A", HORIZONTAL_ALIGNMENT_CENTER, 22, 13, PAPER)
		if i == _sel:
			var g := 4.0 + sin(_t * 6.0)
			draw_rect(r.grow(g), RED, false, 3.0)
		var idx := i
		_hits.append([r, func(_p):
			if _sel == idx:
				_equip_selected()  # click again = equip
			else:
				_sel = idx
				_confirm_salvage = ""
				Sfx.play("ui_click", -10.0)])
	var sort_r := Rect2(gx, gy + ROWS * CELL + 4, 170, 34)
	_button(sort_r, "Sortieren", "R", _sort)
	var bulk := Profile.bulk_candidates().size()
	var bulk_label := "Alle ≤ %s (%d)" % [Loot.RARITIES[Loot.BULK_MAX].name, bulk] if not _confirm_bulk else "Sicher? Nochmal"
	_button(Rect2(sort_r.end.x + 12, sort_r.position.y, COLS * CELL - 8 - 182, 34), bulk_label, "Z", _salvage_bulk, _confirm_bulk)
	# item card
	var cx := gx + COLS * CELL + 22.0
	var card := Rect2(cx, inner.position.y + 8, inner.end.x - cx, inner.size.y - 8)
	var it := _sel_item()
	if it.is_empty():
		_paper(card)
		_halftone(card, Color(INK, 0.06), 6)
		var msg := "Noch keine Ausrüstung." if Profile.items.is_empty() else "Leerer Platz."
		_ink(Vector2(card.position.x + 24, card.position.y + 60), msg, 22)
		_ink(Vector2(card.position.x + 24, card.position.y + 92), "Besiege Gegner im Trainingswald.", 16, Color(INK, 0.75))
		_ink(Vector2(card.position.x + 24, card.position.y + 116), "Elite-Gegner lassen immer etwas fallen.", 16, Color(INK, 0.75))
		_ink(Vector2(card.position.x + 24, card.position.y + 150), "Seltenheit:", 15, Color(INK, 0.7))
		var ry := card.position.y + 176.0
		for rar in Loot.RARITIES:
			draw_rect(Rect2(card.position.x + 26, ry - 12, 14, 14), INK)
			draw_rect(Rect2(card.position.x + 28, ry - 10, 10, 10), rar.color)
			_ink(Vector2(card.position.x + 50, ry), "%s · %d Werte" % [rar.name, rar.rolls], 15)
			ry += 24.0
		return
	var col := Loot.color(it)
	var rar := Loot.rarity_info(it)
	var rint := int(it.get("rarity", 0))
	_paper(card)
	draw_rect(Rect2(card.position + Vector2(3, 3), Vector2(card.size.x - 6, 112)), col.lerp(PAPER, 0.6))
	_halftone(Rect2(card.position + Vector2(3, 3), Vector2(card.size.x - 6, 112)), Color(col, 0.55), 5)
	ItemFrame.card(self, card.grow(5), rint, _t)  # thin rarity rim around the whole card
	var ic := Rect2(card.position.x + 22, card.position.y + 22, 96, 96)
	_icon_box(ic, it)
	var tx := ic.end.x + 18.0
	_tagged(Vector2(tx, card.position.y + 22), rar.name, col.darkened(0.15), 14)
	# lock toggle in the header
	var lr := Rect2(card.end.x - 50, card.position.y + 18, 32, 32)
	draw_rect(lr.grow(2), INK)
	draw_rect(lr, Color("f9c22b").lerp(PAPER, 0.3) if it.get("locked", false) else PAPER)
	if it.get("locked", false):
		_lock(lr.get_center() + Vector2(0, 2), 9.0)
	else:
		_lock(lr.get_center() + Vector2(0, 2), 9.0)
		draw_rect(lr, Color(PAPER, 0.55))
	_hits.append([lr, func(_p): _lock_selected()])
	_ink(Vector2(tx, card.position.y + 72), Loot.display_name(it), 24, INK, HORIZONTAL_ALIGNMENT_LEFT, card.end.x - tx - 20)
	_ink(Vector2(tx, card.position.y + 94), "%s · Gegenstandsstufe %d" % [Profile.SLOT_NAMES[it.slot], int(it.ilvl)], 14, Color(INK, 0.7))
	_plus_pips(Vector2(tx, card.position.y + 104), it)
	var y := card.position.y + 152.0
	var place := Profile.place_of(it.uid)
	var worn := Profile.equipped_item(place if place != "" else Profile.place_for(it))
	var same: bool = not worn.is_empty() and worn.uid == it.uid
	var target := _reforge_target(it)
	var hof := GameFlow.is_overworld()
	var lines := 0
	for st in Loot.STATS:
		if Loot.affix(it, st) > 0.0 or (not worn.is_empty() and not same and Loot.affix(worn, st) > 0.0):
			lines += 1
	var line_h := 25.0 if lines <= 6 else 21.0  # more stats: tighter rows
	for st in Loot.STATS:
		var v := Loot.affix(it, st)
		var w := Loot.affix(worn, st) if not worn.is_empty() and not same else v
		if v == 0.0 and w == 0.0:
			continue
		if v > 0.0:
			if hof and st == target:
				draw_rect(Rect2(card.position.x + 14, y - 20, card.size.x - 28, 26), Color("fb6b1d", 0.22))
				_ink(Vector2(card.position.x + 24, y), "⚒", 16, Color("fb6b1d"), HORIZONTAL_ALIGNMENT_RIGHT, card.size.x - 120)
			var stn: String = st
			if st != Loot.MAIN_STAT.get(str(it.slot), ""):
				_hits.append([Rect2(card.position.x + 14, y - 20, card.size.x - 28, 26), func(_p): _reforge_stat = stn])
			_ink(Vector2(card.position.x + 24, y), Loot.stat_line(st, v), 18)
		else:
			_ink(Vector2(card.position.x + 24, y), "– " + str(Loot.STATS[st].name), 18, Color(INK, 0.4))
		if not same and not worn.is_empty() and absf(v - w) > 0.0005:
			var d := v - w
			_ink(Vector2(card.position.x + 24, y), ("%+.1f %%" % (d * 100.0)).replace(".", ","), 16, GOOD if d > 0 else BAD, HORIZONTAL_ALIGNMENT_RIGHT, card.size.x - 48)
		y += line_h
	y = _card_extras(card, it, y)
	if it.has("line"):
		_ink(Vector2(card.position.x + 24, y + 4), "„%s“" % it.line, 13, col.darkened(0.35))
		y += 20.0
	if same:
		_ink(Vector2(card.position.x + 24, y + 10), "Angelegt", 16, GOOD)
	elif worn.is_empty():
		_ink(Vector2(card.position.x + 24, y + 10), "Platz %s ist frei" % Profile.SLOT_NAMES[Profile.place_for(it)], 15, Color(INK, 0.7))
	else:
		_ink(Vector2(card.position.x + 24, y + 10), "Vergleich mit: %s" % worn.name, 15, Color(INK, 0.7))
	var by := card.end.y - 54.0
	var half := (card.size.x - 52.0) * 0.5
	var up_label := "Aufwerten −%d" % Loot.upgrade_cost(it) if Loot.can_upgrade(it) else "Höchststufe +%d" % Loot.max_plus(it)
	_button(Rect2(card.position.x + 20, by - 48, half, 38), up_label, "F", _upgrade_selected, Loot.can_upgrade(it) and Profile.splitter >= Loot.upgrade_cost(it))
	if hof and target != "":
		_button(Rect2(card.position.x + 32 + half, by - 48, half, 38), "Umschmieden −%d" % Loot.reforge_cost(it), "U", _reforge_selected)
	elif target != "":
		_ink(Vector2(card.position.x + 32 + half, by - 30), "Umschmieden:", 13, Color(INK, 0.55))
		_ink(Vector2(card.position.x + 32 + half, by - 14), "bei Hino im Hof", 13, Color(INK, 0.55))
	_button(Rect2(card.position.x + 20, by, 190, 38), "Ablegen" if same else "Anlegen", "Leer", _equip_selected, not same)
	var gain := int(Loot.salvage_value(it))
	var sl := "Gesperrt" if it.get("locked", false) else ("Zerlegen +%d" % gain if _confirm_salvage != it.uid else "Sicher? Nochmal")
	_button(Rect2(card.position.x + 226, by, card.size.x - 246, 38), sl, "X", _salvage_selected)


## Upgrade steps as small diamonds under the item type (filled = reached).
func _plus_pips(p: Vector2, it: Dictionary) -> void:
	var n := Loot.max_plus(it)
	var have := int(it.get("plus", 0))
	for i in n:
		var c := p + Vector2(6 + i * 13, 6)
		var pts := PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)])
		draw_colored_polygon(pts, Color("f9c22b") if i < have else Color(INK, 0.15))
		pts.append(pts[0])
		draw_polyline(pts, INK, 1.5)


## Sockets (click: set a gem / at Hino take it out), set and legendary mod
## of the item on the card. Returns the next free y.
func _card_extras(card: Rect2, it: Dictionary, y: float) -> float:
	var x := card.position.x + 24.0
	var sockets: Array = it.get("sockets", [])
	if not sockets.is_empty():
		y += 4.0
		var sx := x
		for i in sockets.size():
			var g := str(sockets[i])
			var label := Gems.line(g) if g != "" else "Sockel frei"
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 34.0
			var r := Rect2(sx, y - 18, w, 26)
			draw_rect(r, Color(Gems.color(g), 0.18) if g != "" else Color(INK, 0.07))
			draw_rect(r, Color(INK, 0.5), false, 1.5)
			draw_circle(Vector2(sx + 13, y - 5), 9.0, INK)
			if g != "":
				Gems.draw(self, Vector2(sx + 13, y - 5), g, 20.0)
			else:
				draw_circle(Vector2(sx + 13, y - 5), 7.0, Color("4a3a4a"))
			_ink(Vector2(sx + 27, y), label, 14, INK if g != "" else Color(INK, 0.55))
			var idx := i
			_hits.append([r, func(_p): _unsocket(idx)])
			sx += w + 8.0
		y += 26.0
	if it.has("set"):
		var info := ItemSets.info(str(it.set))
		var n := ItemSets.worn_count(str(it.set))
		var col: Color = info.get("color", ItemSets.COLOR)
		_tagged(Vector2(x + 4, y - 16), "Set", col.darkened(0.25), 13)
		_ink(Vector2(x + 50, y), "%s  %d/6" % [info.name, n], 16, col.darkened(0.45))
		var steps := ""
		for step in ItemSets.STEPS:
			steps += ("  ✓%d" if n >= step else "  ·%d") % step
		_ink(Vector2(x, y), steps.strip_edges(), 14, Color(INK, 0.7), HORIZONTAL_ALIGNMENT_RIGHT, card.size.x - 48)
		y += 24.0
	if it.has("mod"):
		var m := ItemMods.info(str(it.mod))
		var active := str(m.get("style", "")) == ItemMods.current_style()
		var t := ItemMods.texture(str(it.mod))
		var ir := Rect2(x - 2, y - 18, 24, 24)
		if t != null:
			draw_texture_rect(t, ir, false)
		_ink(Vector2(x + 28, y), "%s  ·  %s" % [m.get("name", ""), ItemMods.target_line(str(it.mod))], 15, Color("b07a00") if active else Color(INK, 0.5))
		y += 19.0
		var txt := str(m.get("text", ""))
		if not active:
			txt += "  (wirkt mit %s)" % Gacha.style_name(str(m.style))
		_ink(Vector2(x + 28, y), txt, 13, INK if active else Color(INK, 0.5))
		y += 20.0
	return y


# Steine ------------------------------------------------------------------------

func _draw_gems(R: Rect2) -> void:
	var inner := R.grow(-26)
	var gx := inner.position.x
	var gy := inner.position.y + 30.0
	_ink(Vector2(gx, gy - 6), "Edelsteine", 22, RED)
	_ink(Vector2(gx, gy - 6), "%d Splitter" % Profile.splitter, 16, INK, HORIZONTAL_ALIGNMENT_RIGHT, 420)
	gy += 10.0
	var cw := 134.0
	var ch := 58.0
	for i in Gems.ORDER.size() * 3:
		var kind: String = Gems.ORDER[i / 3]
		var gem := Gems.make_id(kind, i % 3 + 1)
		var r := Rect2(gx + (i % 3) * (cw + 8), gy + (i / 3) * (ch + 6), cw, ch)
		var n := Gems.count(gem)
		_paper(r, Color(Gems.color(gem), 0.16).blend(Color(PAPER, 0.84)) if n > 0 else Color("e9dfc8"), 2)
		Gems.draw(self, Vector2(r.position.x + 28, r.get_center().y), gem, 40.0)
		if n == 0:
			draw_rect(Rect2(r.position + Vector2(6, 6), Vector2(44, ch - 12)), Color("e9dfc8", 0.65))
		_ink(Vector2(r.position.x + 54, r.position.y + 24), Gems.TIER_NAMES[i % 3 + 1], 13, Color(INK, 0.65))
		_ink(Vector2(r.position.x + 54, r.position.y + 46), "× %d" % n, 20, INK if n > 0 else Color(INK, 0.4))
		if i == _gsel:
			draw_rect(r.grow(3.0 + sin(_t * 6.0)), RED, false, 3.0)
		var idx := i
		_hits.append([r, func(_p):
			if _gsel == idx:
				_fuse_selected()
			else:
				_gsel = idx
				Sfx.play("ui_click", -10.0)])
	# selected gem
	var gem := _gsel_gem()
	var by := gy + 6 * (ch + 6) + 6.0
	_ink(Vector2(gx, by + 16), "%s: %s" % [Gems.display_name(gem), Gems.line(gem)], 16, INK)
	if Gems.tier_of(gem) < Gems.MAX_TIER:
		var hot := GameFlow.is_overworld() and Gems.can_fuse(gem)
		_button(Rect2(gx, by + 28, 418, 36), "3 → 1 %s  −%d Splitter" % [Gems.TIER_NAMES[Gems.tier_of(gem) + 1], Gems.fuse_cost(gem)], "F", _fuse_selected, hot)
	else:
		_ink(Vector2(gx, by + 48), "Höchste Stufe", 14, Color(INK, 0.6))

	# right: sets and mods
	var rx := gx + 3 * (cw + 8) + 18.0
	var rr := Rect2(rx, inner.position.y + 8, inner.end.x - rx, inner.size.y - 8)
	_paper(rr)
	var x := rr.position.x + 18.0
	var y := rr.position.y + 32.0
	_ink(Vector2(x, y), "Sets", 22, RED)
	y += 30.0
	var sets := ItemSets.worn_sets()
	if sets.is_empty():
		_ink(Vector2(x, y), "Kein Set-Teil angelegt.", 15, Color(INK, 0.7))
		y += 20.0
		_ink(Vector2(x, y), "Set-Teile sind episch und grün markiert.", 13, Color(INK, 0.6))
		y += 26.0
	for st in sets:
		var col: Color = ItemSets.info(st.id).color
		draw_rect(Rect2(x - 6, y - 17, 5, 22 + 20 * st.steps.size()), col)
		_ink(Vector2(x + 4, y), "%s  %d/6" % [st.name, st.count], 17, col.darkened(0.45))
		y += 22.0
		for step in st.steps:
			_ink(Vector2(x + 12, y), "(%d) %s" % [step.n, step.text], 14, INK if step.on else Color(INK, 0.4))
			y += 20.0
		y += 8.0
	y += 10.0
	_ink(Vector2(x, y), "Legendäre Mods", 22, RED)
	y += 28.0
	var mods := ItemMods.worn()
	if mods.is_empty():
		_ink(Vector2(x, y), "Keine angelegt.", 15, Color(INK, 0.7))
		y += 20.0
		_ink(Vector2(x, y), "Jedes legendäre Teil verändert einen Zug.", 13, Color(INK, 0.6))
	var cur := ItemMods.current_style()
	for mid in mods:
		if y > rr.end.y - 30:
			break
		var m := ItemMods.info(mid)
		var on: bool = m.style == cur
		var t := ItemMods.texture(mid)
		if t != null:
			draw_texture_rect(t, Rect2(x - 2, y - 20, 28, 28), false)
		_ink(Vector2(x + 32, y), str(m.name), 16, Color("b07a00") if on else Color(INK, 0.5))
		_ink(Vector2(x + 32, y), ItemMods.target_line(mid), 12, Color(INK, 0.6) if on else Color(INK, 0.4), HORIZONTAL_ALIGNMENT_RIGHT, rr.size.x - 60)
		y += 18.0
		_ink(Vector2(x + 32, y), str(m.text) if on else "inaktiv: wirkt mit %s" % Gacha.style_name(str(m.style)), 13, INK if on else Color(INK, 0.45))
		y += 26.0


# Optionen ------------------------------------------------------------------------

func _draw_options(R: Rect2) -> void:
	var inner := R.grow(-26)
	var opts := _options()
	var y := inner.position.y + 20.0
	var rw := minf(640.0, inner.size.x)
	var x := inner.get_center().x - rw * 0.5
	_ink(Vector2(x, y + 14), "Einstellungen", 22, RED)
	_ink(Vector2(x, y + 14), "werden sofort gespeichert", 14, Color(INK, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, rw)
	y += 36.0
	_slider_rects.clear()
	for i in opts.size():
		var o: Array = opts[i]
		var r := Rect2(x, y, rw, 52)
		var on := i == _opt
		_paper(r, Color("fff4d0") if on else PAPER, 3 if on else 2, RED if on else INK)
		_ink(Vector2(r.position.x + 20, r.position.y + 33), o[0], 19)
		var cx := r.position.x + rw * 0.48
		var cw := rw * 0.52 - 20.0
		var idx := i
		match o[1]:
			"slider":
				var sr := Rect2(cx, r.position.y + 20, cw - 70, 12)
				_bar(sr, float(o[3]), RED)
				draw_circle(Vector2(sr.position.x + sr.size.x * float(o[3]), sr.get_center().y), 9.0, INK)
				draw_circle(Vector2(sr.position.x + sr.size.x * float(o[3]), sr.get_center().y), 6.0, PAPER)
				_ink(Vector2(sr.end.x + 10, r.position.y + 33), o[2], 17, INK, HORIZONTAL_ALIGNMENT_RIGHT, 60)
				_slider_rects[i] = sr
				_hits.append([Rect2(sr.position.x - 10, r.position.y, sr.size.x + 20, r.size.y), func(p):
					_opt = idx
					_drag_opt = idx
					_slider_to(idx, p.x)])
			"choice":
				_arrow(Vector2(cx + 10, r.get_center().y), -1)
				_arrow(Vector2(cx + cw - 10, r.get_center().y), 1)
				_ink(Vector2(cx, r.position.y + 33), o[2], 19, INK, HORIZONTAL_ALIGNMENT_CENTER, cw)
				_hits.append([Rect2(cx - 10, r.position.y, cw * 0.5 + 10, r.size.y), func(_p):
					_opt = idx
					_change(idx, -1)])
				_hits.append([Rect2(cx + cw * 0.5, r.position.y, cw * 0.5 + 10, r.size.y), func(_p):
					_opt = idx
					_change(idx, 1)])
			"toggle":
				var on_v: bool = o[2] == "an"
				var tr := Rect2(cx + cw - 76, r.position.y + 12, 66, 28)
				draw_rect(tr.grow(2), INK)
				draw_rect(tr, GOOD if on_v else Color(INK, 0.35))
				var knob := Rect2(tr.position.x + (36 if on_v else 2), tr.position.y + 2, 28, 24)
				draw_rect(knob, PAPER)
				draw_rect(knob, INK, false, 2.0)
				_ink(Vector2(cx, r.position.y + 33), o[2], 17, INK)
				_hits.append([Rect2(cx - 10, r.position.y, cw + 10, r.size.y), func(_p):
					_opt = idx
					_change(idx, 1)])
		_hits.append([r, func(_p): _opt = idx])
		y += 60.0


func _arrow(c: Vector2, d: int) -> void:
	var pts := PackedVector2Array([c + Vector2(-6 * d, -9), c + Vector2(8 * d, 0), c + Vector2(-6 * d, 9)])
	draw_colored_polygon(pts, RED)
	pts.append(pts[0])
	draw_polyline(pts, INK, 2.0)
