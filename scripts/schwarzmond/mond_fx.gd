class_name MondFx
extends Node2D
## Effects of the fighting style Schwarzmond, drawn in code (soft, M.U.G.E.N
## like, no pixel art): black ink crescents with a cold white/cyan rim,
## sweeping blade arcs, fast streaks, the Schattenlarve over the face and the
## dark blade of the Neumond form. Two layers: ink (normal blend, black can't
## be additive) and light (additive, unshaded). Fire-free on purpose; the
## shared GlutFx still supplies words, glow blobs and lights.

const INK := Color("0b0a12")
const CYAN := Color("6fe3ff")
const WHITE := Color("f4f8ff")
const RED := Color("b0122a")
const EMBER := Color("ff3b4a")

var room: Node  # TrainingRoom
var caster: Node  # MondCaster (Larve, Neumond)
var _ink: Node2D
var _add: Node2D
var _fx: Array = []


func _ready() -> void:
	z_index = 4
	_ink = Node2D.new()
	_ink.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var im := CanvasItemMaterial.new()
	im.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_ink.material = im
	_ink.draw.connect(_draw_ink)
	add_child(_ink)
	_add = Node2D.new()
	_add.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_add.material = m
	_add.draw.connect(_draw_add)
	add_child(_add)


## Points of a crescent around `c`, bulging towards `dir` (unit vector).
## `span` = half angle of the outer arc, `fat` 0.4..1.5 (bigger = thicker in the middle).
static func crescent(c: Vector2, dir: Vector2, r: float, span := 1.2, fat := 1.0, steps := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var base := dir.angle()
	for i in steps + 1:
		var a := base + lerpf(-span, span, float(i) / steps)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	var d := r * fat
	var c2 := c - dir * d
	var ex := r * cos(span) + d
	var ey := r * sin(span)
	var r2 := sqrt(ex * ex + ey * ey)
	var phi := atan2(ey, ex)
	for i in range(1, steps):  # the tips are shared with the outer arc
		var a2 := base + lerpf(phi, -phi, float(i) / steps)
		pts.append(c2 + Vector2(cos(a2), sin(a2)) * r2)
	return pts


## Outer edge of a crescent only (for the glowing rim).
static func rim(c: Vector2, dir: Vector2, r: float, span := 1.2, steps := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var base := dir.angle()
	for i in steps + 1:
		var a := base + lerpf(-span, span, float(i) / steps)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## Draws a full ink crescent with rim onto two canvases (used by waves and
## the Meisterzug too). `rim_col` decides the mood: cyan = controlled,
## red = entfesselt.
static func draw_crescent(ink: CanvasItem, add: CanvasItem, c: Vector2, dir: Vector2, r: float, alpha: float,
		rim_col := CYAN, span := 1.2, fat := 1.0, squash := 1.0) -> void:
	var pts := crescent(c, dir, r, span, fat)
	if squash != 1.0:
		var nrm := Vector2(-dir.y, dir.x)
		for i in pts.size():
			var v := pts[i] - c
			var along := v.dot(dir)
			var side := v.dot(nrm)
			pts[i] = c + dir * along * squash + nrm * side
	if ink != null:
		ink.draw_colored_polygon(pts, Color(INK, 0.92 * alpha))
	if add != null:
		var outer := PackedVector2Array()
		for i in 19:
			outer.append(pts[i])
		var tex := GlutFx.glow_texture()
		for i in range(0, 19, 3):
			var p := outer[i] + dir * r * 0.12  # outside the ink, so the black stays black
			var s := r * 0.14
			add.draw_texture_rect(tex, Rect2(p - Vector2(s, s), Vector2(s, s) * 2.0), false, Color(rim_col, 0.22 * alpha))
		add.draw_polyline(outer, Color(rim_col, 0.85 * alpha), maxf(1.2, r * 0.07), true)
		add.draw_polyline(outer, Color(WHITE, alpha), maxf(0.8, r * 0.035), true)


# --- spawners ----------------------------------------------------------------------

func _push(d: Dictionary) -> void:
	d["max"] = d.life
	_fx.append(d)


## A crescent that flashes and fades in place (impacts, slashes).
func sichel(pos: Vector2, dir: Vector2, r: float, life := 0.25, rim_col := CYAN, grow := 1.25) -> void:
	_push({"type": "sichel", "pos": pos, "dir": dir.normalized(), "r": r, "life": life, "col": rim_col, "grow": grow})


## A sweeping blade arc (from angle a0 to a1, in world angles).
func slash(pos: Vector2, r: float, a0: float, a1: float, life := 0.18, col := CYAN, width := 7.0) -> void:
	_push({"type": "slash", "pos": pos, "r": r, "a0": a0, "a1": a1, "life": life, "col": col, "w": width})


## Fast cold streaks (no gravity).
func streaks(pos: Vector2, angle: float, spread: float, count: int, speed: float, life := 0.3, col := CYAN) -> void:
	for i in count:
		var a := angle + randf_range(-spread, spread)
		_push({"type": "streak", "pos": pos, "vel": Vector2(cos(a), sin(a)) * speed * randf_range(0.5, 1.1),
			"life": randf_range(life * 0.5, life), "col": col})


## Ink burst: black flakes that drift and dissolve.
func ink(pos: Vector2, count: int, speed := 90.0, life := 0.6) -> void:
	for i in count:
		var a := randf() * TAU
		_push({"type": "flake", "pos": pos, "vel": Vector2(cos(a), sin(a)) * speed * randf_range(0.3, 1.0) + Vector2(0, -20),
			"life": randf_range(life * 0.5, life), "size": randf_range(2.0, 4.5), "rot": randf() * TAU})


## Expanding ring of ink with a cold rim (Druckwelle).
func shock(pos: Vector2, radius: float, life := 0.3, col := CYAN) -> void:
	_push({"type": "shock", "pos": pos, "r": radius, "life": life, "col": col})


# --- update & draw -------------------------------------------------------------------

func _process(delta: float) -> void:
	if room != null and room.fx.is_frozen():
		_ink.queue_redraw()
		_add.queue_redraw()
		return
	for f in _fx:
		f.life -= delta
		if f.has("vel"):
			f.pos += f.vel * delta
			f.vel *= 0.94 if f.type == "flake" else 0.97
	_fx = _fx.filter(func(f): return f.life > 0.0)
	_ink.queue_redraw()
	_add.queue_redraw()


func _draw_ink() -> void:
	for f in _fx:
		var p: float = 1.0 - f.life / f.max
		match f.type:
			"sichel":
				var pts := crescent(f.pos, f.dir, f.r * lerpf(1.0, f.grow, p))
				_ink.draw_colored_polygon(pts, Color(INK, 0.9 * (1.0 - p)))
			"slash":
				var a1: float = lerpf(f.a0, f.a1, minf(1.0, p * 3.0))
				_ink.draw_arc(f.pos, f.r, f.a0, a1, 18, Color(INK, 0.85 * (1.0 - p)), f.w * (1.0 - p * 0.5), true)
			"flake":
				var s: float = f.size * (1.0 - p)
				if s < 0.6:
					continue
				var d := Vector2(cos(f.rot), sin(f.rot)) * s
				_ink.draw_colored_polygon(PackedVector2Array([f.pos - d, f.pos + Vector2(-d.y, d.x) * 0.4, f.pos + d, f.pos - Vector2(-d.y, d.x) * 0.4]), Color(INK, 0.85 * (1.0 - p)))
			"shock":
				var e := 1.0 - pow(1.0 - p, 3.0)
				_ink.draw_arc(f.pos, f.r * (0.2 + 0.8 * e), PI, TAU, 24, Color(INK, 0.8 * (1.0 - p)), 6.0 * (1.0 - p) + 1.0, true)
	if caster != null and is_instance_valid(caster):
		caster.draw_ink(_ink)


func _draw_add() -> void:
	var tex := GlutFx.glow_texture()
	for f in _fx:
		var p: float = 1.0 - f.life / f.max
		match f.type:
			"sichel":
				var r: float = f.r * lerpf(1.0, f.grow, p)
				var outer := rim(f.pos, f.dir, r)
				_add.draw_polyline(outer, Color(f.col, 0.9 * (1.0 - p)), maxf(1.5, r * 0.1), true)
				_add.draw_polyline(outer, Color(WHITE, 1.0 - p), maxf(0.8, r * 0.04), true)
			"slash":
				var a1: float = lerpf(f.a0, f.a1, minf(1.0, p * 3.0))
				_add.draw_arc(f.pos, f.r + f.w * 0.5, f.a0, a1, 18, Color(f.col, 0.8 * (1.0 - p)), 2.0, true)
				_add.draw_arc(f.pos, f.r + f.w * 0.5, f.a0 + (a1 - f.a0) * 0.4, a1, 12, Color(WHITE, 1.0 - p), 1.0, true)
			"streak":
				var tail: Vector2 = f.vel * 0.03
				_add.draw_line(f.pos, f.pos - tail, Color(f.col, 1.0 - p), 1.4, true)
				_add.draw_line(f.pos, f.pos - tail * 0.4, Color(WHITE, 1.0 - p), 0.7, true)
			"shock":
				var e := 1.0 - pow(1.0 - p, 3.0)
				var rr: float = f.r * (0.2 + 0.8 * e)
				_add.draw_arc(f.pos, rr + 3.0, PI, TAU, 24, Color(f.col, 0.9 * (1.0 - p)), 1.5, true)
				var s := rr * 0.3
				_add.draw_texture_rect(tex, Rect2(f.pos - Vector2(s, s), Vector2(s, s) * 2.0), false, Color(f.col, 0.3 * (1.0 - p)))
	if caster != null and is_instance_valid(caster):
		caster.draw_add(_add)
