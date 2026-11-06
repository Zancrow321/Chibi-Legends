class_name GachaScreen
extends Control
## The Sternschrein (gacha for fighting styles): banner list on the left,
## the banner art in the middle, crystals / pity / rates / pull buttons on
## the right. A pull plays a falling star (its colour tells the best prize,
## gold can hide behind blue until the last moment), a burst with flash and
## shake, then the cards flip one by one; a new Legendär style gets a full
## cut-in. Rules and numbers live in Gacha / assets/gacha/banners.json.
## Opened at the Sternschrein in the courtyard or with the Gacha button.
## Keys: ↑↓ banner, 1 pull once, 0 pull ten, R rates, G daily gift,
## Space/click skip or continue, Esc close. F9 = test: all styles + crystals.
## Art: assets/gacha/*.png from PixelLab (tools/gacha/gen_ui.py); without
## them the screen draws simple stand-ins.

const INK := UiSkin.INK
const PAPER := UiSkin.PAPER
const RED := UiSkin.RED
const GOLD := Color("f9c22b")
const NIGHT := Color("0d0b1e")
const ART := "res://assets/gacha/"

var font: Font
var is_open := false
var banner_i := 0
var _t := 0.0
var _hits: Array = []
var _toast := ""
var _toast_t := 0.0
var _show_rates := false
var _tex_cache := {}
var _glow: Control  # additive layer for the light (bloom look)
var _stars: Array = []  # background stars [pos01, size, phase]
var _sparks: Array = []  # burst particles [pos, vel, life, col, size]
var _rings: Array = []  # shockwaves [age, col]
var _shake := 0.0
var _flash := 0.0
# pull sequence
var _phase := "idle"  # idle, fall, burst, reveal, cutin, done
var _pt := 0.0
var _results: Array = []
var _shown := 0  # cards revealed
var _flip_t: Array = []  # per card: time since its flip started
var _best := 0
var _cutin := {}
var _paused_recently := 0
var _soft_tex: GradientTexture2D  # radial soft light for the glow layer


func _ready() -> void:
	add_to_group("gacha")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")
	visible = false
	_glow = Control.new()
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = m
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.35, Color(1, 1, 1, 0.45))
	_soft_tex = GradientTexture2D.new()
	_soft_tex.gradient = grad
	_soft_tex.fill = GradientTexture2D.FILL_RADIAL
	_soft_tex.fill_from = Vector2(0.5, 0.5)
	_soft_tex.fill_to = Vector2(1.0, 0.5)
	_soft_tex.width = 128
	_soft_tex.height = 128
	for i in 90:
		_stars.append([Vector2(randf(), randf()), randf_range(1.0, 2.6), randf() * TAU])


func open() -> void:
	if is_open:
		return
	Gacha.ensure()
	Profile.ensure()
	is_open = true
	visible = true
	_phase = "idle"
	_show_rates = false
	get_tree().paused = true
	Sfx.play("menu_open")
	if Gacha.daily_ready():
		_say("Tagesgeschenk wartet: G drücken")


func close() -> void:
	if _phase != "idle" and _phase != "done":
		_skip()
	is_open = false
	visible = false
	_phase = "idle"
	get_tree().paused = false
	get_tree().call_group("profile_user", "apply_profile")
	Sfx.play("menu_close")


func _banner() -> Dictionary:
	var b: Array = Gacha.banners()
	return b[clampi(banner_i, 0, b.size() - 1)] if not b.is_empty() else {}


func _say(s: String) -> void:
	_toast = s
	_toast_t = 2.4


func _tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var path := ART + name + ".png"
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[name] = t
	return t


## Emblem of a style: the PixelLab gacha emblem, else its Meisterzug icon.
func _emblem(style_id: String) -> Texture2D:
	var t := _tex("emblem_" + style_id)
	if t != null:
		return t
	var key := "mz_" + style_id
	if not _tex_cache.has(key):
		var p := "res://assets/combat/icons/%s/meisterzug.png" % style_id
		_tex_cache[key] = load(p) if ResourceLoader.exists(p) else null
	return _tex_cache[key]


func _col(style_id: String, keys: Array, fallback: Color) -> Color:
	var c: Dictionary = Gacha.style_colors(style_id)
	for k in keys:
		if c.has(k):
			return Color(str(c[k]))
	return fallback


