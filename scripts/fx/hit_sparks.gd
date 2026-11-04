class_name HitSparks
extends Node2D
## Additive, glowing hit sparks in the style of classic 2D fighting games:
## star bursts, shock rings, speed streaks and per-element shapes
## (flames, ice shards, zaps, wind swirls). Everything is drawn in code.
##
## Pixel-art override: if a sprite strip exists at res://assets/vfx/<id>.png
## (square frames side by side), it is played on top of the coded effect.
## That way hand-drawn frames can replace or enrich single effects later.
## Runs while the tree is paused, so sparks keep playing during hit-stop.

const PHYS_COLOR := Color("bfe9ff")
const SPRITE_DIR := "res://assets/vfx/"
const SPRITE_FPS := 30.0

static var _glow: Texture2D
static var _sprite_cache: Dictionary = {}

var _fx: Array = []  # {type, pos, vel, life, max, col, size, rot, spin, ...}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	if _glow == null:
		_glow = make_glow()


## Soft radial glow (white center, transparent edge), shared by all fx.
static func make_glow() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 32
	t.height = 32
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


static func glow_texture() -> Texture2D:
	if _glow == null:
		_glow = make_glow()
	return _glow


# --- spawning --------------------------------------------------------------

func _add(d: Dictionary) -> void:
	d.merge({"vel": Vector2.ZERO, "rot": 0.0, "spin": 0.0, "size": 4.0, "grav": 0.0, "drag": 1.0}, false)
	d["max"] = d.life
	_fx.append(d)


## Main entry: a hit spark at `pos`, element shapes, scaled by `s`,
## `dir` = horizontal direction of the hit (+1 / -1).
func hit(pos: Vector2, element: String, s: float, dir: float, heavy := false) -> void:
	var col: Color = PHYS_COLOR if element == "" else GameData.ELEMENTS[element].color
	_add({"type": "core", "pos": pos, "life": 0.16, "col": Color.WHITE, "size": 14.0 * s})
	match element:
		"feuer":
			_star(pos, Color("ffb347"), 5, 22.0 * s, dir)
			_add({"type": "ring", "pos": pos, "life": 0.22, "col": Color("ff6a2a"), "size": 20.0 * s})
			for i in int(7 * s) + 2:
				_add({"type": "flame", "pos": pos + Vector2(randf_range(-8, 8), randf_range(-6, 6)) * s,
					"vel": Vector2(randf_range(-40, 40) + dir * 40.0, randf_range(-110, -40)) * s,
					"life": randf_range(0.25, 0.45), "col": Color("ffd27a"), "size": randf_range(5, 9) * s, "drag": 0.92})
			_embers(pos, Color("ff9a3d"), int(6 * s), dir)
		"frost":
			_star(pos, Color("d8f6ff"), 6, 20.0 * s, dir, 0.6)
			_add({"type": "ring", "pos": pos, "life": 0.25, "col": col, "size": 22.0 * s})
			for i in int(6 * s) + 2:
				var ang := randf() * TAU
				_add({"type": "shard", "pos": pos, "vel": Vector2(cos(ang) * 160.0 + dir * 60.0, sin(ang) * 120.0 - 40.0) * s,
					"life": randf_range(0.3, 0.5), "col": Color("bff0ff"), "size": randf_range(3, 6) * s,
					"rot": ang, "spin": randf_range(-14, 14), "grav": 320.0, "drag": 0.95})
		"blitz":
			_star(pos, Color("fff6a0"), 4, 26.0 * s, dir)
			for i in int(4 * s) + 2:
				_add({"type": "zap", "pos": pos, "life": randf_range(0.12, 0.22), "col": col,
					"size": randf_range(20, 36) * s, "rot": randf() * TAU})
			_embers(pos, Color("fff3a0"), int(5 * s), dir)
		"wind":
			for i in 3:
				_add({"type": "swirl", "pos": pos, "life": 0.3, "col": Color("b8ffd0"),
					"size": (14.0 + i * 7.0) * s, "rot": randf() * TAU, "spin": 9.0 * dir})
			_streaks(pos, col, int(6 * s) + 2, dir, 260.0 * s)
		_:
			_star(pos, col, 6 if heavy else 4, (24.0 if heavy else 16.0) * s, dir)
			_add({"type": "ring", "pos": pos, "life": 0.18, "col": col, "size": 16.0 * s})
			if heavy:
				_add({"type": "slash", "pos": pos, "life": 0.16, "col": col, "size": 22.0 * s, "rot": -0.6 * dir})
			_streaks(pos, col, int(5 * s) + 2, dir, 220.0 * s)
	if heavy:
		focus_lines(pos, col, 70.0 * s)
	_sprite(_sprite_id(element, heavy), pos, s, dir)


## Manga focus lines: thin wedges rushing in towards the hit point.
func focus_lines(pos: Vector2, col: Color, radius: float, life := 0.2) -> void:
	var rays: Array = []
	for i in 22:
		rays.append([randf() * TAU, randf_range(0.55, 1.0), randf_range(1.0, 2.6)])
	_add({"type": "focus", "pos": pos, "life": life, "col": col.lerp(Color.WHITE, 0.5), "size": radius, "rays": rays})


