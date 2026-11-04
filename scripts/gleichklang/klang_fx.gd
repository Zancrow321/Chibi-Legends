class_name KlangFx
extends Node2D
## Effects of the fighting style Gleichklang (Sense Nachhall): sharp sickle
## arcs that sweep and fade, pulsing sound rings, drifting soul motes, small
## note marks, the beat ring around the figure, the Klangloch glow on the
## scythe and Nachhall's speech bubbles. Smooth and additive like GlutFx (not
## pixel art); colours pale blue, white and violet, red only as an accent.
## Runs while the tree is paused (hit-stop, super pause).

const BLUE := Color("8fd3ff")
const PALE := Color("cfeaff")
const WHITE := Color("f4fbff")
const VIOLET := Color("a884f3")
const RED := Color("e83b3b")
const INK := Color("16121f")

var room: Node  # TrainingRoom
var font: Font

var _add: Node2D
var _top: Node2D
var _fx: Array = []
var _once: Array = []      # one-frame shapes (beat ring, Klangloch glow)
var _speech: Dictionary = {}
var _speech_pos := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = CombatFx.FOCUS_Z + 3
	font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")
	_add = Node2D.new()
	_add.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_add.material = m
	_add.draw.connect(_draw_add)
	add_child(_add)
	_top = Node2D.new()
	_top.z_index = 3
	var tm := CanvasItemMaterial.new()
	tm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_top.material = tm
	_top.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_top.draw.connect(_draw_top)
	add_child(_top)


# --- building blocks ----------------------------------------------------------

## Sickle arc: a crescent band around `center` from angle a0 to a1 that
## sweeps in during the first third of its life, then fades. `width` is the
## thickness in the middle; both ends taper to a point.
func arc(center: Vector2, radius: float, a0: float, a1: float, width: float, col := BLUE, life := 0.26) -> void:
	_fx.append({"type": "arc", "pos": center, "r": radius, "a0": a0, "a1": a1, "w": width, "col": col, "life": life, "max": life})


## Contour line that stays for a moment (the white outline of a giant cut).
func contour(center: Vector2, radius: float, a0: float, a1: float, life := 0.6) -> void:
	_fx.append({"type": "contour", "pos": center, "r": radius, "a0": a0, "a1": a1, "life": life, "max": life})


func ring(pos: Vector2, radius: float, col := BLUE, life := 0.35, width := 3.0) -> void:
	_fx.append({"type": "ring", "pos": pos, "r": radius, "col": col, "w": width, "life": life, "max": life})


## Ring that shrinks onto its centre (inhale / resonance building up).
func ring_in(pos: Vector2, radius: float, col := BLUE, life := 0.4, width := 2.0) -> void:
	_fx.append({"type": "ring_in", "pos": pos, "r": radius, "col": col, "w": width, "life": life, "max": life})


func glow(pos: Vector2, col: Color, size: float, life: float, vel := Vector2.ZERO) -> void:
	_fx.append({"type": "glow", "pos": pos, "col": col, "size": size, "life": life, "max": life, "vel": vel})


## Soul motes: small diamonds that drift up and twinkle.
func motes(pos: Vector2, count: int, area := 10.0, col := PALE, life := 0.7) -> void:
	for i in count:
		_fx.append({"type": "mote", "pos": pos + Vector2(randf_range(-area, area), randf_range(-area, area) * 0.6),
			"vel": Vector2(randf_range(-20, 20), randf_range(-50, -15)), "col": col, "size": randf_range(1.2, 2.4),
			"life": life * randf_range(0.6, 1.0), "max": life, "phase": randf() * TAU})


## Shards flying out of a hit (sharp, straight, no gravity).
func shards(pos: Vector2, angle: float, spread: float, count: int, speed: float, col := WHITE) -> void:
	for i in count:
		var a := angle + randf_range(-spread, spread)
		_fx.append({"type": "shard", "pos": pos, "vel": Vector2(cos(a), sin(a)) * speed * randf_range(0.5, 1.1),
			"col": col, "life": randf_range(0.15, 0.3), "max": 0.3})


## Small note mark floating up (sparse musical impulse).
func note(pos: Vector2, col := PALE) -> void:
	_fx.append({"type": "note", "pos": pos, "vel": Vector2(randf_range(-12, 12), -36), "col": col, "life": 0.8, "max": 0.8, "two": randf() < 0.4})