# --- input -------------------------------------------------------------------------

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
	_step(delta)
	queue_redraw()
	_glow.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var busy := _phase != "idle"
	if event is InputEventKey and event.pressed and not event.echo:
		if busy:
			if event.physical_keycode == KEY_ESCAPE:
				close()
			else:
				_advance()
		else:
			_key(event.physical_keycode)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if busy:
			_advance()
		else:
			for h in _hits:
				if (h[0] as Rect2).has_point(event.position):
					(h[1] as Callable).call()
					break
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if busy:
			_advance()
		else:
			match event.button_index:
				JOY_BUTTON_B, JOY_BUTTON_BACK:
					close()
				JOY_BUTTON_DPAD_UP:
					_key(KEY_UP)
				JOY_BUTTON_DPAD_DOWN:
					_key(KEY_DOWN)
				JOY_BUTTON_A:
					_key(KEY_1)
				JOY_BUTTON_Y:
					_key(KEY_0)
				JOY_BUTTON_X:
					_key(KEY_R)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func _key(k: Key) -> void:
	match k:
		KEY_ESCAPE:
			if _show_rates:
				_show_rates = false
			else:
				close()
		KEY_UP, KEY_W:
			_pick(banner_i - 1)
		KEY_DOWN, KEY_S:
			_pick(banner_i + 1)
		KEY_1, KEY_KP_1, KEY_SPACE, KEY_ENTER, KEY_J:
			_pull(1)
		KEY_0, KEY_KP_0, KEY_K:
			_pull(10)
		KEY_R:
			_show_rates = not _show_rates
			Sfx.play("ui_click")
		KEY_G:
			_daily()
		KEY_F9:
			Gacha.unlock_all()
			_say("Test: alle Kampfstile + 10000 Sternkristalle")


func _pick(i: int) -> void:
	var n := Gacha.banners().size()
	if n == 0:
		return
	banner_i = (i + n) % n
	Sfx.play("ui_hover")


func _daily() -> void:
	var n := Gacha.claim_daily()
	if n > 0:
		_say("Tagesgeschenk: +%d Sternkristalle" % n)
		Sfx.play("pickup")
		_burst(Vector2(size.x - 170, 120), Color("8fd3ff"), 26)
	else:
		_say("Das Tagesgeschenk gibt es morgen wieder")
		Sfx.play("ui_error")


func _pull(n: int) -> void:
	if not Gacha.can_pull(n):
		_say("Zu wenig Sternkristalle (%d nötig)" % Gacha.cost(n))
		Sfx.play("ui_error")
		return
	_results = Gacha.pull(_banner(), n)
	_best = 0
	for r in _results:
		_best = maxi(_best, int(r.rarity))
	_flip_t = []
	for r in _results:
		_flip_t.append(-1.0)
	_shown = 0
	_phase = "fall"
	_pt = 0.0
	_show_rates = false
	Sfx.play("ui_confirm")


## Space / click during a pull: next step, or skip to the end.
func _advance() -> void:
	match _phase:
		"fall", "burst":
			_skip()
		"reveal":
			_skip()
		"cutin":
			if _pt > 0.5:
				_phase = "reveal"
				_pt = 0.0
		"done":
			_phase = "idle"
			Sfx.play("ui_click")


func _skip() -> void:
	_phase = "done"
	_shown = _results.size()
	for i in _flip_t.size():
		_flip_t[i] = maxf(_flip_t[i], 1.0)


# --- sequence ------------------------------------------------------------------------

func _center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.47)


func _step(delta: float) -> void:
	_pt += delta
	_shake = maxf(0.0, _shake - delta * 2.5)
	_flash = maxf(0.0, _flash - delta * 3.2)
	for s in _sparks:
		s[0] += s[1] * delta
		s[1] *= pow(0.12, delta)
		s[1].y += 60.0 * delta
		s[2] -= delta
	_sparks = _sparks.filter(func(s): return s[2] > 0.0)
	for r in _rings:
		r[0] += delta
	_rings = _rings.filter(func(r): return r[0] < 1.2)
	for i in _flip_t.size():
		if _flip_t[i] >= 0.0:
			_flip_t[i] += delta
	match _phase:
		"fall":
			if _pt >= 1.35:
				_phase = "burst"
				_pt = 0.0
				var c: Color = Gacha.RARITY_COLORS[_best]
				_burst(_center(), c, 60 + _best * 50)
				_rings.append([0.0, c])
				_rings.append([-0.12, Color.WHITE])
				_flash = 0.6 + 0.4 * _best
				_shake = 0.4 + 0.35 * _best
				Sfx.play("super_flash" if _best == 2 else ("rare_drop" if _best == 1 else "hit_heavy"))
				if _best == 2:
					Sfx.play("bell_big", -3.0)
		"burst":
			if _pt >= 0.7:
				_phase = "reveal"
				_pt = 10.0  # first card at once
		"reveal":
			var every := 0.22 if _results.size() > 1 else 0.0
			if _shown < _results.size() and _pt >= every:
				var r: Dictionary = _results[_shown]
				_flip_t[_shown] = 0.0
				_pt = 0.0
				var rect := _card_rect(_shown)
				var c: Color = Gacha.RARITY_COLORS[int(r.rarity)]
				_burst(rect.get_center(), c, 10 + int(r.rarity) * 14)
				_shown += 1
				if int(r.rarity) == 2 and r.get("kind", "") == "style":
					_phase = "cutin"
					_cutin = r
					_flash = 1.0
					_shake = 0.8
					Sfx.play("super_flash")
					Sfx.play("level_up", -2.0)
				else:
					Sfx.play("pickup" if int(r.rarity) == 0 else "rare_drop", -6.0 if int(r.rarity) == 0 else -2.0)
			elif _shown >= _results.size() and _pt > 0.5:
				_phase = "done"
		"cutin":
			if _pt >= 2.6:
				_phase = "reveal"
				_pt = 0.0
	if _phase == "cutin" and fmod(_pt, 0.12) < delta:
		var col := _col(str(_cutin.get("id", "")), ["gold", "yellow", "orange", "cyan"], GOLD)
		_burst(Vector2(randf() * size.x, size.y * 0.5 + randf_range(-90, 90)), col, 6)


