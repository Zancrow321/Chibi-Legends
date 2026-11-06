class_name GlutFx
extends Node2D
## Fire effects of the fighting style Glutatem ("Schmiede": sparks, glowing
## slag, anvil flashes, heat). Drawn in code like the M.U.G.E.N-style hit
## sparks, but smooth instead of pixel art: soft additive glow, motion-blurred
## spark streaks that bounce off the ground, flame tongues with a heat colour
## ramp, dark smoke (lit by the fire), sprite afterimages and manga sound words.
##
## Three canvases: smoke (normal blend, lit by 2D lights), glow (additive,
## unshaded, linear filtering) and text (unshaded). Every bigger effect also
## asks the dusk stage for a short flash of real 2D light, so fire lights up
## the figure and the ground. Runs while the tree is paused (hit-stop).

## Heat ramp from cold ember to white-hot (index 0..5).
const RAMP := [Color("5a1410"), Color("c2331f"), Color("ff3b1f"), Color("ff9a2a"), Color("ffd25c"), Color("fff4d0")]
const SMOKE := Color(0.16, 0.12, 0.13, 0.5)
## PixelLab effect sprites (tools/glutatem/gen_katana.py): katana slash arcs
## and one burst per Zug / Meisterzug, drawn additive so the bloom picks them up.
const PIC_DIR := "res://assets/combat/vfx/glutatem/%s.png"

static var _glow_tex: Texture2D
static var _pic_tex := {}

var room: Node  # TrainingRoom
var stage: Node  # DuskStage (lights), may be null
var font: Font

var _add: Node2D
var _smoke: Node2D
var _text: Node2D
var _fx: Array = []        # additive particles
var _smokes: Array = []
var _words: Array = []
var _lines: Array = []     # one-frame glow lines (blade heat), cleared each frame
var _spr: Node2D           # PixelLab sprites (additive, crisp pixels)
var _pics: Array = []


static func heat(t: float) -> Color:
	t = clampf(t, 0.0, 1.0) * (RAMP.size() - 1)
	var i := mini(int(t), RAMP.size() - 2)
	return RAMP[i].lerp(RAMP[i + 1], t - i)


static func glow_texture() -> Texture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.18, 0.42, 0.7, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.78), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.07), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 64
		t.height = 64
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_glow_tex = t
	return _glow_tex


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = CombatFx.FOCUS_Z + 3
	font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")
	_smoke = Node2D.new()
	_smoke.z_index = -1
	_smoke.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_smoke.draw.connect(_draw_smoke)
	add_child(_smoke)
	_add = Node2D.new()
	_add.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_add.material = m
	_add.draw.connect(_draw_add)
	add_child(_add)
	_spr = Node2D.new()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sm := CanvasItemMaterial.new()
	sm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_spr.material = sm
	_spr.draw.connect(_draw_pics)
	add_child(_spr)
	_text = Node2D.new()
	_text.z_index = 2
	var tm := CanvasItemMaterial.new()
	tm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_text.material = tm
	_text.draw.connect(_draw_text)
	add_child(_text)


# --- lights -------------------------------------------------------------------

## Short flash of real 2D light (only in the dusk look).
func light(pos: Vector2, col: Color, energy: float, size: float, life: float) -> void:
	if stage != null and stage.has_method("flash_light"):
		stage.flash_light(pos, col, energy, size, life)


# --- building blocks ----------------------------------------------------------

static func pic(id: String) -> Texture2D:
	if not _pic_tex.has(id):
		var p := PIC_DIR % id
		_pic_tex[id] = load(p) if ResourceLoader.exists(p) else null
	return _pic_tex[id]


## A PixelLab effect sprite that pops in, grows a little and fades.
## `size` is the drawn width in px; `grow0` the start scale; `drift` moves it.
func burst(id: String, pos: Vector2, size: float, life := 0.35, rot := 0.0, flip := false,
		col := Color.WHITE, grow0 := 0.5, drift := Vector2.ZERO) -> void:
	if pic(id) == null:
		return
	_pics.append({"id": id, "pos": pos, "size": size, "life": life, "max": life, "rot": rot,
		"flip": flip, "col": col, "g0": grow0, "vel": drift})
	glow(pos, Color(col.lerp(heat(0.7), 0.5), 0.55), size * 0.42, life * 0.7)


