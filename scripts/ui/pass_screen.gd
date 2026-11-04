class_name PassScreen
extends Control
## Herausforderungen and Saison-Pass in one screen with two tabs.
##   Herausforderungen: daily (new at midnight) and weekly (new on Monday)
##     challenges with progress bars; finished ones are claimed for Pass-EP
##     and Sternkristalle (some also give a Creator part).
##   Saison-Pass: 30 tiers, the free track to claim, the premium track shown
##     but locked until the shop exists.
## Opens with P, at the Questbrett in the courtyard or with the Pass button.
## Keys: Q/E tab, ←→ scroll the pass, Space claim all, Esc close.
## Art: assets/pass/*.png from PixelLab (tools/pass/gen_ui.py), stand-ins
## are drawn when a file is missing.

const INK := UiSkin.INK
const PAPER := UiSkin.PAPER
const RED := UiSkin.RED
const GOLD := Color("f9c22b")
const GOOD := Color("1ebc73")
const EP_COL := Color("fb6b1d")
const TABS := ["Herausforderungen", "Saison-Pass"]
const ART := "res://assets/pass/"
const CELL_W := 96.0

var font: Font
var is_open := false
var tab := 0
var scroll := 0.0  # first visible tier (float, smooth)
var _scroll_to := 0.0
var _t := 0.0
var _hits: Array = []
var _toast := ""
var _toast_t := 0.0
var _tex_cache := {}
var _glow: Control
var _soft: GradientTexture2D
var _sparks: Array = []
var _paused_recently := 0


func _ready() -> void:
	add_to_group("season_pass")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")
	visible = false
	if not InputMap.has_action("season_pass"):
		InputMap.add_action("season_pass")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_P
		InputMap.action_add_event("season_pass", ev)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	_soft = GradientTexture2D.new()
	_soft.gradient = grad
	_soft.fill = GradientTexture2D.FILL_RADIAL
	_soft.fill_from = Vector2(0.5, 0.5)
	_soft.fill_to = Vector2(1.0, 0.5)
	_glow = Control.new()
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = m
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


func open(which := -1) -> void:
	if is_open:
		return
	SeasonPass.ensure()
	SeasonPass._refresh()
	is_open = true
	visible = true
	if which >= 0:
		tab = which
	_scroll_to = clampf(float(SeasonPass.tier()) - 3.0, 0.0, float(SeasonPass.tiers()) - 1.0)
	scroll = _scroll_to
	get_tree().paused = true
	Sfx.play("menu_open")


func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	get_tree().call_group("profile_user", "apply_profile")
	Sfx.play("menu_close")


func _tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var path := ART + name + ".png"
	if not ResourceLoader.exists(path):
		path = "res://assets/gacha/" + name + ".png"  # shared icons (splitter, dye, outfit)
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[name] = t
	return t


func _say(s: String) -> void:
	_toast = s
	_toast_t = 2.6