func _burst(at: Vector2, col: Color, n: int) -> void:
	if FxSettings.level == 0:
		n = n / 3
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(80.0, 520.0)
		_sparks.append([at, Vector2(cos(a), sin(a)) * sp, randf_range(0.4, 1.1), col.lerp(Color.WHITE, randf() * 0.5), randf_range(1.5, 4.0)])


# --- drawing helpers ---------------------------------------------------------------

func _ink(pos: Vector2, s: String, sz: int, col := INK, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := PAPER) -> void:
	draw_string_outline(font, pos, s, align, width, sz, 5, Color(outline, 0.95))
	draw_string(font, pos, s, align, width, sz, col)


func _paper(r: Rect2, fill := PAPER, border := 2, border_col := INK) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border_col
	sb.set_border_width_all(border)
	draw_style_box(sb, r)


func _slant(r: Rect2, fill: Color, edge := INK, cut := 8.0) -> void:
	var pts := PackedVector2Array([r.position + Vector2(cut, 0), Vector2(r.end.x, r.position.y), r.end - Vector2(cut, 0), Vector2(r.position.x, r.end.y)])
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(4, 4))
	draw_colored_polygon(sh, INK)
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, edge, 2.5)


## Button: PixelLab art when there, else the slanted manga shape.
func _button(r: Rect2, label: String, sub: String, on: Callable, hot := true, enabled := true) -> void:
	var t := _tex("button_summon" if hot else "button")
	var hover := r.has_point(get_local_mouse_position())
	if t != null:
		draw_texture_rect(t, r, false, Color(1, 1, 1, 1.0 if enabled else 0.45))
	else:
		_slant(r, (RED if hot else PAPER).lightened(0.12 if hover else 0.0) if enabled else Color("8a8090"))
	var tc := PAPER if hot or t != null else INK
	_ink(Vector2(r.position.x, r.position.y + r.size.y * 0.5 + (0 if sub != "" else 7)), label, 20, tc, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, INK)
	if sub != "":
		_ink(Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 21), sub, 14, tc, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, INK)
	_hits.append([r, on])


func _crystal(c: Vector2, s: float) -> void:
	var t := _tex("crystal")
	if t != null:
		draw_texture_rect(t, Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), false)
		return
	var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.7, -s * 0.2), c + Vector2(0, s), c + Vector2(-s * 0.7, -s * 0.2)])
	draw_colored_polygon(pts, Color("8fd3ff"))
	draw_colored_polygon(PackedVector2Array([pts[0], pts[1], c]), Color("cfeaff"))
	pts.append(pts[0])
	draw_polyline(pts, INK, 2.0)


func _star(c: Vector2, r: float, col: Color, filled := true) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + TAU * i / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	if filled:
		draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, INK, 1.5)


# --- drawing ------------------------------------------------------------------------

func _draw() -> void:
	if not is_open:
		return
	_hits.clear()
	var W := size.x
	var H := size.y
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 14.0 if GameSettings.shake else Vector2.ZERO
	draw_set_transform(off)
	var b := _banner()
	var sid := str(b.get("style", "glutatem"))
	var accent := _col(sid, ["gold", "yellow", "orange", "cyan", "blue"], GOLD)
	var deep := _col(sid, ["night", "deep", "ink", "ash"], NIGHT)
	# night sky behind everything
	var bg := _tex("background")
	if bg != null:
		draw_texture_rect(bg, Rect2(0, 0, W, H), false, Color(0.75, 0.75, 0.85))
	else:
		for i in 12:
			var y := H * i / 12.0
			draw_rect(Rect2(0, y, W, H / 12.0 + 1), NIGHT.lerp(deep.darkened(0.3), float(i) / 12.0))
	for s in _stars:
		var p: Vector2 = s[0] * Vector2(W, H)
		var tw := 0.5 + 0.5 * sin(_t * 2.0 + s[2])
		draw_rect(Rect2(p, Vector2(s[1], s[1])), Color(1, 1, 1, 0.25 + 0.6 * tw))
	if _phase == "idle":
		_draw_shrine(W, H, b, sid, accent)
	if _phase != "idle":
		_draw_pull(W, H)
	draw_set_transform(Vector2.ZERO)
	if _flash > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, minf(0.7, _flash)))
	if _toast_t > 0.0:
		var tw2 := font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 40.0
		var tr := Rect2(W * 0.5 - tw2 * 0.5, H - 92, tw2, 36)
		_paper(tr, Color(PAPER, minf(1.0, _toast_t * 3.0)))
		_ink(Vector2(tr.position.x, tr.position.y + 25), _toast, 18, INK, HORIZONTAL_ALIGNMENT_CENTER, tw2)


