class_name DamageNumbers
extends Node2D
## Big, stacked pop-up damage numbers and reaction names.
## Lives on a CanvasLayer and maps world positions to the screen, so the
## text stays crisp at any camera zoom.

const LIFE := 1.1
const STACK_STEP := 44.0
const STACK_WINDOW := 0.5

var font: Font
var _items: Array = []  # {pos, text, color, size, t, stack, outline}
var _recent: Dictionary = {}  # target id -> [last_time, stack]
var _clock := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://assets/fonts/PixelifySans-SemiBold.ttf"):
		font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")


func spawn_number(world_pos: Vector2, amount: int, color: Color, key: int, big := false) -> void:
	var stack := 0
	if _recent.has(key) and _clock - _recent[key][0] < STACK_WINDOW:
		stack = _recent[key][1] + 1
	_recent[key] = [_clock, stack]
	_items.append({
		"pos": world_pos, "text": str(amount), "color": color,
		"size": 80 if big else 60, "t": 0.0, "stack": stack % 5,
		"jitter": randf_range(-10.0, 10.0),
	})


func spawn_text(world_pos: Vector2, text: String, color: Color) -> void:
	# several targets often react at once: show the name once, not stacked on top of itself
	for it in _items:
		if it.text == text and it.t < 0.3:
			return
	_items.append({
		"pos": world_pos, "text": text, "color": color, "size": 36, "t": 0.0,
		"stack": -1, "jitter": 0.0,
	})


func _process(delta: float) -> void:
	_clock += delta
	for it in _items:
		it.t += delta
	_items = _items.filter(func(it): return it.t < LIFE)
	queue_redraw()


func _draw() -> void:
	var xf := get_viewport().get_canvas_transform()
	for it in _items:
		var t: float = it.t
		var screen: Vector2 = xf * it.pos
		var rise: float = -40.0 * t - (it.stack * STACK_STEP if it.stack >= 0 else 96.0)
		# pop: overshoot then settle
		var s := 1.0
		if t < 0.12:
			s = lerpf(0.4, 1.35, t / 0.12)
		elif t < 0.22:
			s = lerpf(1.35, 1.0, (t - 0.12) / 0.1)
		var alpha := 1.0 if t < LIFE * 0.75 else 1.0 - (t - LIFE * 0.75) / (LIFE * 0.25)
		var fs: int = it.size
		var w := font.get_string_size(it.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_set_transform(screen + Vector2(it.jitter, rise), 0.0, Vector2(s, s))
		var origin := Vector2(-w / 2.0, 0)
		var c: Color = it.color
		c.a = alpha
		draw_string_outline(font, origin + Vector2(0, 3), it.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Color(0.08, 0.02, 0.04, alpha))
		draw_string_outline(font, origin, it.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0.12, 0.03, 0.06, alpha))
		draw_string(font, origin, it.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