func _process(delta: float) -> void:
	_t += delta
	_toast_t = maxf(0.0, _toast_t - delta)
	position = Vector2.ZERO
	size = get_viewport_rect().size
	if get_tree().paused and not is_open:
		_paused_recently = 2
	elif _paused_recently > 0:
		_paused_recently -= 1
	if not is_open:
		return
	scroll = lerpf(scroll, _scroll_to, minf(1.0, delta * 12.0))
	for s in _sparks:
		s[0] += s[1] * delta
		s[1] *= pow(0.1, delta)
		s[2] -= delta
	_sparks = _sparks.filter(func(s): return s[2] > 0.0)
	queue_redraw()
	_glow.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open:
		if event.is_action_pressed("season_pass") and not get_tree().paused and _paused_recently == 0:
			open()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_key(event.physical_keycode)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			for h in _hits:
				if (h[0] as Rect2).has_point(event.position):
					(h[1] as Callable).call()
					break
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll(2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll(-2)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_B, JOY_BUTTON_BACK:
				close()
			JOY_BUTTON_LEFT_SHOULDER:
				_key(KEY_Q)
			JOY_BUTTON_RIGHT_SHOULDER:
				_key(KEY_E)
			JOY_BUTTON_DPAD_LEFT:
				_key(KEY_LEFT)
			JOY_BUTTON_DPAD_RIGHT:
				_key(KEY_RIGHT)
			JOY_BUTTON_A:
				_key(KEY_SPACE)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func _key(k: Key) -> void:
	match k:
		KEY_ESCAPE, KEY_P:
			close()
		KEY_Q, KEY_1:
			_set_tab(0)
		KEY_E, KEY_2:
			_set_tab(1)
		KEY_TAB:
			_set_tab(1 - tab)
		KEY_LEFT, KEY_A:
			_scroll(-1)
		KEY_RIGHT, KEY_D:
			_scroll(1)
		KEY_SPACE, KEY_ENTER, KEY_J:
			_claim_all()
		KEY_F9:
			SeasonPass.premium = true
			SeasonPass.add_ep(5000)
			_say("Test: Premium an, +5000 Pass-EP")


func _set_tab(i: int) -> void:
	if i != tab:
		tab = i
		Sfx.play("ui_click", -4.0)


func _scroll(d: int) -> void:
	_scroll_to = clampf(_scroll_to + d, 0.0, float(SeasonPass.tiers()) - 5.0)


func _burst(at: Vector2, col: Color, n: int) -> void:
	for i in n:
		var a := randf() * TAU
		_sparks.append([at, Vector2(cos(a), sin(a)) * randf_range(60, 340), randf_range(0.4, 0.9), col.lerp(Color.WHITE, randf() * 0.4), randf_range(1.5, 3.5)])


func _claim_challenge(c: Dictionary, at: Vector2) -> void:
	var s := SeasonPass.claim(c)
	if s != "":
		_say(s)
		Sfx.play("rare_drop", -2.0)
		_burst(at, EP_COL, 30)


func _claim_tier(t: int, prem: bool, at: Vector2) -> void:
	if prem and not SeasonPass.premium:
		_say(str(SeasonPass.data.get("premium_note", "Premium kommt mit dem Shop")))
		Sfx.play("ui_error")
		return
	if t > SeasonPass.tier():
		_say("Erst ab Pass-Stufe %d" % t)
		Sfx.play("ui_error")
		return
	var s := SeasonPass.claim_tier(t, prem)
	if s != "":
		_say(s)
		Sfx.play("pickup")
		_burst(at, GOLD, 24)


func _claim_all() -> void:
	var got := 0
	if tab == 0:
		for list in [SeasonPass.daily, SeasonPass.weekly]:
			for c in list:
				if SeasonPass.claim(c) != "":
					got += 1
	else:
		for t in range(1, SeasonPass.tier() + 1):
			for prem in [false, true]:
				if SeasonPass.can_claim(t, prem) and SeasonPass.claim_tier(t, prem) != "":
					got += 1
	if got > 0:
		_say("%d Belohnungen abgeholt" % got)
		Sfx.play("rare_drop")
		_burst(size * 0.5, GOLD, 50)
	else:
		_say("Nichts zum Abholen")
		Sfx.play("ui_error", -6.0)


# --- drawing helpers ------------------------------------------------------------------

func _ink(pos: Vector2, s: String, sz: int, col := INK, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := PAPER) -> void:
	draw_string_outline(font, pos, s, align, width, sz, 5, Color(outline, 0.95))
	draw_string(font, pos, s, align, width, sz, col)


func _slant(r: Rect2, fill: Color, edge := INK, cut := 8.0) -> void:
	var pts := PackedVector2Array([r.position + Vector2(cut, 0), Vector2(r.end.x, r.position.y), r.end - Vector2(cut, 0), Vector2(r.position.x, r.end.y)])
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(3, 3))
	draw_colored_polygon(sh, INK)
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, edge, 2.0)


