class_name MarksShop
extends Control
## Raid-Marken-Tausch at Schmiedin Hino: pick the kind of piece you want
## (Waffe, Oberteil, Hose, Schuhe, Accessoire, Talisman) and the rarity
## (Episch or Legendär); the stats roll randomly (RaidLoot.buy).
## Keys: ←→ kind, ↑↓ rarity, Enter/Space trade, Esc close. Mouse works too.

const INK := UiSkin.INK
const PAPER := UiSkin.PAPER
const RED := UiSkin.RED
const VIOLET := Color("a46bff")
const RARITIES := [Loot.EPIC, Loot.LEGENDARY]

var font: Font
var is_open := false
var kind := 0
var rar := 0
var last_item := {}
var _t := 0.0
var _hits: Array = []
var _toast := ""
var _toast_t := 0.0


func _ready() -> void:
	add_to_group("marks_shop")
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
	last_item = {}
	get_tree().paused = true
	Sfx.play("menu_open")


func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	get_tree().call_group("profile_user", "apply_profile")
	Sfx.play("menu_close")


func _process(delta: float) -> void:
	_t += delta
	_toast_t = maxf(0.0, _toast_t - delta)
	position = Vector2.ZERO
	size = get_viewport_rect().size
	if is_open:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				close()
			KEY_LEFT, KEY_A:
				_pick(posmod(kind - 1, Profile.KINDS.size()), rar)
			KEY_RIGHT, KEY_D:
				_pick(posmod(kind + 1, Profile.KINDS.size()), rar)
			KEY_UP, KEY_W, KEY_DOWN, KEY_S:
				_pick(kind, 1 - rar)
			KEY_ENTER, KEY_SPACE, KEY_J:
				trade()
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
				trade()
			JOY_BUTTON_DPAD_LEFT:
				_pick(posmod(kind - 1, Profile.KINDS.size()), rar)
			JOY_BUTTON_DPAD_RIGHT:
				_pick(posmod(kind + 1, Profile.KINDS.size()), rar)
			JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN:
				_pick(kind, 1 - rar)
	get_viewport().set_input_as_handled()


func _pick(k: int, r: int) -> void:
	if k != kind or r != rar:
		kind = k
		rar = r
		Sfx.play("ui_click", -4.0)


## Trades for the selected piece; true when it worked.
func trade() -> bool:
	if Net.is_online():
		_trade_online()
		return true
	var why := RaidLoot.buy(Profile.KINDS[kind], RARITIES[rar])
	if why != "":
		_say(why)
		Sfx.play("ui_error")
		return false
	last_item = Profile.items.back()
	_say("%s geschmiedet!" % last_item.name)
	Sfx.play("rare_drop", -2.0)
	return true


## Online: the server takes the marks and rolls the piece.
func _trade_online() -> void:
	var price := RaidLoot.price(RARITIES[rar])
	if Profile.marks < price:
		_say("Zu wenig Raid-Marken (%d nötig)" % price)
		Sfx.play("ui_error")
		return
	if Profile.bag_full():
		_say("Die Tasche ist voll")
		Sfx.play("ui_error")
		return
	var r: Dictionary = await Net.call_fn("cl_buy", {"kind": Profile.KINDS[kind], "rarity": RARITIES[rar], "level": Profile.level})
	if not r.ok:
		_say("Server: %s" % r.error)
		Sfx.play("ui_error")
		return
	Profile.marks = int(r.data.total_marks)
	var it := Net.build_item(r.data.drop)
	Profile.add_item(it)  # saves
	last_item = it
	_say("%s geschmiedet!" % it.name)
	Sfx.play("rare_drop", -2.0)


func _say(s: String) -> void:
	_toast = s
	_toast_t = 2.6


func _ink(pos: Vector2, s: String, sz: int, col := INK, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := PAPER) -> void:
	draw_string_outline(font, pos, s, align, width, sz, 5, Color(outline, 0.95))
	draw_string(font, pos, s, align, width, sz, col)