## Manga sound word, pale with an ink outline.
func word(pos: Vector2, text: String, col := WHITE, size := 22, tilt := -0.1) -> void:
	for w in _fx:
		if w.type == "word" and w.max - w.life < 0.35 and absf(w.pos.x - pos.x) < 60.0 and absf(w.pos.y - pos.y) < 14.0:
			pos.y = w.pos.y - 14.0
	_fx.append({"type": "word", "pos": pos, "text": text, "col": col, "size": size, "life": 0.7, "max": 0.7, "tilt": tilt + randf_range(-0.05, 0.05)})


## Nachhall speaks: a small bubble next to the scythe head.
func speech(text: String, life := 1.1) -> void:
	_speech = {"text": text, "life": life, "max": life}


## Where the bubble points to (the Klangloch), updated every frame.
func speech_anchor(pos: Vector2) -> void:
	_speech_pos = pos


## The beat ring around the figure for this frame: `k` = 0 right after a
## beat, 1 right at the next. `grey` while the beat is lost after a hit.
func beat_ring(pos: Vector2, k: float, grey: bool, wide: bool) -> void:
	_once.append({"type": "beat", "pos": pos, "k": k, "grey": grey, "wide": wide})


## Klangloch glow on the scythe for this frame.
func klangloch(pos: Vector2, strength: float, col := BLUE) -> void:
	_once.append({"type": "hole", "pos": pos, "s": strength, "col": col})


# --- update ---------------------------------------------------------------------

func _process(delta: float) -> void:
	for f in _fx:
		f.life -= delta
		if f.has("vel"):
			f.pos += f.vel * delta
			if f.type == "shard":
				f.vel *= pow(0.9, delta * 60.0)
	_fx = _fx.filter(func(f): return f.life > 0.0)
	if not _speech.is_empty():
		_speech.life -= delta
		if _speech.life <= 0.0:
			_speech = {}
	_add.queue_redraw()
	_top.queue_redraw()


# --- draw -------------------------------------------------------------------------

func _glow(ci: CanvasItem, pos: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect(GlutFx.glow_texture(), Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


func _crescent(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, w: float, col: Color) -> void:
	var n := maxi(6, int(absf(a1 - a0) * r / 5.0))
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in n + 1:
		var k := float(i) / n
		var a := lerpf(a0, a1, k)
		var th := w * sin(k * PI) * (0.35 + 0.65 * k)  # thicker towards the leading edge
		var d := Vector2(cos(a), sin(a))
		outer.append(c + d * (r + th * 0.5))
		inner.append(c + d * (r - th * 0.5))
	inner.reverse()
	var poly := outer + inner
	if poly.size() >= 3:
		ci.draw_colored_polygon(poly, col)


func _draw_add() -> void:
	for f in _once:
		match f.type:
			"beat":
				var k: float = f.k
				var col: Color = Color(0.55, 0.55, 0.6) if f.grey else BLUE
				var r := lerpf(30.0, 15.0, k) * (1.15 if f.wide else 1.0)
				var a := 0.12 + 0.35 * k * k
				_add.draw_arc(f.pos, r, 0.0, TAU, 40, Color(col, a), 1.2 + k, true)
				if k > 0.92 and not f.grey:
					_glow(_add, f.pos, 22.0, Color(BLUE, 0.25))
			"hole":
				var s: float = f.s
				_glow(_add, f.pos, 4.0 + s * 8.0, Color(f.col, 0.35 + 0.5 * s))
				_glow(_add, f.pos, 1.5 + s * 2.5, Color(WHITE, 0.6 + 0.4 * s))
	for f in _fx:
		var p: float = 1.0 - f.life / f.max
		match f.type:
			"arc":
				var grow := minf(1.0, p * 3.0)
				var fade := 1.0 if p < 0.4 else 1.0 - (p - 0.4) / 0.6
				var a_end: float = lerpf(f.a0, f.a1, grow)
				var a_start: float = lerpf(f.a0, f.a1, maxf(0.0, p - 0.25) * 1.2)
				if absf(a_end - a_start) < 0.02:
					continue
				_crescent(_add, f.pos, f.r, a_start, a_end, f.w * 1.8, Color(f.col, 0.25 * fade))
				_crescent(_add, f.pos, f.r, a_start, a_end, f.w, Color(f.col, 0.75 * fade))
				_crescent(_add, f.pos, f.r + f.w * 0.15, a_start, a_end, f.w * 0.35, Color(WHITE, 0.9 * fade))
			"contour":
				var a2 := 1.0 if p < 0.6 else 1.0 - (p - 0.6) / 0.4
				_add.draw_arc(f.pos, f.r, f.a0, f.a1, 64, Color(WHITE, a2), 3.0, true)
				_add.draw_arc(f.pos, f.r, f.a0, f.a1, 64, Color(PALE, a2 * 0.4), 9.0, true)
			"ring":
				var e := 1.0 - pow(1.0 - p, 3.0)
				var rr: float = f.r * (0.2 + 0.8 * e)
				_add.draw_arc(f.pos, rr, 0.0, TAU, 48, Color(f.col, 1.0 - p), f.w * (1.0 - p) + 0.6, true)
				_add.draw_arc(f.pos, rr * 0.94, 0.0, TAU, 48, Color(WHITE, (1.0 - p) * 0.5), 0.8, true)
			"ring_in":
				var rr2: float = f.r * (1.0 - p * 0.85)
				_add.draw_arc(f.pos, rr2, 0.0, TAU, 48, Color(f.col, 0.2 + 0.7 * p), f.w, true)
			"glow":
				_glow(_add, f.pos, f.size * (1.0 - p * 0.4), Color(f.col, f.col.a * (1.0 - p * p)))
			"mote":
				var tw := 0.5 + 0.5 * sin(f.phase + p * 18.0)
				var s: float = f.size * (1.0 - p * 0.5)
				var c: Vector2 = f.pos
				_add.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 1.6), c + Vector2(s, 0), c + Vector2(0, s * 1.6), c + Vector2(-s, 0)]), Color(f.col, (1.0 - p) * (0.5 + 0.5 * tw)))
				_glow(_add, c, s * 3.0, Color(f.col, 0.25 * (1.0 - p)))
			"shard":
				var tail: Vector2 = f.vel * 0.035
				_add.draw_line(f.pos, f.pos - tail, Color(f.col, 1.0 - p), 1.4, true)
				_add.draw_line(f.pos, f.pos - tail * 0.4, Color(WHITE, 1.0 - p), 0.8, true)


