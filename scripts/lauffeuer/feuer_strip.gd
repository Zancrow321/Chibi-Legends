class_name FeuerStrip
extends Node2D
## Plays one PixelLab effect strip of Lauffeuer (assets/vfx/lauffeuer, frames
## side by side, sizes and timing in fx.json) additively and brighter than
## white, so the bloom makes it glow. One-shot strips free themselves after
## the last frame; loops run until `life` runs out or free() is called.
##   FeuerStrip.spawn(parent, "ausbruch", pos, {"scale": 2.0, "anchor": "bottom"})

const DIR := "res://assets/vfx/lauffeuer/"

static var _info: Dictionary = {}
static var _tex: Dictionary = {}

var fx_name := ""
var loop := false
var life := -1.0  # seconds a loop lives (-1 = until freed)
var speed := 1.0
var size := 1.0
var anchor := "center"  # "center" or "bottom" (bottom middle at the position)
var flip := false
var hdr := 1.0  # extra brightness on top of FxSettings.boost()
var tint := Color.WHITE
var alpha := 1.0
var fade := 0.15  # fade out over the last seconds of a timed loop
var hold_last := 0.0  # one-shot: keep the last frame this long
var frame_override := -1  # >= 0: show this frame instead of the timed one
var _t := 0.0
var _left := 0.0


static func info(n: String) -> Dictionary:
	if _info.is_empty():
		var f := FileAccess.open(DIR + "fx.json", FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_info = d
	return _info.get(n, {})


static func texture(n: String) -> Texture2D:
	if not _tex.has(n):
		var p := DIR + n + ".png"
		_tex[n] = load(p) if ResourceLoader.exists(p) else null
	return _tex[n]


static func spawn(parent: Node, n: String, pos: Vector2, opts := {}) -> FeuerStrip:
	var s := FeuerStrip.new()
	s.fx_name = n
	s.loop = bool(info(n).get("loop", false))
	for k in opts:
		s.set(k, opts[k])
	s.position = pos
	parent.add_child(s)
	return s


## Total length of one pass in seconds.
static func length(n: String) -> float:
	var ms: Array = info(n).get("ms", [])
	var total := 0.0
	for m in ms:
		total += float(m) / 1000.0
	return maxf(total, 0.05)


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 4
	_left = life


func frame_now() -> int:
	var inf := info(fx_name)
	var n := int(inf.get("frames", 1))
	if frame_override >= 0:
		return clampi(frame_override, 0, n - 1)
	var ms: Array = inf.get("ms", [])
	var total := length(fx_name)
	var t := fmod(_t, total) if loop else minf(_t, total - 0.0001)
	var acc := 0.0
	for i in ms.size():
		acc += float(ms[i]) / 1000.0
		if t < acc:
			return i
	return n - 1


func _process(delta: float) -> void:
	_t += delta * speed
	if loop:
		if life >= 0.0:
			_left -= delta
			if _left <= 0.0:
				queue_free()
				return
	elif frame_override < 0 and _t >= length(fx_name) + hold_last:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var tex := texture(fx_name)
	if tex == null:
		return
	var inf := info(fx_name)
	var w := float(inf.get("w", 32))
	var h := float(inf.get("h", 32))
	var src := Rect2(frame_now() * w, 0, w, h)
	var dw := w * size
	var dh := h * size
	var off := Vector2(-dw / 2.0, -dh if anchor == "bottom" else -dh / 2.0)
	var a := alpha
	if loop and life >= 0.0 and fade > 0.0:
		a *= clampf(_left / fade, 0.0, 1.0)
	var b := FxSettings.boost() * hdr
	var col := Color(tint.r * b, tint.g * b, tint.b * b, a)
	if flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	draw_texture_rect_region(tex, Rect2(off, Vector2(dw, dh)), src, col)