func _push(d: Dictionary) -> void:
	d.merge({"vel": Vector2.ZERO, "grav": 0.0, "drag": 1.0, "size": 4.0, "rot": 0.0, "spin": 0.0}, false)
	d["max"] = d.life
	_fx.append(d)


## Soft glow blob. `size` is the radius; it shrinks to `end` x size.
func glow(pos: Vector2, col: Color, size: float, life: float, vel := Vector2.ZERO, end := 0.5) -> void:
	_push({"type": "glow", "pos": pos, "col": col, "size": size, "life": life, "vel": vel, "end": end})


## Spark streaks: bright motion-blurred lines that fall, cool down and
## bounce off the ground once. `angle` = main direction, `spread` = cone half-angle.
func sparks(pos: Vector2, angle: float, spread: float, count: int, speed: float, life := 0.45, grav := 520.0) -> void:
	for i in count:
		var a := angle + randf_range(-spread, spread)
		var v := Vector2(cos(a), sin(a)) * speed * randf_range(0.45, 1.15)
		_push({"type": "streak", "pos": pos, "vel": v, "life": randf_range(life * 0.5, life),
			"grav": grav, "drag": 0.985, "size": randf_range(1.0, 2.0), "bounce": true})


## Thin falling spark (spark rain of the Meisterzug).
func rain(pos: Vector2, vel: Vector2, life := 0.9) -> void:
	_push({"type": "streak", "pos": pos, "vel": vel, "life": life, "grav": 120.0, "drag": 1.0, "size": 0.5, "bounce": true})


## Floating embers that drift up and flicker.
func embers(pos: Vector2, count: int, area := 8.0, rise := 40.0, life := 0.9) -> void:
	for i in count:
		_push({"type": "ember", "pos": pos + Vector2(randf_range(-area, area), randf_range(-area, area) * 0.5),
			"vel": Vector2(randf_range(-20, 20), -randf_range(rise * 0.5, rise)), "life": randf_range(life * 0.5, life),
			"size": randf_range(0.8, 1.8), "drag": 0.98, "phase": randf() * TAU})


## A flame tongue: rises, stretches and cools down along the heat ramp.
func flame(pos: Vector2, size: float, vel := Vector2(0, -60), life := 0.45, hot := 0.9) -> void:
	_push({"type": "flame", "pos": pos, "vel": vel, "size": size, "life": life, "hot": hot, "drag": 0.96,
		"phase": randf() * TAU})


## Dark smoke puff (normal blend, lit by the fire lights).
func smoke(pos: Vector2, size: float, vel := Vector2(0, -24), life := 1.0) -> void:
	_smokes.append({"pos": pos, "vel": vel, "size": size, "life": life, "max": life})


## Anvil flash: a white-hot core with sharp rays and a light flash.
func anvil(pos: Vector2, size := 22.0, rays := 7) -> void:
	var rr: Array = []
	var base := randf() * TAU
	for i in rays:
		rr.append([base + TAU * i / rays + randf_range(-0.2, 0.2), size * randf_range(0.6, 1.3)])
	_push({"type": "star", "pos": pos, "life": 0.16, "col": RAMP[4], "size": 2.4, "rays": rr})
	glow(pos, Color(RAMP[5], 0.8), size * 0.5, 0.16, Vector2.ZERO, 0.3)
	glow(pos, Color(RAMP[3], 0.5), size * 1.1, 0.26, Vector2.ZERO, 0.7)
	light(pos, Color(1.0, 0.7, 0.35), 2.0, 0.4 + size * 0.012, 0.22)


func ring(pos: Vector2, radius: float, col := Color("ff9a2a"), life := 0.3, width := 5.0) -> void:
	_push({"type": "ring", "pos": pos, "life": life, "col": col, "size": radius, "width": width})


## Cone of fire/sparks in front of the blade: a glowing wedge that flares up
## and fades, plus streaks flying out of it.
func cone(origin: Vector2, side: float, length: float, half_angle := 0.36, life := 0.22) -> void:
	_push({"type": "cone", "pos": origin, "life": life, "side": side, "len": length, "half": half_angle})
	sparks(origin, 0.0 if side > 0.0 else PI, half_angle, int(length * 0.45), length * 6.5, 0.5, 380.0)
	light(origin + Vector2(side * length * 0.5, 0), Color(1.0, 0.62, 0.3), 2.0, 0.8, 0.25)