func _draw_top() -> void:
	for f in _fx:
		var p: float = 1.0 - f.life / f.max
		match f.type:
			"note":
				var a := 1.0 - p
				var c: Vector2 = f.pos
				var col := Color(f.col, a)
				_top.draw_circle(c, 1.8, col)
				_top.draw_line(c + Vector2(1.6, 0), c + Vector2(1.6, -7), col, 1.0)
				if f.two:
					_top.draw_circle(c + Vector2(5, 1), 1.8, col)
					_top.draw_line(c + Vector2(6.6, 1), c + Vector2(6.6, -6), col, 1.0)
					_top.draw_line(c + Vector2(1.6, -7), c + Vector2(6.6, -6), col, 1.4)
				else:
					_top.draw_line(c + Vector2(1.6, -7), c + Vector2(4, -4.5), col, 1.0)
			"word":
				var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - p * 6.0)
				var a2 := 1.0 if p < 0.65 else 1.0 - (p - 0.65) / 0.35
				var fs: int = f.size
				var tw := font.get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				_top.draw_set_transform(f.pos + Vector2(0, -p * 10.0), f.tilt, Vector2(pop, pop) * 0.5)
				var at := Vector2(-tw / 2.0, fs * 0.35)
				_top.draw_string_outline(font, at, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(INK, a2))
				_top.draw_string(font, at, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(f.col, a2))
				_top.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_once.clear()
	if not _speech.is_empty():
		_draw_speech()


func _draw_speech() -> void:
	var p: float = 1.0 - _speech.life / _speech.max
	var a := minf(1.0, p * 8.0) * (1.0 if p < 0.8 else 1.0 - (p - 0.8) / 0.2)
	var fs := 16
	var txt: String = _speech.text
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5
	var anchor := _speech_pos
	var box := Rect2(anchor + Vector2(-tw / 2.0 - 5.0, -27.0), Vector2(tw + 10.0, 13.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(WHITE, 0.92 * a)
	sb.border_color = Color(INK, a)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	_top.draw_colored_polygon(PackedVector2Array([box.position + Vector2(box.size.x * 0.5 - 3, box.size.y - 0.5), box.position + Vector2(box.size.x * 0.5 + 3, box.size.y - 0.5), anchor + Vector2(0, -6)]), Color(WHITE, 0.92 * a))
	_top.draw_style_box(sb, box)
	_top.draw_set_transform(Vector2(box.position.x + 5.0, box.position.y + 10.0), 0.0, Vector2(0.5, 0.5))
	_top.draw_string(font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(INK, a))
	_top.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