func _draw_shrine(W: float, H: float, b: Dictionary, sid: String, accent: Color) -> void:
	# title
	var tt := _tex("title")
	if tt != null:
		var th := 64.0
		var tw := th * tt.get_width() / float(tt.get_height())
		draw_texture_rect(tt, Rect2(W * 0.5 - tw * 0.5, 10, tw, th), false)
	else:
		_ink(Vector2(0, 50), "STERNSCHREIN", 38, PAPER, HORIZONTAL_ALIGNMENT_CENTER, W, INK)
	# --- banner list (left)
	var lx := 24.0
	var ly := 92.0
	var bl: Array = Gacha.banners()
	for i in bl.size():
		var bi: Dictionary = bl[i]
		var on := i == banner_i
		var r := Rect2(lx + (14.0 if on else 0.0), ly + i * 62.0, 230, 54)
		var c := _col(str(bi.style), ["gold", "yellow", "orange", "cyan"], GOLD)
		_slant(r, c if on else Color(PAPER, 0.92))
		var em := _emblem(str(bi.style))
		if em != null:
			draw_texture_rect(em, Rect2(r.position + Vector2(10, 5), Vector2(44, 44)), false)
		_ink(r.position + Vector2(62, 23), Gacha.style_name(str(bi.style)), 18, INK)
		draw_string(font, r.position + Vector2(62, 43), str(bi.title), HORIZONTAL_ALIGNMENT_LEFT, 160, 13, INK)
		if Gacha.owns_style(str(bi.style)):
			_star(r.position + Vector2(r.size.x - 18, 16), 9.0, GOLD)
		var idx := i
		_hits.append([r, func(): _pick(idx)])
	# --- banner art (centre)
	var ax := 290.0
	var aw := W - ax - 330.0
	var ar := Rect2(ax, 92, aw, H - 92 - 110)
	draw_rect(ar.grow(5), INK)
	var art := _tex("banner_" + sid)
	if art != null:
		draw_texture_rect(art, ar, false)
	else:
		var a1 := _col(sid, ["ink", "night", "deep", "ash"], NIGHT)
		for i in 16:
			draw_rect(Rect2(ar.position.x, ar.position.y + ar.size.y * i / 16.0, ar.size.x, ar.size.y / 16.0 + 1), a1.lerp(accent.darkened(0.35), float(i) / 16.0))
	# speed rays from the emblem
	var ec := ar.position + Vector2(ar.size.x * 0.5, ar.size.y * 0.45)
	for i in 24:
		var a := TAU * i / 24.0 + _t * 0.15
		draw_line(ec + Vector2(cos(a), sin(a)) * 70, ec + Vector2(cos(a), sin(a)) * 420, Color(accent, 0.07), 10.0)
	var em2 := _emblem(sid)
	var es := 150.0 + sin(_t * 2.0) * 5.0
	if em2 != null:
		draw_texture_rect(em2, Rect2(ec - Vector2(es, es) * 0.5, Vector2(es, es)), false)
	# frame on top (manga ink panel)
	var fr := _tex("frame")
	if fr != null:
		draw_texture_rect(fr, ar.grow(10), false)
	else:
		draw_rect(ar, INK, false, 4.0)
	# banner text plate
	var plate := Rect2(ar.position.x + 18, ar.end.y - 108, ar.size.x - 36, 92)
	_slant(plate, Color(PAPER, 0.95), INK, 14.0)
	_ink(plate.position + Vector2(24, 34), str(b.get("title", "")), 28, INK)
	draw_string(font, plate.position + Vector2(26, 58), str(b.get("tagline", "")), HORIZONTAL_ALIGNMENT_LEFT, plate.size.x - 40, 15, Color(INK, 0.8))
	var feat := "Legendär: Kampfstil %s" % Gacha.style_name(sid)
	if Gacha.owns_style(sid):
		feat += "  ·  besitzt du (%d★)" % Gacha.stars(sid)
	draw_string(font, plate.position + Vector2(26, 80), feat, HORIZONTAL_ALIGNMENT_LEFT, plate.size.x - 40, 15, RED)
	var lab := Rect2(ar.position.x + 18, ar.position.y + 16, 150, 30)
	_slant(lab, RED)
	_ink(Vector2(lab.position.x, lab.position.y + 21), "BANNER", 17, PAPER, HORIZONTAL_ALIGNMENT_CENTER, lab.size.x, INK)
	# --- right column
	var rx := W - 310.0
	var pr := Rect2(rx, 92, 286, H - 92 - 110)
	draw_style_box(UiSkin.box("panel"), pr)
	var y := pr.position.y + 26
	_crystal(Vector2(rx + 40, y + 12), 16.0)
	_ink(Vector2(rx + 64, y + 22), "%d" % Gacha.crystals, 28, INK)
	draw_string(font, Vector2(rx + 64, y + 42), "Sternkristalle", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(INK, 0.7))
	y += 62
	var gr := Rect2(rx + 20, y, 246, 40)
	var ready := Gacha.daily_ready()
	_button(gr, "Tagesgeschenk +%d" % int(Gacha.data.get("daily", 100)) if ready else "Geschenk morgen wieder", "", _daily, ready, ready)
	var gift := _tex("gift")
	if gift != null and ready:
		draw_texture_rect(gift, Rect2(gr.position + Vector2(-10, -8), Vector2(36, 36)), false)
	y += 60
	# pity
	_ink(Vector2(rx + 22, y + 14), "Garantie", 18, INK)
	var left := Gacha.pity_max() - Gacha.pity
	draw_string(font, Vector2(rx + 22, y + 34), "Legendär spätestens in %d Zügen" % left, HORIZONTAL_ALIGNMENT_LEFT, 250, 14, INK)
	var bar := Rect2(rx + 22, y + 44, 242, 14)
	draw_rect(bar.grow(2), INK)
	draw_rect(bar, Color(INK, 0.4))
	var frac := float(Gacha.pity) / float(Gacha.pity_max())
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), GOLD)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, 3)), Color(1, 1, 1, 0.6))
	y += 72
	if Gacha.guaranteed:
		draw_string(font, Vector2(rx + 22, y), "Nächstes Legendär: sicher %s" % Gacha.style_name(sid), HORIZONTAL_ALIGNMENT_LEFT, 250, 14, RED)
	else:
		draw_string(font, Vector2(rx + 22, y), "Legendär: 50 %% %s" % Gacha.style_name(sid), HORIZONTAL_ALIGNMENT_LEFT, 250, 14, INK)
	y += 22
	draw_string(font, Vector2(rx + 22, y), "10er-Zug: mindestens 1× Episch", HORIZONTAL_ALIGNMENT_LEFT, 250, 14, INK)
	y += 18
	_button(Rect2(rx + 20, y, 246, 34), "Chancen ansehen (R)", "", func(): _show_rates = not _show_rates, false)
	# pull buttons (bottom)
	var by := H - 96.0
	var bw := 250.0
	var cx := ar.get_center().x
	_button(Rect2(cx - bw - 14, by, bw, 64), "1× Beschwören", "%d Kristalle · Taste 1" % Gacha.cost(1), func(): _pull(1), true, Gacha.can_pull(1))
	_button(Rect2(cx + 14, by, bw, 64), "10× Beschwören", "%d Kristalle · Taste 0" % Gacha.cost(10), func(): _pull(10), true, Gacha.can_pull(10))
	_crystal(Vector2(cx - bw - 4, by + 4), 12.0)
	_crystal(Vector2(cx + 24, by + 4), 12.0)
	draw_string(font, Vector2(24, H - 22), "↑↓ Banner   1 / 0 Beschwören   R Chancen   G Geschenk   Esc Zurück", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(PAPER, 0.75))
	if _show_rates:
		_draw_rates(W, H, b, sid)