## Afterimage of the fighter sprite (additive, tinted), MUGEN-style.
func afterimage(sprite: Sprite2D, foot: Vector2, flip: float, col: Color, life := 0.22) -> void:
	if sprite == null or sprite.texture == null:
		return
	_push({"type": "ghost", "pos": foot, "life": life, "col": col, "tex": sprite.texture,
		"hframes": sprite.hframes, "frame": sprite.frame, "offset": sprite.offset, "flip": flip})


## Glowing line for this frame only (heated blade).
func glow_line(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	_lines.append([a, b, col, width])


## Manga sound word ("KLONG!"): pops in big, settles, fades.
func word(pos: Vector2, text: String, col: Color, size := 22, tilt := -0.12) -> void:
	# stack words that would overlap a fresh one
	for w in _words:
		if w.max - w.life < 0.35 and absf(w.pos.x - pos.x) < 60.0 and absf(w.pos.y - pos.y) < 14.0:
			pos.y = w.pos.y - 14.0
	_words.append({"pos": pos, "text": text, "col": col, "size": size, "life": 0.7, "max": 0.7, "tilt": tilt + randf_range(-0.06, 0.06)})


## Exhaled breath before every Zug: warm puffs and a few embers.
func breath(mouth: Vector2, facing: float, hot := 0.5) -> void:
	for i in 4:
		glow(mouth + Vector2(facing * i * 2.0, 0), heat(hot).lerp(Color.WHITE, 0.4), 3.0 + i, 0.35 + i * 0.05,
			Vector2(facing * randf_range(30, 55), randf_range(-14, -4)), 1.6)
	embers(mouth + Vector2(facing * 4, 0), 3, 2.0, 30.0, 0.6)


## Burst of glowing slag chunks (visual only).
func slag_burst(pos: Vector2, count: int, speed := 180.0) -> void:
	for i in count:
		var a := -PI / 2.0 + randf_range(-1.2, 1.2)
		_push({"type": "chunk", "pos": pos, "vel": Vector2(cos(a), sin(a)) * speed * randf_range(0.5, 1.1), "life": randf_range(0.5, 0.9),
			"grav": 700.0, "size": randf_range(1.5, 3.0), "rot": randf() * TAU, "spin": randf_range(-12, 12), "bounce": true})


## Fountain of sparks straight up from an impact.
func fountain(pos: Vector2, count := 30, speed := 320.0) -> void:
	sparks(pos, -PI / 2.0, 0.55, count, speed, 0.75, 620.0)
	glow(pos, Color(RAMP[4], 0.55), 16.0, 0.25, Vector2.ZERO, 0.4)
	for i in 6:
		flame(pos + Vector2(randf_range(-8, 8), 0), randf_range(7, 11), Vector2(randf_range(-20, 20), randf_range(-140, -80)), 0.4)
	light(pos + Vector2(0, -10), Color(1.0, 0.65, 0.3), 2.4, 1.1, 0.35)


# --- update ---------------------------------------------------------------------

func _ground_y(x: float) -> float:
	for g in TrainingRoom.GROUND:
		if x >= g[0] and x <= g[0] + g[2]:
			return g[1]
	return 9999.0


func _process(delta: float) -> void:
	for f in _fx:
		f.life -= delta
		f.vel *= pow(f.drag, delta * 60.0)
		f.vel.y += f.grav * delta
		var np: Vector2 = f.pos + f.vel * delta
		if f.get("bounce", false):
			var gy := _ground_y(np.x)
			if np.y >= gy and f.pos.y <= gy:
				np.y = gy - 0.5
				f.vel = Vector2(f.vel.x * 0.55, -absf(f.vel.y) * 0.32)
				f.bounce = false
		f.pos = np
		f.rot += f.spin * delta
	_fx = _fx.filter(func(f): return f.life > 0.0)
	for s in _smokes:
		s.life -= delta
		s.pos += s.vel * delta
		s.vel.x *= 0.98
	_smokes = _smokes.filter(func(s): return s.life > 0.0)
	for w in _words:
		w.life -= delta
	_words = _words.filter(func(w): return w.life > 0.0)
	for q in _pics:
		q.life -= delta
		q.pos += q.vel * delta
	_pics = _pics.filter(func(q): return q.life > 0.0)
	_spr.queue_redraw()
	_add.queue_redraw()
	_smoke.queue_redraw()
	_text.queue_redraw()


# --- draw -------------------------------------------------------------------------

func _draw_glow(pos: Vector2, r: float, col: Color, stretch := Vector2.ONE) -> void:
	var s := Vector2(r, r) * stretch
	_add.draw_texture_rect(glow_texture(), Rect2(pos - s, s * 2.0), false, col)


func _draw_add() -> void:
	var tex := glow_texture()
	for l in _lines:
		var a: Vector2 = l[0]
		var b: Vector2 = l[1]
		var col: Color = l[2]
		var w: float = l[3]
		var n := maxi(2, int(a.distance_to(b) / 3.0))
		for i in n + 1:
			_draw_glow(a.lerp(b, float(i) / n), w * 2.2, Color(col, col.a * 0.45))
		_add.draw_line(a, b, Color(col, col.a), maxf(1.0, w * 0.6), true)
		_add.draw_line(a, b, Color(1, 1, 0.9, col.a), maxf(0.6, w * 0.25), true)
	_lines.clear()
	for f in _fx:
		var p: float = 1.0 - f.life / f.max
		var pos: Vector2 = f.pos
		match f.type:
			"glow":
				var r: float = f.size * lerpf(1.0, f.end, p)
				_draw_glow(pos, r, Color(f.col, f.col.a * 0.75 * (1.0 - p * p)))
			"streak":
				var hot := 1.0 - p
				var c := heat(0.35 + hot * 0.65)
				var tail: Vector2 = f.vel * 0.028
				_add.draw_line(pos, pos - tail, Color(c, 1.0 - p * 0.6), f.size + 0.6, true)
				_add.draw_line(pos, pos - tail * 0.45, Color(1, 0.95, 0.8, hot), maxf(0.6, f.size * 0.5), true)
				if p < 0.5:
					_draw_glow(pos, 3.0 + f.size, Color(c, 0.35 * (1.0 - p * 2.0)))
			"ember":
				var fl: float = 0.6 + 0.4 * sin(f.phase + p * 30.0)
				var c2 := heat(0.75 - p * 0.5)
				_draw_glow(pos + Vector2(sin(f.phase + p * 9.0) * 3.0, 0), f.size * 2.8, Color(c2, (1.0 - p) * 0.55 * fl))
				_add.draw_rect(Rect2(pos - Vector2(0.5, 0.5), Vector2(1, 1)), Color(c2.lerp(Color.WHITE, 0.4), (1.0 - p) * fl))
			"flame":
				var hotness: float = f.hot * (1.0 - p)
				var c3 := heat(hotness)
				var fr: float = f.size * (1.0 - p * 0.6)
				var wob: float = sin(f.phase + p * 14.0) * 1.5
				_draw_glow(pos + Vector2(wob, 0), fr, Color(c3, (1.0 - p) * 0.8), Vector2(0.75, 1.35))
				_draw_glow(pos + Vector2(wob, fr * 0.2), fr * 0.45, Color(heat(hotness + 0.2), (1.0 - p)), Vector2(0.7, 1.2))
			"star":
				var grow := minf(1.0, p * 4.0)
				var w: float = f.size * (1.0 - p)
				for ray in f.rays:
					var d := Vector2(cos(ray[0]), sin(ray[0]))
					var nrm := Vector2(-d.y, d.x)
					var tip: Vector2 = pos + d * ray[1] * (0.4 + 0.6 * grow)
					_add.draw_colored_polygon(PackedVector2Array([pos + nrm * w, tip, pos - nrm * w]), Color(f.col, 1.0 - p * 0.5))
					_add.draw_colored_polygon(PackedVector2Array([pos + nrm * w * 0.35, pos + (tip - pos) * 0.75, pos - nrm * w * 0.35]), Color(1, 1, 1, 1.0 - p))
			"ring":
				var e := 1.0 - pow(1.0 - p, 3.0)
				var rr: float = f.size * (0.15 + 0.85 * e)
				_add.draw_arc(pos, rr, 0.0, TAU, 40, Color(f.col, 1.0 - p), f.width * (1.0 - p) + 0.8, true)
				_add.draw_arc(pos, rr * 0.96, 0.0, TAU, 40, Color(1, 0.95, 0.8, (1.0 - p) * 0.6), 0.8, true)
			"cone":
				_draw_cone(f, p)
			"chunk":
				var c4 := heat(0.85 - p * 0.6)
				_draw_glow(pos, f.size * 3.0, Color(c4, (1.0 - p) * 0.6))
				_add.draw_rect(Rect2(pos - Vector2(f.size, f.size) * 0.5, Vector2(f.size, f.size)), Color(c4.lerp(Color.WHITE, 0.3), 1.0 - p))
			"ghost":
				_draw_ghost(f, p)


func _draw_pics() -> void:
	for q in _pics:
		var p: float = 1.0 - q.life / q.max
		var k := minf(1.0, p * 5.0)
		var sc: float = lerpf(q.g0, 1.0, 1.0 - pow(1.0 - k, 3.0)) * (1.0 + 0.12 * p)
		var a: float = 1.0 if p < 0.4 else 1.0 - (p - 0.4) / 0.6
		var s: float = q.size * sc
		_spr.draw_set_transform(q.pos, q.rot, Vector2(-1.0 if q.flip else 1.0, 1.0))
		_spr.draw_texture_rect(pic(q.id), Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)), false, Color(q.col, q.col.a * a))
	_spr.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_cone(f: Dictionary, p: float) -> void:
	var o: Vector2 = f.pos
	var side: float = f.side
	var flare := minf(1.0, p * 5.0)
	var length: float = f.len * (0.55 + 0.45 * flare)
	var half: float = f.half * (0.8 + 0.4 * p)
	var a := 1.0 - p
	var dir := Vector2(side, 0)
	var steps := 7
	var pts := PackedVector2Array([o])
	var cols := PackedColorArray([Color(1, 0.97, 0.85, a * 0.75)])
	for i in steps + 1:
		var ang := lerpf(-half, half, float(i) / steps)
		var d := dir.rotated(ang * side)
		pts.append(o + d * length * (0.85 + 0.15 * sin(i * 2.3 + p * 20.0)))
		cols.append(Color(heat(0.45), 0.0))
	_add.draw_polygon(pts, cols)
	var inner := PackedVector2Array([o])
	var icols := PackedColorArray([Color(1, 1, 0.9, a * 0.8)])
	for i in steps + 1:
		var ang2 := lerpf(-half * 0.45, half * 0.45, float(i) / steps)
		inner.append(o + dir.rotated(ang2 * side) * length * 0.7)
		icols.append(Color(heat(0.8), 0.0))
	_add.draw_polygon(inner, icols)
	_draw_glow(o + dir * length * 0.3, length * 0.4, Color(heat(0.6), a * 0.3), Vector2(1.0, 0.6))


