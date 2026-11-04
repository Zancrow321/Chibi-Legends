extends CanvasLayer
## Autoload "AreaTransition": the switch between overworld and combat areas.
##
## A manga panel wipe: an ink panel with a slanted edge sweeps across the
## screen (accent stripe and halftone dots on its leading edge), a slanted
## paper title card names the new area, then the ink sweeps on and reveals
## the new scene. Behind the covered screen the scene is reloaded and Main
## builds the other mode (see GameFlow). The tree is paused until the reveal,
## so nobody moves while the card is up.
##
##   AreaTransition.go("trainingswald")   # into a combat area
##   AreaTransition.go("akademie_hof")    # back to the overworld

const COVER := 0.42
const HOLD := 0.95
const REVEAL := 0.5
const SLANT := 160.0

var _ctl: Control
var _font: Font
var _phase := ""  # "", cover, hold, reveal
var _t := 0.0
var _target := ""
var _title := ""
var _sub := ""
var _accent := Color.WHITE
var _combat := false
var _reloaded := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")
	_ctl = Control.new()
	_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctl.draw.connect(_draw_wipe)
	add_child(_ctl)


func busy() -> bool:
	return _phase != ""


## Starts the switch into area `id` (see GameFlow.AREAS).
func go(id: String) -> void:
	if busy():
		return
	var info := GameFlow.area_info(id)
	_target = id
	_title = info.title
	_sub = info.sub
	_accent = info.accent
	_combat = info.kind == GameFlow.DUNGEON
	_phase = "cover"
	_t = 0.0
	_reloaded = false
	get_tree().paused = true
	Sfx.play("menu_open")


## Shows only the title card (first start), without reloading.
func intro(id: String) -> void:
	if busy():
		return
	var info := GameFlow.area_info(id)
	_title = info.title
	_sub = info.sub
	_accent = info.accent
	_combat = info.kind == GameFlow.DUNGEON
	_target = ""
	_phase = "hold"
	_t = HOLD * 0.35
	_reloaded = true


func _process(delta: float) -> void:
	if _phase == "":
		return
	_t += delta
	match _phase:
		"cover":
			if _t >= COVER:
				_phase = "hold"
				_t = 0.0
				Sfx.play("ui_confirm")
		"hold":
			if not _reloaded and _t > 0.12:
				_reloaded = true
				GameFlow.enter(_target)
				get_tree().reload_current_scene()
			if _t >= HOLD:
				_phase = "reveal"
				_t = 0.0
				get_tree().paused = false
		"reveal":
			if _t >= REVEAL:
				_phase = ""
	_ctl.size = _ctl.get_viewport_rect().size
	_ctl.queue_redraw()


static func _ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3.0)


func _draw_wipe() -> void:
	if _phase == "":
		return
	var W := _ctl.size.x
	var H := _ctl.size.y
	var ink := UiSkin.INK
	# x of the slanted edge at the top; the edge leans by SLANT to the bottom
	var e := 0.0
	var left_covered := false  # reveal: ink stays on the left of the edge
	match _phase:
		"cover":
			e = lerpf(W + 40.0, -SLANT - 40.0, _ease(_t / COVER))
		"hold":
			e = -SLANT - 40.0
		"reveal":
			e = lerpf(W + 40.0, -SLANT - 40.0, _ease(_t / REVEAL))
			left_covered = true
	var top := Vector2(e, 0)
	var bot := Vector2(e + SLANT, H)
	var poly: PackedVector2Array
	# outer edge always beyond the slanted one, so the polygon stays convex
	var lx := minf(-10.0, e - 10.0)
	var rx := maxf(W + 10.0, e + SLANT + 10.0)
	if left_covered:
		poly = PackedVector2Array([Vector2(lx, 0), top, bot, Vector2(lx, H)])
	else:
		poly = PackedVector2Array([top, Vector2(rx, 0), Vector2(rx, H), bot])
	_ctl.draw_colored_polygon(poly, ink)
	# speed lines inside the ink
	var seed := 0
	for i in 14:
		seed = (seed * 1103515245 + 12345 + i * 977) & 0x7fffffff
		var y := float(seed % int(maxf(H, 1.0)))
		var len := 80.0 + float(seed % 220)
		var x0 := e + SLANT * (y / H)
		var xs := x0 + 30.0 + float(seed % 400) if not left_covered else x0 - 30.0 - float(seed % 400) - len
		_ctl.draw_rect(Rect2(xs, y, len, 2), Color(1, 1, 1, 0.07))
	if _phase != "hold":
		# accent stripe and halftone on the leading edge
		var dir := -1.0 if not left_covered else 1.0
		var s0 := 0.0 if not left_covered else 6.0
		var stripe := PackedVector2Array([top + Vector2(dir * s0, 0), top + Vector2(dir * (s0 + 14.0), 0), bot + Vector2(dir * (s0 + 14.0), 0), bot + Vector2(dir * s0, 0)])
		_ctl.draw_colored_polygon(stripe, _accent)
		var step := 9.0
		var y2 := 0.0
		var row := 0
		while y2 < H:
			var ex := e + SLANT * (y2 / H) + dir * 18.0
			for k in 7:
				var r := 3.6 - k * 0.5
				if r <= 0.6:
					break
				var x := ex + dir * (k * step + (step * 0.5 if row % 2 == 1 else 0.0))
				_ctl.draw_rect(Rect2(x - r * 0.5, y2 - r * 0.5, r, r), ink)
			y2 += step
			row += 1
	_draw_card(W, H)


