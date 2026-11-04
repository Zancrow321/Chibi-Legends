class_name BollwerkFx
extends FederFx
## Effects of the fighting style Bollwerk (gepanzerter Supersoldat). Builds
## on FederFx (PixelLab bursts, rings, glow, manga words, speed lines) and adds:
##  - tracers and muzzle flashes (short, readable, additive)
##  - explosions with a fire ball, shock rings, shards and dark smoke
##  - the hexagon pattern of the energy shield, the energy wall, the aim
##    marker of Orbitalsturz, the chain of the Kettenhaken, the lance beam
## One-frame shapes are stamped with the physics frame like FederFx's limbs,
## so they do not flicker when the screen refreshes faster than physics.
## Colours: amber/gold (visor, muzzle), shield blue, plasma cyan, orange fire.

const AMBER := Color("ffb02e")
const GOLD := Color("ffd36a")
const SHIELD := Color("5fb8ff")
const PLASMA := Color("52f2ff")
const FIRE := Color("ff7a2a")
const OLIVE := Color("8fd16a")
const SMOKE := Color("4a4d55")
const BW_DIR := "res://assets/combat/vfx/bollwerk/%s.png"

var _frame: Array = []    # one-frame shapes (additive)
var _frame_n: Array = []  # one-frame shapes (normal blend: chain, wall frame)
var _smoke: Array = []


static func bw(id: String) -> String:
	return BW_DIR % id


func _stamp() -> int:
	return Engine.get_physics_frames()


# --- building blocks ----------------------------------------------------------

func tracer(a: Vector2, b: Vector2, col := AMBER, life := 0.09, width := 1.6) -> void:
	_fx.append({"type": "tracer", "a": a, "b": b, "col": col, "w": width, "life": life, "max": life})


## Muzzle flash: a short star of light pointing along `ang`.
func muzzle(pos: Vector2, ang: float, size := 9.0, col := AMBER) -> void:
	_fx.append({"type": "muzzle", "pos": pos, "ang": ang, "size": size, "col": col, "life": 0.06, "max": 0.06, "rot": randf_range(-0.3, 0.3)})
	glow(pos, Color(col, 0.6), size * 1.6, 0.08)


func explosion(pos: Vector2, r: float, col := FIRE) -> void:
	burst(bw("explosion"), pos + Vector2(0, -r * 0.15), r * 2.4, 0.45, randf() * TAU, randf() < 0.5)
	glow(pos, Color(col, 0.9), r * 1.3, 0.25)
	glow(pos, Color(1, 1, 0.85, 0.9), r * 0.6, 0.12)
	ring(pos, r * 1.1, col, 0.35, 5.0)
	ring(pos, r * 0.7, Color(1, 0.9, 0.6), 0.25, 3.0)
	shards(pos, -PI / 2.0, PI, 16, r * 6.0, GOLD)
	for i in 8:
		var a := randf() * TAU
		_smoke.append({"pos": pos + Vector2(cos(a), sin(a) * 0.5) * r * randf_range(0.2, 0.6),
			"vel": Vector2(cos(a) * randf_range(10, 40), randf_range(-50, -20)), "r": randf_range(r * 0.18, r * 0.32),
			"life": randf_range(0.6, 1.1), "max": 1.1})


## Electric arcs (Störladung, Prallstoß, Schildbruch): jagged short lines.
func zap(pos: Vector2, radius: float, count := 3, col := PLASMA) -> void:
	for i in count:
		var a := randf() * TAU
		var pts: Array = [pos]
		var p := pos
		for k in 4:
			p += Vector2(cos(a), sin(a)) * radius * 0.25 + Vector2(randf_range(-4, 4), randf_range(-4, 4))
			pts.append(p)
		_fx.append({"type": "zap", "pts": pts, "col": col, "life": 0.1, "max": 0.1})


func smoke(pos: Vector2, count := 3, area := 8.0) -> void:
	for i in count:
		_smoke.append({"pos": pos + Vector2(randf_range(-area, area), randf_range(-area, area) * 0.5),
			"vel": Vector2(randf_range(-12, 12), randf_range(-40, -18)), "r": randf_range(3.0, 6.0),
			"life": randf_range(0.5, 0.9), "max": 0.9})


## Shield hexagons around the figure for this frame (`k` = brightness).
func hex_shield(center: Vector2, k: float, col := SHIELD) -> void:
	_frame.append({"t": "hex", "f": _stamp(), "pos": center, "k": k, "col": col})


## The energy wall for this frame: a vertical panel at x, floor y, height h.
func wall(x: float, floor_y: float, h: float, k: float, facing: float) -> void:
	_frame.append({"t": "wall", "f": _stamp(), "x": x, "y": floor_y, "h": h, "k": k, "dir": facing})
	_frame_n.append({"t": "wallbase", "f": _stamp(), "x": x, "y": floor_y, "dir": facing})


func chain(a: Vector2, b: Vector2) -> void:
	_frame_n.append({"t": "chain", "f": _stamp(), "a": a, "b": b})