func _draw_rates(W: float, H: float, b: Dictionary, sid: String) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
	var r := Rect2(W * 0.5 - 330, H * 0.5 - 230, 660, 460)
	draw_style_box(UiSkin.box("panel"), r)
	var x := r.position.x + 36
	var y := r.position.y + 50
	_ink(Vector2(x, y), "Chancen · %s" % b.get("title", ""), 26, INK)
	y += 40
	for i in [2, 1, 0]:
		var c: Color = Gacha.RARITY_COLORS[i]
		_star(Vector2(x + 10, y - 6), 9.0, c)
		draw_string(font, Vector2(x + 30, y), "%s" % Gacha.RARITY_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
		draw_string(font, Vector2(x + 150, y), ("%.1f %%" % (Gacha.rate(i) * 100.0)).replace(".", ","), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
		var what: String = ["Splitter, seltene Ausrüstung oder ein Farbstoff", "Teil des Banner-Outfits, Farbstoff oder epische Ausrüstung", "ein Kampfstil"][i]
		draw_string(font, Vector2(x + 240, y), what, HORIZONTAL_ALIGNMENT_LEFT, 360, 15, Color(INK, 0.85))
		y += 32
	y += 8
	var lines := [
		"Legendär: zu 50 %% %s. War es ein anderer Stil, ist das nächste Legendär sicher %s." % [Gacha.style_name(sid), Gacha.style_name(sid)],
		"Garantie: spätestens der %d. Zug ohne Legendär ist Legendär (gilt für alle Banner)." % Gacha.pity_max(),
		("Mit Garantie im Schnitt ein Legendär alle %.1f Züge." % Gacha.average_legendary()).replace(".", ","),
		"Ein 10er-Zug enthält immer mindestens ein Episch.",
		"Doppelte Kampfstile: ein Stern mehr (nur Optik, bis 6★) und %d Splitter." % int(Gacha.data.get("duplicate_splitter", 300)),
		"Alle Stile sind gleich stark wie Episch, Legendär heißt mehr Auswahl und Spektakel.",
		"Sternkristalle: Startgeschenk, täglich %d im Schrein, %d pro Stufenaufstieg." % [int(Gacha.data.get("daily", 100)), int(Gacha.data.get("level_up", 50))],
	]
	for l in lines:
		draw_string(font, Vector2(x, y), l, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 72, 15, INK)
		y += 26
	var parts: Array = Gacha.banner_parts(b)
	var skin_names: Array = StyleSkin.skins(str(b.get("style", ""))).filter(func(k): return k.get("unlock", {}).get("banner", false)).map(func(k): return "Skin " + str(k.name))
	if not parts.is_empty() or not skin_names.is_empty():
		var names: Array = parts.map(func(p): return CreatorCatalog.item_name(p.slot, p.id)) + skin_names
		draw_string(font, Vector2(x, y + 6), "Banner-Teile (Episch): " + ", ".join(names), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 72, 15, RED)
	draw_string(font, Vector2(x, r.end.y - 24), "Gezogen bisher: %d  ·  R oder Esc schließt" % Gacha.pulls_total, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(INK, 0.6))
	_hits.clear()
	_hits.append([Rect2(0, 0, W, H), func(): _show_rates = false])


func _card_rect(i: int) -> Rect2:
	var n := _results.size()
	var cw := 132.0
	var ch := 190.0
	if n <= 1:
		cw = 200.0
		ch = 290.0
		return Rect2(_center() - Vector2(cw, ch) * 0.5, Vector2(cw, ch))
	var cols := 5
	var gap := 18.0
	var row := i / cols
	var col := i % cols
	var total := cols * cw + (cols - 1) * gap
	var x0 := size.x * 0.5 - total * 0.5
	var y0 := size.y * 0.5 - ch - gap * 0.5 - 20.0
	return Rect2(x0 + col * (cw + gap), y0 + row * (ch + gap), cw, ch)


func _draw_pull(W: float, H: float) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.35))
	var c := _center()
	# the shrine's star circle the prizes come out of
	var ring := _tex("summon_circle")
	if ring != null:
		var rs := 420.0
		draw_set_transform(c, _t * 0.4, Vector2.ONE)
		draw_texture_rect(ring, Rect2(-Vector2(rs, rs) * 0.5, Vector2(rs, rs)), false, Color(1, 1, 1, 0.55))
		draw_set_transform(Vector2.ZERO)
	if _phase == "fall":
		# the star comes down; gold may hide behind blue until the last moment
		var k := clampf(_pt / 1.35, 0.0, 1.0)
		var shown := _best
		if _best == 2 and k < 0.72:
			shown = 0
		var col: Color = Gacha.RARITY_COLORS[shown]
		var from := Vector2(W * 0.82, -40)
		var p := from.lerp(c, k * k)
		for i in 14:
			var q := from.lerp(c, maxf(0.0, k - i * 0.02) * maxf(0.0, k - i * 0.02))
			draw_circle(q, 10.0 - i * 0.6, Color(col, 0.6 - i * 0.04))
		_star(p, 18.0 + k * 10.0, col.lightened(0.3))
		return
	# cards
	for i in _shown:
		_draw_card(i)
	if _phase == "cutin":
		_draw_cutin(W, H)
	elif _phase == "done":
		var msg := "Klick oder Leertaste: weiter"
		_ink(Vector2(0, H - 40), msg, 18, PAPER, HORIZONTAL_ALIGNMENT_CENTER, W, INK)