## Big reaction blast: double ring, long star, many streaks.
func blast(pos: Vector2, col: Color, radius: float, s: float) -> void:
	_add({"type": "core", "pos": pos, "life": 0.24, "col": Color.WHITE, "size": 26.0 * s})
	_add({"type": "core", "pos": pos, "life": 0.35, "col": col, "size": 40.0 * s})
	_star(pos, col.lightened(0.3), 8, 40.0 * s, 0.0)
	_add({"type": "ring", "pos": pos, "life": 0.32, "col": col, "size": maxf(radius, 30.0)})
	_add({"type": "ring", "pos": pos, "life": 0.45, "col": Color.WHITE, "size": maxf(radius, 30.0) * 0.7})
	_streaks(pos, col, int(12 * s), 0.0, 320.0 * s)
	_embers(pos, col, int(10 * s), 0.0)
	_sprite("blast", pos, s, 1.0)


## Public building blocks (used by the super move).
func glow(pos: Vector2, col: Color, size: float, life: float, vel := Vector2.ZERO) -> void:
	_add({"type": "core", "pos": pos, "life": life, "col": col, "size": size, "vel": vel})


func flame(pos: Vector2, col: Color, size: float, vel: Vector2, life := 0.4) -> void:
	_add({"type": "flame", "pos": pos, "vel": vel, "life": life, "col": col, "size": size, "drag": 0.95})


func streak(pos: Vector2, col: Color, vel: Vector2, life := 0.25) -> void:
	_add({"type": "streak", "pos": pos, "vel": vel, "life": life, "col": col, "size": 2.0, "drag": 0.9})


func ring(pos: Vector2, col: Color, radius: float, life := 0.3) -> void:
	_add({"type": "ring", "pos": pos, "life": life, "col": col, "size": radius})


func star(pos: Vector2, col: Color, spikes: int, length: float) -> void:
	_star(pos, col, spikes, length, 0.0)


func _star(pos: Vector2, col: Color, spikes: int, length: float, dir: float, width := 1.0) -> void:
	var base := randf() * TAU
	var rays: Array = []
	for i in spikes:
		var ang := base + TAU * i / spikes + randf_range(-0.25, 0.25)
		var l := length * randf_range(0.6, 1.25)
		if dir != 0.0 and signf(cos(ang)) == signf(dir):
			l *= 1.35  # sparks fly further in the hit direction
		rays.append([ang, l])
	_add({"type": "star", "pos": pos, "life": 0.14, "col": col, "size": 4.0 * width, "rays": rays})


func _streaks(pos: Vector2, col: Color, n: int, dir: float, speed: float) -> void:
	for i in n:
		var ang := randf() * TAU
		if dir != 0.0:
			ang = (0.0 if dir > 0.0 else PI) + randf_range(-1.1, 1.1)
		var v := Vector2(cos(ang), sin(ang)) * speed * randf_range(0.6, 1.2)
		streak(pos, col, v, randf_range(0.15, 0.28))


func _embers(pos: Vector2, col: Color, n: int, dir: float) -> void:
	for i in n:
		var ang := randf() * TAU
		var v := Vector2(cos(ang) * 130.0 + dir * 50.0, sin(ang) * 100.0 - 60.0)
		_add({"type": "ember", "pos": pos, "vel": v, "life": randf_range(0.3, 0.6), "col": col, "size": 2.0, "grav": 260.0, "drag": 0.97})


# --- pixel-art override ----------------------------------------------------

func _sprite_id(element: String, heavy: bool) -> String:
	var base := "hit_" + (element if element != "" else "phys")
	return base + ("_heavy" if heavy else "")


static func sprite_strip(id: String) -> Texture2D:
	if not _sprite_cache.has(id):
		var path := SPRITE_DIR + id + ".png"
		_sprite_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return _sprite_cache[id]


func _sprite(id: String, pos: Vector2, s: float, dir: float) -> void:
	var tex := sprite_strip(id)
	if tex == null:
		return
	var h := tex.get_height()
	var frames := maxi(1, tex.get_width() / h)
	_add({"type": "sprite", "pos": pos, "life": frames / SPRITE_FPS, "col": Color.WHITE,
		"size": h * s, "tex": tex, "frames": frames, "flip": dir < 0.0})


# --- update & draw ---------------------------------------------------------

func _process(delta: float) -> void:
	for f in _fx:
		f.life -= delta
		f.vel *= f.drag
		f.vel.y += f.grav * delta
		f.pos += f.vel * delta
		f.rot += f.spin * delta
	_fx = _fx.filter(func(f): return f.life > 0.0)
	queue_redraw()