func marker(pos: Vector2, k: float, col := OLIVE) -> void:
	_frame.append({"t": "marker", "f": _stamp(), "pos": pos, "k": k, "col": col})


## Aim line (thin, pulsing) from a to b for this frame.
func aim_line(a: Vector2, b: Vector2, k: float, col := PLASMA) -> void:
	_frame.append({"t": "aim", "f": _stamp(), "a": a, "b": b, "k": k, "col": col})


func beam(a: Vector2, b: Vector2, width: float, col := PLASMA) -> void:
	_frame.append({"t": "beam", "f": _stamp(), "a": a, "b": b, "w": width, "col": col})


## Visor glint on the helmet (super cut-in moment).
func glint(pos: Vector2, size := 14.0) -> void:
	_fx.append({"type": "muzzle", "pos": pos, "ang": 0.0, "size": size, "col": GOLD, "life": 0.25, "max": 0.25, "rot": 0.0, "star": true})


# --- update / draw -------------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	for p in _smoke:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= pow(0.93, delta * 60.0)
		p.r += delta * 9.0
	_smoke = _smoke.filter(func(p): return p.life > 0.0)
	var now := _stamp()
	_frame = _keep_newest(_frame, now)
	_frame_n = _keep_newest(_frame_n, now)


func _keep_newest(list: Array, now: int) -> Array:
	var out := list.filter(func(e): return e.f >= now - 1)
	if out.is_empty():
		return out
	var newest: int = out.back().f
	return out.filter(func(e): return e.f == newest)


