class_name FountainFx
extends Node2D
## Water of the courtyard fountain: glints on the basins and droplets
## falling from the top tier. Unshaded, glints bright enough to bloom.

var _t := 0.0
var _drops: Array = []  # [pos, vel]


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m


func _process(delta: float) -> void:
	_t += delta
	if randf() < delta * 14.0:
		var side := -1.0 if randf() < 0.5 else 1.0
		_drops.append([Vector2(side * randf_range(20, 25), -80), Vector2(side * randf_range(1, 4), randf_range(-6, 0))])
	for d in _drops:
		d[1].y += 160.0 * delta
		d[0] += d[1] * delta
	_drops = _drops.filter(func(d): return d[0].y < -42.0)
	queue_redraw()


func _draw() -> void:
	for d in _drops:
		draw_rect(Rect2((d[0] as Vector2).round(), Vector2(1, 2)), Color(0.75, 0.95, 1.3, 0.9))
	# glints wandering over the lower and upper basin
	for i in 6:
		var ph := _t * 0.9 + i * 1.7
		var on := fmod(ph, 2.0) < 0.35
		if not on:
			continue
		var lower := i < 4
		var x := sin(i * 2.3 + floor(ph / 2.0)) * (38.0 if lower else 22.0)
		var y := -41.0 if lower else -84.0
		draw_rect(Rect2(Vector2(x, y).round(), Vector2(2, 1)), Color(1.8, 1.9, 2.0))