func _draw() -> void:
	for f in _fx:
		var p: float = 1.0 - f.life / f.max  # progress 0..1
		var c: Color = f.col
		var pos: Vector2 = f.pos
		match f.type:
			"core":
				var r: float = f.size * (1.0 - p * 0.5)
				draw_texture_rect(_glow, Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(c, 1.0 - p))
				if p < 0.35:
					draw_circle(pos, r * 0.3, Color(1, 1, 1, 1.0 - p * 2.0))
			"star":
				var grow := minf(1.0, p * 4.0)
				var w: float = f.size * (1.0 - p)
				for ray in f.rays:
					var d := Vector2(cos(ray[0]), sin(ray[0]))
					var n := Vector2(-d.y, d.x)
					var tip: Vector2 = pos + d * ray[1] * (0.4 + 0.6 * grow)
					draw_colored_polygon(PackedVector2Array([pos + n * w, tip, pos - n * w]), Color(c, 1.0 - p * 0.5))
					draw_colored_polygon(PackedVector2Array([pos + n * w * 0.35, pos + (tip - pos) * 0.75, pos - n * w * 0.35]), Color(1, 1, 1, 1.0 - p))
			"ring":
				var e := 1.0 - pow(1.0 - p, 3.0)
				var rr: float = f.size * (0.2 + 0.8 * e)
				draw_arc(pos, rr, 0.0, TAU, 28, Color(c, 1.0 - p), 5.0 * (1.0 - p) + 1.0)
			"focus":
				# lines start far out and rush inwards, leaving the centre free
				var inner: float = f.size * (0.35 + 0.25 * p)
				for ray in f.rays:
					var d := Vector2(cos(ray[0]), sin(ray[0]))
					var outer: float = f.size * (1.25 - 0.3 * p) * (0.8 + 0.4 * ray[1])
					var w: float = ray[2]
					var a0: Vector2 = pos + d * outer
					var a1: Vector2 = pos + d * (inner + (outer - inner) * (1.0 - ray[1]) * 0.5)
					var nrm: Vector2 = d.orthogonal() * w
					draw_colored_polygon(PackedVector2Array([a0 + nrm, a0 - nrm, a1]), Color(c, (1.0 - p) * 0.8))
			"streak":
				var v: Vector2 = f.vel
				var tail := v * 0.045 * (1.0 - p * 0.5)
				draw_line(pos.round(), (pos - tail).round(), Color(c, 1.0 - p), 2.0)
				draw_line(pos.round(), (pos - tail * 0.4).round(), Color(1, 1, 1, 1.0 - p), 1.0)
			"ember":
				draw_rect(Rect2(pos.round(), Vector2(2, 2)), Color(c, 1.0 - p))
			"flame":
				var fr: float = f.size * (1.0 - p * 0.7)
				var fc: Color = c.lerp(Color("ff3d1f"), p)
				draw_texture_rect(_glow, Rect2(pos - Vector2(fr, fr * 1.3), Vector2(fr * 2.0, fr * 2.6)), false, Color(fc, 1.0 - p))
			"shard":
				var d2: Vector2 = Vector2(cos(f.rot), sin(f.rot)) * f.size
				var n2 := Vector2(-d2.y, d2.x) * 0.4
				draw_colored_polygon(PackedVector2Array([pos + d2, pos + n2, pos - d2, pos - n2]), Color(c, 1.0 - p * 0.6))
				draw_line(pos - d2 * 0.6, pos + d2 * 0.6, Color(1, 1, 1, 1.0 - p), 1.0)
			"zap":
				var pts := PackedVector2Array([pos])
				var dirv := Vector2(cos(f.rot), sin(f.rot))
				var steps := 4
				for k in range(1, steps + 1):
					var q: Vector2 = pos + dirv * f.size * k / steps
					pts.append(q + Vector2(-dirv.y, dirv.x) * randf_range(-5, 5))
				draw_polyline(pts, Color(c, 1.0 - p), 3.0)
				draw_polyline(pts, Color(1, 1, 1, 1.0 - p), 1.0)
			"swirl":
				var sr: float = f.size * (0.4 + 0.6 * p)
				draw_arc(pos, sr, f.rot, f.rot + 2.3, 14, Color(c, 1.0 - p), 3.0 * (1.0 - p) + 1.0)
			"slash":
				var sl: float = f.size * (0.8 + 0.4 * p)
				draw_set_transform(pos, f.rot, Vector2.ONE)
				draw_arc(Vector2.ZERO, sl, -1.2, 1.2, 16, Color(c, 1.0 - p), 7.0 * (1.0 - p) + 1.0)
				draw_arc(Vector2.ZERO, sl, -1.0, 1.0, 16, Color(1, 1, 1, 1.0 - p), 2.0)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"sprite":
				var tex: Texture2D = f.tex
				var h := float(tex.get_height())
				var frame := mini(int(p * f.frames), f.frames - 1)
				var sz: float = f.size
				var dst := Rect2(pos - Vector2(sz, sz) / 2.0, Vector2(sz, sz))
				if f.flip:
					dst = Rect2(dst.position + Vector2(sz, 0), Vector2(-sz, sz))
				draw_texture_rect_region(tex, dst, Rect2(frame * h, 0, h, h))