func _hexagon(ci: CanvasItem, c: Vector2, r: float, col: Color, w := 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 7:
		var a := PI / 6.0 + TAU * i / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_polyline(pts, col, w, true)


func _draw_add() -> void:
	super._draw_add()
	for f in _fx:
		var p: float = 1.0 - f.life / f.max
		match f.type:
			"tracer":
				var a := 1.0 - p
				var head: Vector2 = f.a.lerp(f.b, minf(1.0, 0.35 + p * 1.6))
				var tail: Vector2 = f.a.lerp(f.b, clampf(p * 1.6 - 0.2, 0.0, 1.0))
				_add.draw_line(tail, head, Color(f.col, 0.35 * a), f.w * 3.0, true)
				_add.draw_line(tail, head, Color(1, 0.95, 0.8, a), f.w, true)
				_glow(_add, head, 4.0, Color(f.col, 0.6 * a))
			"muzzle":
				var s: float = f.size * (1.0 - p * 0.5)
				var a2 := 1.0 - p
				var d := Vector2(cos(f.ang), sin(f.ang))
				var n := d.orthogonal()
				var c: Vector2 = f.pos
				if f.get("star", false):
					for k in 4:
						var dir := Vector2.RIGHT.rotated(k * PI / 4.0 + p)
						_add.draw_line(c - dir * s, c + dir * s, Color(f.col, a2), 1.6 if k % 2 == 0 else 1.0, true)
					_glow(_add, c, s * 0.8, Color(1, 1, 1, 0.6 * a2))
					continue
				var poly := PackedVector2Array([c - n * s * 0.35, c + d * s * 1.6, c + n * s * 0.35, c - d * s * 0.2])
				_add.draw_colored_polygon(poly, Color(f.col, 0.9 * a2))
				var poly2 := PackedVector2Array([c + (d.rotated(0.9 + f.rot)) * s * 0.9, c + n * 1.5, c - n * 1.5])
				_add.draw_colored_polygon(poly2, Color(f.col, 0.6 * a2))
				var poly3 := PackedVector2Array([c + (d.rotated(-0.9 + f.rot)) * s * 0.9, c - n * 1.5, c + n * 1.5])
				_add.draw_colored_polygon(poly3, Color(f.col, 0.6 * a2))
				_glow(_add, c + d * 3.0, s * 0.7, Color(1, 1, 0.9, 0.8 * a2))
			"zap":
				var pts := PackedVector2Array(f.pts)
				_add.draw_polyline(pts, Color(f.col, 0.4 * (1.0 - p)), 3.0, true)
				_add.draw_polyline(pts, Color(1, 1, 1, 1.0 - p), 1.0, true)
	var t := Time.get_ticks_msec() * 0.001
	for e in _frame:
		match e.t:
			"hex":
				var k: float = e.k
				var c: Vector2 = e.pos
				_glow(_add, c, 34.0, Color(e.col, 0.12 * k))
				# a loose net of small hexagons over the body outline
				for i in 14:
					var a := TAU * i / 14.0 + t * 0.6
					var rr := 20.0 + 3.0 * sin(t * 5.0 + i)
					var hc := c + Vector2(cos(a) * rr * 0.75, sin(a) * rr)
					var fl := 0.5 + 0.5 * sin(t * 13.0 + i * 1.7)
					_hexagon(_add, hc, 3.2, Color(e.col, (0.25 + 0.6 * fl) * k), 1.0)
				_add.draw_arc(c, 23.0, 0.0, TAU, 40, Color(e.col, 0.35 * k), 1.4, true)
			"wall":
				var k2: float = e.k
				var top: float = e.y - e.h
				var x: float = e.x
				var flick := 0.85 + 0.15 * sin(t * 30.0)
				var wtex := tex(bw("schildwand"))
				if wtex != null:
					_add.draw_texture_rect(wtex, Rect2(x - 9.0, top - 2.0, 18.0, e.h + 2.0), false, Color(1, 1, 1, 0.55 * k2 * flick))
				_add.draw_rect(Rect2(x - 5.0, top, 10.0, e.h), Color(SHIELD, 0.18 * k2 * flick))
				_add.draw_line(Vector2(x, top), Vector2(x, e.y), Color(SHIELD, 0.8 * k2), 1.5, true)
				var rows := int(e.h / 6.0)
				for i in rows:
					var yy: float = top + 3.0 + i * 6.0
					var off := 3.4 if i % 2 == 0 else -3.4
					var fl2 := 0.5 + 0.5 * sin(t * 9.0 + i * 0.8)
					_hexagon(_add, Vector2(x + off, yy), 3.0, Color(SHIELD, (0.25 + 0.5 * fl2) * k2), 1.0)
				_glow(_add, Vector2(x, top + e.h * 0.5), e.h * 0.6, Color(SHIELD, 0.12 * k2))
				_glow(_add, Vector2(x, top), 6.0, Color(1, 1, 1, 0.5 * k2))
			"marker":
				var k3: float = e.k
				var c3: Vector2 = e.pos
				var r3 := 14.0 - 6.0 * k3
				_add.draw_arc(c3, r3, 0.0, TAU, 32, Color(e.col, 0.8), 1.4, true)
				for i in 4:
					var d3 := Vector2.RIGHT.rotated(i * PI / 2.0 + t * 2.0)
					_add.draw_line(c3 + d3 * (r3 + 2.0), c3 + d3 * (r3 + 7.0), Color(e.col, 0.9), 1.4, true)
				_add.draw_line(c3 + Vector2(-r3 * 1.6, 0), c3 + Vector2(r3 * 1.6, 0), Color(e.col, 0.35), 1.0, true)
				_glow(_add, c3, 6.0, Color(e.col, 0.4 + 0.4 * k3))
			"aim":
				var k4: float = e.k
				var pulse := 0.6 + 0.4 * sin(t * (12.0 + 30.0 * k4))
				_add.draw_line(e.a, e.b, Color(e.col, (0.25 + 0.6 * k4) * pulse), 1.0 + 2.0 * k4, true)
				_glow(_add, e.b, 5.0 + 6.0 * k4, Color(e.col, 0.5 * pulse))
			"beam":
				var w: float = e.w
				var fl3 := 0.9 + 0.1 * sin(t * 50.0)
				_add.draw_line(e.a, e.b, Color(e.col, 0.25), w * 2.6 * fl3, true)
				_add.draw_line(e.a, e.b, Color(e.col, 0.75), w * fl3, true)
				_add.draw_line(e.a, e.b, Color(1, 1, 1, 0.95), w * 0.4, true)
				_glow(_add, e.a, w * 2.2, Color(e.col, 0.7))
				for i in 6:
					var q: Vector2 = e.a.lerp(e.b, fmod(t * 3.0 + i / 6.0, 1.0))
					_glow(_add, q, w * 1.2, Color(1, 1, 1, 0.25))


func _draw_limbs() -> void:
	for p in _smoke:
		var k: float = 1.0 - p.life / p.max
		_limb_layer.draw_circle(p.pos, p.r, Color(SMOKE, 0.6 * (1.0 - k)))
		_limb_layer.draw_circle(p.pos + Vector2(-p.r * 0.3, -p.r * 0.3), p.r * 0.5, Color(0.55, 0.57, 0.62, 0.3 * (1.0 - k)))
	super._draw_limbs()
	for e in _frame_n:
		match e.t:
			"chain":
				var a: Vector2 = e.a
				var b: Vector2 = e.b
				_limb_layer.draw_line(a, b, INK, 3.4, true)
				_limb_layer.draw_line(a, b, Color("8e98a6"), 1.6, true)
				var n := int(a.distance_to(b) / 5.0)
				for i in n:
					var q := a.lerp(b, (i + 0.5) / maxf(1.0, n))
					_limb_layer.draw_circle(q, 1.2, Color("c9d1dc") if i % 2 == 0 else Color("5a616c"))
				# claw
				var d := (b - a).normalized()
				var nn := d.orthogonal()
				_limb_layer.draw_colored_polygon(PackedVector2Array([b + d * 4.0, b + nn * 3.5 - d * 1.5, b - nn * 3.5 - d * 1.5]), Color("3a3f48"))
				_limb_layer.draw_circle(b, 1.5, Color("ffb02e"))
			"wallbase":
				var x: float = e.x
				var y: float = e.y
				_limb_layer.draw_rect(Rect2(x - 6, y - 4, 12, 4), INK)
				_limb_layer.draw_rect(Rect2(x - 5, y - 3, 10, 2), Color("3a3f48"))
				_limb_layer.draw_rect(Rect2(x - 1, y - 3, 2, 1), Color("ffb02e"))
