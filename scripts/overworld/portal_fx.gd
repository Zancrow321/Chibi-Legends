class_name PortalFx
extends Node2D
## Animated fill for a gate: an open portal (turquoise rings swirling inward,
## motes rising, bright enough to bloom) or a sealed gate (pulsing orange
## seal ring with embers drifting up). Pixel-snapped, drawn unshaded.

var sealed := false
## Violet portal (Turm der Prüfungen) instead of turquoise.
var violet := false
var _t := 0.0
var _motes: Array = []  # [pos, vel, life]


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func _process(delta: float) -> void:
	_t += delta
	if randf() < delta * (10.0 if not sealed else 7.0):
		var p := Vector2(randf_range(-12, 12), randf_range(-26, 30)) if not sealed else Vector2(randf_range(-26, 26), randf_range(10, 40))
		_motes.append([p, Vector2(randf_range(-4, 4), randf_range(-22, -10)), randf_range(1.0, 2.0)])
	for m in _motes:
		m[0] += m[1] * delta
		m[2] -= delta
	_motes = _motes.filter(func(m): return m[2] > 0.0)
	queue_redraw()


func _draw() -> void:
	if sealed:
		var k := 0.6 + 0.4 * absf(sin(_t * 1.4))
		var col := Color(1.6, 0.7, 0.2, 0.55 * k)
		for i in 28:
			var a := TAU * i / 28.0 + _t * 0.4
			var p := Vector2(cos(a) * 15.0, sin(a) * 15.0).round()
			draw_rect(Rect2(p, Vector2(2, 2)), col)
		for i in 3:
			var a2 := TAU * i / 3.0 - _t * 0.9
			var q := Vector2(cos(a2) * 8.0, sin(a2) * 8.0).round()
			draw_rect(Rect2(q - Vector2(1, 1), Vector2(3, 3)), Color(2.0, 1.1, 0.4, 0.7 * k))
		for m in _motes:
			var a3 := clampf(m[2], 0.0, 1.0)
			draw_rect(Rect2((m[0] as Vector2).round(), Vector2(1, 1)), Color(2.0, 0.9, 0.3, a3))
		return
	# portal: rings swirling inward inside the oval (rx 13, ry 34)
	for ring in 5:
		var f := fposmod(ring / 5.0 - _t * 0.35, 1.0)
		var rx := 13.0 * f
		var ry := 34.0 * f
		var n := int(10 + 26 * f)
		var col := (Color(1.3, 0.6, 1.8, 0.55 * (1.0 - f * 0.6)) if violet else Color(0.4, 1.6, 1.3, 0.55 * (1.0 - f * 0.6)))
		for i in n:
			var a := TAU * i / n + _t * (1.2 - f) + ring
			if fmod(i, 3) == 0:
				continue
			var p := Vector2(cos(a) * rx, sin(a) * ry).round()
			draw_rect(Rect2(p, Vector2(1, 1)), col)
	var core := 0.5 + 0.3 * sin(_t * 2.2)
	draw_rect(Rect2(-2, -6, 4, 12), Color(1.8, 1.0, 2.0, core) if violet else Color(0.8, 2.0, 1.7, core))
	for m in _motes:
		var a4 := clampf(m[2], 0.0, 1.0)
		draw_rect(Rect2((m[0] as Vector2).round(), Vector2(1, 1)), Color(1.7, 1.0, 2.0, a4) if violet else Color(0.9, 2.0, 1.6, a4))