func _draw_card(i: int) -> void:
	var r: Dictionary = _results[i]
	var rect := _card_rect(i)
	var ft: float = _flip_t[i]
	var k := clampf(ft / 0.35, 0.0, 1.0)
	var sx := absf(cos(k * PI))
	var front := k >= 0.5
	var rar := int(r.rarity)
	var col: Color = Gacha.RARITY_COLORS[rar]
	var pop := 1.0 + 0.08 * maxf(0.0, 1.0 - absf(ft - 0.45) * 5.0)
	var cr := Rect2(rect.get_center() - Vector2(rect.size.x * sx * pop, rect.size.y * pop) * 0.5, Vector2(rect.size.x * sx * pop, rect.size.y * pop))
	if cr.size.x < 2.0:
		return
	if not front:
		var back := _tex("card_back")
		if back != null:
			draw_texture_rect(back, cr, false)
		else:
			_paper(cr, Color("1d1b33"), 3)
			_star(cr.get_center(), minf(cr.size.x, cr.size.y) * 0.25, Color("4d65b4"))
		return
	var frame := _tex("card_" + Gacha.RARITY_IDS[rar])
	if frame != null:
		draw_texture_rect(frame, cr, false)
	else:
		_paper(cr, PAPER, 4, col.darkened(0.2))
		draw_rect(Rect2(cr.position + Vector2(5, 5), Vector2(cr.size.x - 10, cr.size.y * 0.62)), Color(col, 0.35))
	var ic := Vector2(cr.get_center().x, cr.position.y + cr.size.y * 0.36)
	var isz := cr.size.y * 0.42
	match str(r.get("kind", "")):
		"style":
			var em := _emblem(str(r.id))
			if em != null:
				draw_texture_rect(em, Rect2(ic - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false)
		"gear":
			ItemIcon.draw_icon(self, ic, r.item, isz / 18.0)
		"color":
			var t := _tex("icon_dye")
			if t != null:
				draw_texture_rect(t, Rect2(ic - Vector2(isz, isz) * 0.4, Vector2(isz, isz) * 0.8), false, Color(str(r.get("color", "ffffff"))).lightened(0.3))
			else:
				draw_circle(ic, isz * 0.3, Color(str(r.get("color", "ffffff"))))
				draw_arc(ic, isz * 0.3, 0, TAU, 32, INK, 3.0)
		"skin":
			var em2 := StyleSkin.icon(str(r.get("style", "")), str(r.id))
			if em2 != null:
				draw_texture_rect(em2, Rect2(ic - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false)
			else:
				draw_circle(ic, isz * 0.3, StyleSkin.map_color(StyleSkin.info(str(r.get("style", "")), str(r.id)), Color("ff9a2a")))
		"part":
			var t2 := _tex("icon_outfit")
			if t2 != null:
				draw_texture_rect(t2, Rect2(ic - Vector2(isz, isz) * 0.45, Vector2(isz, isz) * 0.9), false)
			else:
				_star(ic, isz * 0.3, col)
		_:
			var t3 := _tex("icon_splitter")
			if t3 != null:
				draw_texture_rect(t3, Rect2(ic - Vector2(isz, isz) * 0.4, Vector2(isz, isz) * 0.8), false)
			else:
				_crystal(ic, isz * 0.3)
	var fs := 14 if cr.size.x < 160 else 20
	_ink(Vector2(cr.position.x + 6, cr.position.y + cr.size.y * 0.72), str(r.name), fs, INK, HORIZONTAL_ALIGNMENT_CENTER, cr.size.x - 12)
	draw_string(font, Vector2(cr.position.x + 6, cr.position.y + cr.size.y * 0.72 + fs + 4), Gacha.RARITY_NAMES[rar], HORIZONTAL_ALIGNMENT_CENTER, cr.size.x - 12, fs - 3, col.darkened(0.25))
	if cr.size.x >= 160:  # small cards have no room for the note
		draw_string(font, Vector2(cr.position.x + 6, cr.position.y + cr.size.y * 0.72 + fs * 2 + 6), str(r.get("text", "")), HORIZONTAL_ALIGNMENT_CENTER, cr.size.x - 12, 11, Color(INK, 0.75))
	if r.get("new", false):
		var nb := Rect2(cr.position + Vector2(-6, -8), Vector2(52, 24))
		_slant(nb, RED)
		_ink(Vector2(nb.position.x, nb.position.y + 18), "NEU", 15, PAPER, HORIZONTAL_ALIGNMENT_CENTER, nb.size.x, INK)
	if r.get("kind", "") == "style":
		for s in int(r.get("stars", 1)):
			_star(Vector2(cr.position.x + 16 + s * 16, cr.end.y - 14), 7.0, GOLD)


func _draw_cutin(W: float, H: float) -> void:
	var sid := str(_cutin.get("id", ""))
	var a := clampf(_pt / 0.25, 0.0, 1.0)
	var c1 := _col(sid, ["gold", "yellow", "orange", "cyan"], GOLD)
	var c2 := _col(sid, ["ink", "night", "deep"], NIGHT)
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55 * a))
	var bh := 230.0 * a
	var y := H * 0.5
	var band := PackedVector2Array([Vector2(0, y - bh * 0.5 + 40), Vector2(W, y - bh * 0.5 - 40), Vector2(W, y + bh * 0.5 - 40), Vector2(0, y + bh * 0.5 + 40)])
	draw_colored_polygon(band, c2)
	var inner := PackedVector2Array([band[0] + Vector2(0, 26), band[1] + Vector2(0, 26), band[2] - Vector2(0, 26), band[3] - Vector2(0, 26)])
	draw_colored_polygon(inner, c2.lerp(c1, 0.22))
	# speed lines across the band
	for i in 40:
		var ly := y + randf_range(-bh * 0.45, bh * 0.45)
		var lx := fmod(i * 97.0 + _t * 1800.0, W + 400.0) - 200.0
		draw_line(Vector2(lx, ly), Vector2(lx + randf_range(80, 260), ly - 12), Color(c1, 0.35), 2.0)
	band.append(band[0])
	draw_polyline(band, c1, 5.0)
	var slide := (1.0 - a) * W * 0.4
	var em := _emblem(sid)
	if em != null:
		var es := 210.0
		draw_texture_rect(em, Rect2(Vector2(W * 0.24 - es * 0.5 - slide, y - es * 0.5), Vector2(es, es)), false)
	_ink(Vector2(W * 0.4 + slide, y - 30), "LEGENDÄR", 24, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, INK)
	_ink(Vector2(W * 0.4 + slide, y + 34), Gacha.style_name(sid).to_upper(), 64, PAPER, HORIZONTAL_ALIGNMENT_LEFT, -1, INK)
	var sub := "Neuer Kampfstil!" if _cutin.get("new", false) else "Stern %d" % int(_cutin.get("stars", 1))
	_ink(Vector2(W * 0.4 + slide, y + 70), sub, 22, c1, HORIZONTAL_ALIGNMENT_LEFT, -1, INK)
	_ink(Vector2(W * 0.4 + slide, y + 96), str(Gacha.style_info(sid).get("text", "")), 16, PAPER, HORIZONTAL_ALIGNMENT_LEFT, W * 0.55, INK)