func _draw_card(W: float, H: float) -> void:
	# slides in during the hold, out to the left during the reveal
	var slide := 0.0
	if _phase == "hold":
		slide = 1.0 - _ease(_t / 0.28)
	elif _phase == "reveal":
		slide = -_ease(_t / (REVEAL * 0.8))
	else:
		return
	var cw := minf(640.0, W - 60.0)
	var ch := 128.0
	var c := Vector2(W * 0.5 + slide * (W * 0.5 + cw), H * 0.5)
	var lean := 26.0
	var pts := PackedVector2Array([c + Vector2(-cw * 0.5 + lean, -ch * 0.5), c + Vector2(cw * 0.5 + lean, -ch * 0.5), c + Vector2(cw * 0.5 - lean, ch * 0.5), c + Vector2(-cw * 0.5 - lean, ch * 0.5)])
	# drop shadow in the accent colour, then ink border and paper
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(10, 10))
	_ctl.draw_colored_polygon(shadow, _accent)
	var border := PackedVector2Array()
	for p in pts:
		border.append(c + (p - c) * 1.0 + (p - c).sign() * 5.0)
	_ctl.draw_colored_polygon(border, UiSkin.INK)
	_ctl.draw_colored_polygon(pts, UiSkin.PAPER)
	# halftone in the lower right corner of the card
	var y := c.y + 8.0
	var row := 0
	while y < c.y + ch * 0.5 - 6.0:
		var fy := (y - c.y) / (ch * 0.5)
		var x := c.x + cw * 0.08 + (3.0 if row % 2 == 1 else 0.0)
		while x < c.x + cw * 0.5 - lean * fy - 10.0:
			var fx := (x - c.x) / (cw * 0.5)
			var r := clampf((fx + fy - 0.7) * 3.0, 0.0, 2.6)
			if r > 0.5:
				_ctl.draw_rect(Rect2(x, y, r, r), Color(UiSkin.INK, 0.35))
			x += 6.0
		y += 6.0
		row += 1
	# tag in the accent colour
	var tag := "KAMPFAREAL" if _combat else "OVERWORLD"
	var tp := c + Vector2(-cw * 0.5 + lean + 8.0, -ch * 0.5 - 14.0)
	var tw := _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 22.0
	_ctl.draw_colored_polygon(PackedVector2Array([tp, tp + Vector2(tw, 0), tp + Vector2(tw - 6, 26), tp + Vector2(-6, 26)]), _accent)
	_ctl.draw_string(_font, tp + Vector2(8, 20), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiSkin.PAPER)
	# title and subtitle
	_ctl.draw_string_outline(_font, c + Vector2(-cw * 0.5 + 40.0, 6), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, 8, UiSkin.PAPER)
	_ctl.draw_string(_font, c + Vector2(-cw * 0.5 + 40.0, 6), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, UiSkin.INK)
	_ctl.draw_rect(Rect2(c + Vector2(-cw * 0.5 + 36.0, 18), Vector2(cw * 0.55, 3)), _accent)
	_ctl.draw_string(_font, c + Vector2(-cw * 0.5 + 34.0, 46), _sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(UiSkin.INK, 0.8))