func _draw_ghost(f: Dictionary, p: float) -> void:
	var tex: Texture2D = f.tex
	var hf: int = maxi(1, f.hframes)
	var fw := float(tex.get_width()) / hf
	var fh := float(tex.get_height())
	var src := Rect2(fw * f.frame, 0, fw, fh)
	var off: Vector2 = f.offset
	var dst := Rect2(f.pos + Vector2(off.x * f.flip, off.y), Vector2(fw * f.flip, fh))
	_add.draw_texture_rect_region(tex, dst, src, Color(f.col, (1.0 - p) * f.col.a))


func _draw_smoke() -> void:
	var tex := glow_texture()
	for s in _smokes:
		var p: float = 1.0 - s.life / s.max
		var r: float = s.size * (0.6 + p * 1.2)
		var c := Color(SMOKE, SMOKE.a * sin(p * PI))
		_smoke.draw_texture_rect(tex, Rect2(s.pos - Vector2(r, r), Vector2(r, r) * 2.0), false, c)


func _draw_text() -> void:
	for w in _words:
		var p: float = 1.0 - w.life / w.max
		var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - p * 6.0)
		var a := 1.0 if p < 0.65 else 1.0 - (p - 0.65) / 0.35
		var fs: int = w.size
		var tw := font.get_string_size(w.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_text.draw_set_transform(w.pos + Vector2(0, -p * 10.0), w.tilt, Vector2(pop, pop) * 0.5)
		var at := Vector2(-tw / 2.0, fs * 0.35)
		_text.draw_string_outline(font, at, w.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.1, 0.03, 0.03, a))
		_text.draw_string(font, at, w.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(w.col, a))
		_text.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