## Additive light: glows, star trail, sparks and rings (reads as bloom).
func _soft(at: Vector2, radius: float, col: Color) -> void:
	_glow.draw_texture_rect(_soft_tex, Rect2(at - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, col)


func _draw_glow() -> void:
	if not is_open:
		return
	var g := _glow
	var c := _center()
	var amt := 0.5 if FxSettings.level == 0 else 1.0
	if _phase == "idle" or _phase == "done":
		var sid := str(_banner().get("style", "glutatem"))
		var accent := _col(sid, ["gold", "yellow", "orange", "cyan"], GOLD)
		var ar_c := Vector2(290.0 + (size.x - 620.0) * 0.5, 92 + (size.y - 202.0) * 0.45)
		if _phase == "idle":
			_soft(ar_c, 230.0 + sin(_t * 2.0) * 10.0, Color(accent, 0.45 * amt))
	if _phase == "fall":
		var k := clampf(_pt / 1.35, 0.0, 1.0)
		var shown := _best if not (_best == 2 and k < 0.72) else 0
		var col: Color = Gacha.RARITY_COLORS[shown]
		var p := Vector2(size.x * 0.82, -40).lerp(c, k * k)
		_soft(p, 110.0, Color(col, 0.9 * amt))
		_soft(p, 40.0, Color(1, 1, 1, 0.8))
		_soft(c, 120.0 + k * 160.0, Color(col, 0.5 * k * amt))
	if _phase == "burst" or (_phase == "reveal" and _shown <= 1):
		var col2: Color = Gacha.RARITY_COLORS[_best]
		var e := 1.0 - clampf(_pt / 0.9, 0.0, 1.0) if _phase == "burst" else 0.3
		_soft(c, 380.0, Color(col2, 0.8 * e * amt))
		_soft(c, 140.0, Color(1, 1, 1, 0.7 * e))
		if _best == 2:
			for j in 3:
				var wdt := 50.0 + j * 50.0
				g.draw_rect(Rect2(c.x - wdt * 0.5, 0, wdt, size.y), Color(col2, 0.16 * e * amt))
	for i in _shown:
		var r: Dictionary = _results[i]
		if int(r.rarity) >= 1 and _phase != "cutin":
			var rect := _card_rect(i)
			var col3: Color = Gacha.RARITY_COLORS[int(r.rarity)]
			var pulse := 0.75 + 0.25 * sin(_t * 4.0 + i)
			_soft(rect.get_center(), rect.size.y * 0.85, Color(col3, (0.35 if int(r.rarity) == 1 else 0.6) * pulse * amt))
	for s in _sparks:
		var life: float = s[2]
		_soft(s[0], s[4] * 5.0, Color(s[3], 0.5 * minf(1.0, life * 2.0) * amt))
		g.draw_circle(s[0], s[4], Color(s[3], 0.9 * minf(1.0, life * 2.0)))
	for r in _rings:
		var age: float = r[0]
		if age > 0.0:
			g.draw_arc(c, 30.0 + age * 620.0, 0, TAU, 64, Color(r[1], 0.6 * (1.0 - age / 1.2) * amt), 10.0 * (1.0 - age / 1.2) + 2.0)
	if _phase == "cutin":
		var sid2 := str(_cutin.get("id", ""))
		var c1 := _col(sid2, ["gold", "yellow", "orange", "cyan"], GOLD)
		_soft(Vector2(size.x * 0.24, size.y * 0.5), 260.0, Color(c1, 0.75 * amt))
		_soft(Vector2(size.x * 0.6, size.y * 0.5), 420.0, Color(c1, 0.25 * amt))