func _draw() -> void:
	if not is_open:
		return
	_hits.clear()
	var W := size.x
	var H := size.y
	draw_rect(Rect2(0, 0, W, H), Color(INK, 0.72))
	var pw := minf(900.0, W - 40.0)
	var ph := minf(520.0, H - 80.0)
	var R := Rect2(W * 0.5 - pw * 0.5, H * 0.5 - ph * 0.5, pw, ph)
	draw_style_box(UiSkin.box("panel"), R)
	var x0 := R.position.x + 28.0
	_ink(Vector2(x0, R.position.y + 44), "Raid-Marken tauschen", 28, INK)
	_ink(Vector2(x0, R.position.y + 70), "Schmiedin Hino: \"Sag mir, was du brauchst. Wie gut es wird, entscheidet die Glut.\"", 15, Color(INK, 0.75))
	# wallet
	var wal := "%d Raid-Marken" % Profile.marks
	var ww := font.get_string_size(wal, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var wx := R.end.x - 28.0 - ww
	draw_circle(Vector2(wx - 16, R.position.y + 37), 9, INK)
	draw_circle(Vector2(wx - 16, R.position.y + 37), 7, VIOLET)
	_ink(Vector2(wx, R.position.y + 44), wal, 20, INK)
	# kinds
	var n := Profile.KINDS.size()
	var cw := (pw - 56.0 - 10.0 * (n - 1)) / n
	var cy := R.position.y + 96.0
	for i in n:
		var cr := Rect2(x0 + i * (cw + 10.0), cy, cw, 128)
		var on := i == kind
		draw_rect(Rect2(cr.position + Vector2(3, 3), cr.size), INK)
		draw_rect(cr, Color("fff4e0") if on else PAPER)
		draw_rect(cr, RED if on else INK, false, 3.0 if on else 2.0)
		var preview := {"slot": Profile.KINDS[i], "rarity": RARITIES[rar], "icon": 0}
		ItemIcon.draw_icon(self, cr.get_center() + Vector2(0, -14), preview, 3.4)
		_ink(Vector2(cr.position.x, cr.end.y - 14), Profile.SLOT_NAMES[Profile.KINDS[i]], 16, INK, HORIZONTAL_ALIGNMENT_CENTER, cr.size.x)
		var idx := i
		_hits.append([cr, func(): _pick(idx, rar)])
	# rarities
	var ry := cy + 150.0
	for j in RARITIES.size():
		var info: Dictionary = Loot.RARITIES[RARITIES[j]]
		var label := "%s  ·  %d Marken" % [info.name, RaidLoot.price(RARITIES[j])]
		var rr := Rect2(x0 + j * 270.0, ry, 256, 40)
		var on := j == rar
		draw_rect(Rect2(rr.position + Vector2(3, 3), rr.size), INK)
		draw_rect(rr, info.color if on else PAPER)
		draw_rect(rr, INK, false, 2.0)
		_ink(Vector2(rr.position.x, rr.position.y + 27), label, 18, INK, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
		var jdx := j
		_hits.append([rr, func(): _pick(kind, jdx)])
	# trade button
	var can := Profile.marks >= RaidLoot.price(RARITIES[rar])
	var br := Rect2(R.end.x - 28.0 - 220.0, ry, 220, 40)
	draw_rect(Rect2(br.position + Vector2(3, 3), br.size), INK)
	draw_rect(br, RED if can else Color("8a8590"))
	_ink(Vector2(br.position.x, br.position.y + 27), "Schmieden", 20, PAPER, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, INK)
	_hits.append([br, func(): trade()])
	# what you get / last result
	var iy := ry + 64.0
	var info2: Dictionary = Loot.RARITIES[RARITIES[rar]]
	var hint := "%s %s, Gegenstandsstufe %d, %d zufällige Werte, Hauptwert immer %s." % [
		info2.name, Profile.SLOT_NAMES[Profile.KINDS[kind]], Profile.level, int(info2.rolls),
		Loot.STATS[Loot.MAIN_STAT[Profile.KINDS[kind]]].name]
	if RARITIES[rar] == Loot.LEGENDARY:
		hint += " Mit legendärer Veränderung für deinen Kampfstil."
	_ink(Vector2(x0, iy), hint, 15, Color(INK, 0.8), HORIZONTAL_ALIGNMENT_LEFT, pw - 56.0)
	if not last_item.is_empty():
		var lr := Rect2(x0, iy + 18, pw - 56.0, R.end.y - iy - 42)
		draw_rect(lr, Color(Loot.color(last_item), 0.18))
		draw_rect(lr, Loot.color(last_item), false, 2.0)
		ItemFrame.box(self, Rect2(lr.position + Vector2(12, lr.size.y * 0.5 - 32), Vector2(64, 64)), last_item, float(Time.get_ticks_msec()) / 1000.0)
		_ink(Vector2(lr.position.x + 92, lr.position.y + 30), str(last_item.name), 20, Loot.color(last_item), HORIZONTAL_ALIGNMENT_LEFT, -1.0, INK)
		var sy := lr.position.y + 54.0
		for st in last_item.stats:
			_ink(Vector2(lr.position.x + 92, sy), Loot.stat_line(st, float(last_item.stats[st])), 15, INK)
			sy += 20.0
	var keys := "←→ Teil   ↑↓ Seltenheit   Enter schmieden   Esc schließen"
	draw_string_outline(font, Vector2(R.position.x + 6, R.end.y + 28), keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, INK)
	draw_string(font, Vector2(R.position.x + 6, R.end.y + 28), keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, PAPER)
	if _toast_t > 0.0:
		var tw := font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 36.0
		var tr2 := Rect2(R.get_center().x - tw * 0.5, R.end.y - 50, tw, 34)
		draw_rect(tr2.grow(2), INK)
		draw_rect(tr2, Color(PAPER, minf(1.0, _toast_t * 3.0)))
		_ink(Vector2(tr2.position.x, tr2.position.y + 23), _toast, 17, INK, HORIZONTAL_ALIGNMENT_CENTER, tw)