func _bar(r: Rect2, frac: float, col: Color) -> void:
	draw_rect(r.grow(2), INK)
	draw_rect(r, Color(INK, 0.35))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), 2)), Color(1, 1, 1, 0.5))


## Reward icon: PixelLab art when there, else a drawn stand-in.
func _reward_icon(r: Dictionary, c: Vector2, s: float) -> void:
	var kind := str(r.get("kind", ""))
	var name: String = {"crystals": "crystal", "splitter": "icon_splitter", "gear": "icon_chest", "part": "icon_outfit", "color": "icon_dye"}.get(kind, "")
	var t: Texture2D = _tex(name) if name != "" else null
	if t == null and kind == "crystals":
		t = load("res://assets/gacha/crystal.png") if ResourceLoader.exists("res://assets/gacha/crystal.png") else null
	if t != null:
		draw_texture_rect(t, Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), false)
		return
	match kind:
		"crystals":
			var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.7, -s * 0.2), c + Vector2(0, s), c + Vector2(-s * 0.7, -s * 0.2)])
			draw_colored_polygon(pts, Color("8fd3ff"))
			pts.append(pts[0])
			draw_polyline(pts, INK, 2.0)
		"gear":
			ItemIcon.draw_icon(self, c, {"slot": "waffe", "rarity": int(r.get("rarity", 1))}, s / 10.0)
		"color":
			draw_circle(c, s * 0.6, Color("e8597a"))
			draw_arc(c, s * 0.6, 0, TAU, 24, INK, 2.0)
		_:
			draw_rect(Rect2(c - Vector2(s, s) * 0.6, Vector2(s, s) * 1.2), Color("a884f3"))
			draw_rect(Rect2(c - Vector2(s, s) * 0.6, Vector2(s, s) * 1.2), INK, false, 2.0)


func _challenge_icon(event: String, c: Vector2, s: float) -> void:
	var t := _tex("ch_" + event)
	if t != null:
		draw_texture_rect(t, Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), false)
	else:
		draw_circle(c, s * 0.8, RED)
		draw_arc(c, s * 0.8, 0, TAU, 24, INK, 2.0)
		draw_string(font, c + Vector2(-s, 5), event.substr(0, 1).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, s * 2.0, 16, PAPER)


# --- drawing ------------------------------------------------------------------------

func _draw() -> void:
	if not is_open:
		return
	_hits.clear()
	var W := size.x
	var H := size.y
	draw_rect(Rect2(0, 0, W, H), Color(INK, 0.72))
	var pw := minf(1120.0, W - 40.0)
	var ph := minf(600.0, H - 80.0)
	var R := Rect2(W * 0.5 - pw * 0.5, H * 0.5 - ph * 0.5 + 16.0, pw, ph)
	for i in 18:
		var a := TAU * i / 18.0 + _t * 0.05
		var c := R.get_center()
		draw_line(c + Vector2(cos(a), sin(a)) * (pw * 0.55), c + Vector2(cos(a), sin(a)) * (pw * 0.9), Color(PAPER, 0.05), 6.0)
	draw_style_box(UiSkin.box("panel"), R)
	# tabs
	var x := R.position.x + 22.0
	for i in TABS.size():
		var w := font.get_string_size(TABS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 44.0
		var on := i == tab
		var h := 38.0 if on else 32.0
		var tr := Rect2(x, R.position.y - h + 6, w, h)
		_slant(tr, RED if on else PAPER)
		_ink(Vector2(tr.position.x, tr.position.y + h * 0.5 + 8), TABS[i], 20, PAPER if on else INK, HORIZONTAL_ALIGNMENT_CENTER, w, INK)
		var idx := i
		_hits.append([tr, func(): _set_tab(idx)])
		x += w + 8.0
	# season header strip (always visible)
	_draw_header(R)
	if tab == 0:
		_draw_challenges(R)
	else:
		_draw_pass(R)
	var keys := "Q/E Reiter   Leertaste alles abholen   ←→ blättern   Esc schließen" if tab == 1 else "Q/E Reiter   Leertaste alles abholen   Esc schließen"
	draw_string_outline(font, Vector2(R.position.x + 6, R.end.y + 28), keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, INK)
	draw_string(font, Vector2(R.position.x + 6, R.end.y + 28), keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, PAPER)
	if _toast_t > 0.0:
		var tw := font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 36.0
		var tr2 := Rect2(R.get_center().x - tw * 0.5, R.end.y - 50, tw, 34)
		draw_rect(tr2.grow(2), INK)
		draw_rect(tr2, Color(PAPER, minf(1.0, _toast_t * 3.0)))
		_ink(Vector2(tr2.position.x, tr2.position.y + 23), _toast, 17, INK, HORIZONTAL_ALIGNMENT_CENTER, tw)


func _draw_header(R: Rect2) -> void:
	var hr := Rect2(R.position.x + 18, R.position.y + 18, R.size.x - 36, 92)
	var art := _tex("season_header")
	if art != null:
		draw_texture_rect(art, hr, false)
	else:
		for i in 8:
			draw_rect(Rect2(hr.position.x, hr.position.y + hr.size.y * i / 8.0, hr.size.x, hr.size.y / 8.0 + 1), Color("2a1a1a").lerp(Color("c2331f"), float(i) / 8.0))
	draw_rect(hr, INK, false, 3.0)
	_ink(hr.position + Vector2(20, 38), str(SeasonPass.data.get("season", {}).get("name", "Saison")), 28, PAPER, HORIZONTAL_ALIGNMENT_LEFT, -1, INK)
	var t := SeasonPass.tier()
	_ink(hr.position + Vector2(20, 72), "Pass-Stufe %d / %d" % [t, SeasonPass.tiers()], 20, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, INK)
	var br := Rect2(hr.position.x + 240, hr.position.y + 58, 360, 16)
	_bar(br, SeasonPass.tier_fraction(), EP_COL)
	var into := SeasonPass.ep % SeasonPass.ep_per_tier() if t < SeasonPass.tiers() else SeasonPass.ep_per_tier()
	draw_string(font, Vector2(br.end.x + 12, br.position.y + 14), "%d / %d EP" % [into, SeasonPass.ep_per_tier()], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, PAPER)
	var n := SeasonPass.claimable()
	if n > 0:
		var cr := Rect2(hr.end.x - 190, hr.position.y + 26, 170, 40)
		_slant(cr, RED.lightened(0.1 + 0.1 * sin(_t * 5.0)))
		_ink(Vector2(cr.position.x, cr.position.y + 27), "%d abholen" % n, 18, PAPER, HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, INK)
		_hits.append([cr, _claim_all])


func _draw_challenges(R: Rect2) -> void:
	var cols := [["Täglich", SeasonPass.daily, "neu um Mitternacht"], ["Wöchentlich", SeasonPass.weekly, "neu am Montag"]]
	var cw := (R.size.x - 36 - 20) * 0.5
	for ci in 2:
		var x: float = R.position.x + 18 + ci * (cw + 20)
		var y: float = R.position.y + 128
		_ink(Vector2(x + 4, y + 20), cols[ci][0], 22, INK)
		draw_string(font, Vector2(x + 150, y + 20), cols[ci][2], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(INK, 0.6))
		y += 34
		for c in cols[ci][1]:
			var d := SeasonPass.def(str(c.id))
			var rr := Rect2(x, y, cw, 84)
			var done := SeasonPass.done(c)
			var fill := Color("e9f7ee") if done and not c.claimed else (Color("dcd6d0") if c.claimed else PAPER)
			draw_rect(rr.grow(2), INK)
			draw_rect(rr, fill)
			_challenge_icon(str(d.get("event", "")), rr.position + Vector2(36, 42), 22.0)
			draw_string(font, rr.position + Vector2(72, 28), SeasonPass.text(c), HORIZONTAL_ALIGNMENT_LEFT, cw - 220, 17, INK)
			var target := int(d.get("target", 1))
			_bar(Rect2(rr.position + Vector2(72, 44), Vector2(cw - 230, 12)), float(c.progress) / float(target), GOOD if done else EP_COL)
			draw_string(font, rr.position + Vector2(72, 74), "%d / %d" % [int(c.progress), target], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(INK, 0.7))
			var rew := "+%d EP  +%d" % [int(d.get("ep", 0)), int(d.get("crystals", 0))]
			draw_string(font, rr.position + Vector2(cw - 150, 28), rew, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
			_reward_icon({"kind": "crystals"}, rr.position + Vector2(cw - 18, 22), 9.0)
			if d.has("part"):
				draw_string(font, rr.position + Vector2(cw - 150, 46), "+ " + CreatorCatalog.item_name(d.part[0], d.part[1]), HORIZONTAL_ALIGNMENT_LEFT, 140, 13, RED)
			var br := Rect2(rr.end.x - 140, rr.end.y - 32, 126, 26)
			if c.claimed:
				var stamp := _tex("stamp_done")
				if stamp != null:
					draw_texture_rect(stamp, Rect2(rr.end.x - 96, rr.position.y + 10, 64, 64), false)
				else:
					_ink(Vector2(br.position.x, br.position.y + 19), "ERLEDIGT", 16, GOOD, HORIZONTAL_ALIGNMENT_CENTER, br.size.x)
			elif done:
				_slant(br, RED)
				_ink(Vector2(br.position.x, br.position.y + 19), "Abholen", 16, PAPER, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, INK)
				var cc: Dictionary = c
				var at := br.get_center()
				_hits.append([br, func(): _claim_challenge(cc, at)])
			y += 96


func _draw_pass(R: Rect2) -> void:
	var top := R.position.y + 132
	var lane_h := 170.0
	var left := R.position.x + 120
	var right := R.end.x - 30
	# lane labels
	var lanes := [["Gratis", false, top], ["Premium", true, top + lane_h + 46]]
	for l in lanes:
		var lr := Rect2(R.position.x + 18, l[2], 92, lane_h)
		_slant(lr, GOLD if l[1] else PAPER, INK, 6.0)
		_ink(Vector2(lr.position.x, lr.position.y + lane_h * 0.5 + 6), l[0], 18, INK, HORIZONTAL_ALIGNMENT_CENTER, lr.size.x)
		if l[1] and not SeasonPass.premium:
			var lock := _tex("icon_lock")
			var lc := Vector2(lr.get_center().x, lr.position.y + lane_h * 0.5 + 34)
			if lock != null:
				draw_texture_rect(lock, Rect2(lc - Vector2(16, 16), Vector2(32, 32)), false)
			else:
				draw_rect(Rect2(lc - Vector2(9, 4), Vector2(18, 14)), INK)
				draw_arc(lc + Vector2(0, -4), 6.0, PI, TAU, 10, INK, 3.0)
	# tier strip between the lanes
	var strip_y := top + lane_h + 6
	var n := SeasonPass.tiers()
	var cur := SeasonPass.tier()
	var visible_w := right - left
	var first := int(floor(scroll))
	for t in range(first + 1, mini(n, first + int(visible_w / CELL_W) + 2) + 1):
		var x := left + (float(t - 1) - scroll) * CELL_W
		if x < left - 2 or x + CELL_W - 8 > right + 2:
			continue
		var reached := t <= cur
		var nr := Rect2(x, strip_y, CELL_W - 8, 32)
		draw_rect(nr.grow(2), INK)
		draw_rect(nr, EP_COL if reached else Color("8a8090"))
		_ink(Vector2(nr.position.x, nr.position.y + 23), "%d" % t, 18, PAPER, HORIZONTAL_ALIGNMENT_CENTER, nr.size.x, INK)
		for l in lanes:
			var prem: bool = l[1]
			var r := SeasonPass.reward(t, prem)
			var cell := Rect2(x, l[2], CELL_W - 8, lane_h)
			draw_rect(cell.grow(2), INK)
			var bg := Color("fff4d0") if prem else PAPER
			if not reached:
				bg = bg.darkened(0.25)
			draw_rect(cell, bg)
			if r.is_empty():
				continue
			_reward_icon(r, cell.position + Vector2(cell.size.x * 0.5, 56), 26.0)
			draw_multiline_string(font, Vector2(cell.position.x + 4, cell.position.y + 104), SeasonPass.label(r), HORIZONTAL_ALIGNMENT_CENTER, cell.size.x - 8, 13, 2, INK)
			var claimed := SeasonPass.is_claimed(t, prem)
			if claimed:
				var stamp := _tex("stamp_done")
				if stamp != null:
					draw_texture_rect(stamp, Rect2(cell.get_center() - Vector2(30, 40), Vector2(60, 60)), false, Color(1, 1, 1, 0.9))
				else:
					_ink(Vector2(cell.position.x, cell.end.y - 18), "✓", 22, GOOD, HORIZONTAL_ALIGNMENT_CENTER, cell.size.x)
			elif SeasonPass.can_claim(t, prem):
				var br := Rect2(cell.position.x + 6, cell.end.y - 34, cell.size.x - 12, 26)
				_slant(br, RED, INK, 5.0)
				_ink(Vector2(br.position.x, br.position.y + 19), "Holen", 15, PAPER, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, INK)
			if prem and not SeasonPass.premium:
				draw_rect(cell, Color(INK, 0.25))
			var tt := t
			var pp := prem
			var at := cell.get_center()
			_hits.append([cell, func(): _claim_tier(tt, pp, at)])
	# scroll arrows
	if scroll > 0.1:
		_arrow(Vector2(left - 2, strip_y + 16), -1)
	if scroll < float(n) - visible_w / CELL_W:
		_arrow(Vector2(right + 14, strip_y + 16), 1)
	if not SeasonPass.premium:
		draw_string(font, Vector2(left, R.end.y - 14), str(SeasonPass.data.get("premium_note", "")), HORIZONTAL_ALIGNMENT_LEFT, right - left, 13, Color(INK, 0.75))


func _arrow(c: Vector2, d: int) -> void:
	var pts := PackedVector2Array([c + Vector2(-8 * d, -12), c + Vector2(10 * d, 0), c + Vector2(-8 * d, 12)])
	draw_colored_polygon(pts, RED)
	pts.append(pts[0])
	draw_polyline(pts, INK, 2.0)
	_hits.append([Rect2(c - Vector2(16, 16), Vector2(32, 32)), func(): _scroll(d * 3)])


func _draw_glow() -> void:
	if not is_open:
		return
	var amt := 0.5 if FxSettings.level == 0 else 1.0
	for s in _sparks:
		var a := minf(1.0, float(s[2]) * 2.0)
		_glow.draw_texture_rect(_soft, Rect2(s[0] - Vector2(s[4], s[4]) * 5.0, Vector2(s[4], s[4]) * 10.0), false, Color(s[3], 0.5 * a * amt))
		_glow.draw_circle(s[0], s[4], Color(s[3], a))
	# claimable things pulse with a soft light
	if SeasonPass.claimable() > 0:
		var p := 0.6 + 0.4 * sin(_t * 4.0)
		var R := Rect2(size.x * 0.5 - minf(1120.0, size.x - 40.0) * 0.5, size.y * 0.5 - minf(600.0, size.y - 80.0) * 0.5 + 16.0, minf(1120.0, size.x - 40.0), 0)
		var c := Vector2(R.end.x - 123, R.position.y + 64)
		_glow.draw_texture_rect(_soft, Rect2(c - Vector2(130, 60), Vector2(260, 120)), false, Color(RED, 0.45 * p * amt))
