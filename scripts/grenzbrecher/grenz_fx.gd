class_name GrenzFx
extends FederFx
## Effects of the fighting style Grenzbrecher (Ki). Builds on FederFx
## (effect sprites, speed lines, rings, glow, manga words) and adds the
## shapes that need to follow the figure every frame:
##  - beam: the Kernstrahl, a white core inside a sky-blue band with a soft
##    halo, flickering width and a bright muzzle, all additive (bloom)
##  - aura: rising flame tongues around the figure (Sammeln, Grenzbruch)
##  - orb: a glowing Ki ball (charge in the fist, Ki-Kugeln, Sonnenkern)
##  - mark: the blinking target mark of Fernstrahl
##  - rocks: little stones that float up while charging
## Effect sprites live in assets/combat/vfx/grenzbrecher ("grenzbrecher/<id>").
## Colours: sky blue, white, gold and orange only in sparks and cores.

const SKY2 := Color("6fd0ff")
const BLUE2 := Color("3f8fff")
const GOLD := Color("ffd25c")
const ORANGE := Color("ff9a3c")
const ROCK := Color("6b5a4e")

var _beams: Array = []   # one-frame beams
var _auras: Array = []   # one-frame auras
var _orbs: Array = []    # one-frame orbs
var _marks: Array = []   # one-frame target marks
var _rocks: Array = []   # floating stones (normal blend)


static func gtex(id: String) -> Texture2D:
	return FederFx.tex("grenzbrecher/" + id)


## Effect sprite from the Grenzbrecher folder.
func gburst(id: String, pos: Vector2, size: float, life := 0.35, rot := 0.0, flip := false, col := Color.WHITE, grow0 := 0.45) -> void:
	burst("grenzbrecher/" + id, pos, size, life, rot, flip, col, grow0)


## Beam for this frame from `a` to `b`; `w` = thickness, `k` 0..1 = power.
func beam(a: Vector2, b: Vector2, w: float, k := 1.0, col := SKY2) -> void:
	_beams.append({"f": Engine.get_physics_frames(), "a": a, "b": b, "w": w, "k": k, "col": col})


## Flame aura around `pos` (feet) for this frame; `k` 0..1 = strength.
func aura(pos: Vector2, k: float, col := SKY2, tall := 1.0) -> void:
	_auras.append({"f": Engine.get_physics_frames(), "pos": pos, "k": k, "col": col, "tall": tall})


func orb(pos: Vector2, r: float, col := SKY2, corona := false) -> void:
	_orbs.append({"f": Engine.get_physics_frames(), "pos": pos, "r": r, "col": col, "corona": corona})


func mark(pos: Vector2, k: float) -> void:
	_marks.append({"f": Engine.get_physics_frames(), "pos": pos, "k": k})


## Stones lift off the ground around `pos` and drift up (charging).
func rocks(pos: Vector2, count := 1, area := 40.0) -> void:
	for i in count:
		_rocks.append({"pos": pos + Vector2(randf_range(-area, area), randf_range(-2, 2)),
			"vel": Vector2(randf_range(-6, 6), randf_range(-46, -22)), "r": randf_range(1.2, 2.8),
			"life": randf_range(0.7, 1.3), "max": 1.3, "spin": randf() * TAU})


func _process(delta: float) -> void:
	super._process(delta)
	for r in _rocks:
		r.life -= delta
		r.pos += r.vel * delta
		r.vel *= pow(0.97, delta * 60.0)
		r.spin += delta * 3.0
	_rocks = _rocks.filter(func(r): return r.life > 0.0)
	var now := Engine.get_physics_frames()
	_beams = _beams.filter(func(x): return x.f >= now - 1)
	_auras = _auras.filter(func(x): return x.f >= now - 1)
	_orbs = _orbs.filter(func(x): return x.f >= now - 1)
	_marks = _marks.filter(func(x): return x.f >= now - 1)
	for arr in [_beams, _auras, _orbs, _marks]:
		if not arr.is_empty():
			var newest: int = arr.back().f
			var keep: Array = arr.filter(func(x): return x.f == newest)
			arr.clear()
			arr.append_array(keep)


func _draw_add() -> void:
	super._draw_add()
	var tm := Time.get_ticks_msec() * 0.001
	for a in _auras:
		_draw_aura(a, tm)
	for b in _beams:
		_draw_beam(b, tm)
	for o in _orbs:
		_draw_orb(o, tm)
	for m in _marks:
		var pulse := 0.5 + 0.5 * sin(tm * 18.0)
		var r: float = lerpf(26.0, 12.0, m.k)
		var c := Color(GOLD, 0.5 + 0.5 * pulse)
		_add.draw_arc(m.pos, r, 0.0, TAU, 40, c, 2.0, true)
		for i in 4:
			var d := Vector2.RIGHT.rotated(i * PI / 2.0 + tm * 2.0)
			_add.draw_line(m.pos + d * (r + 3.0), m.pos + d * (r + 10.0), c, 2.0, true)
		_glow(_add, m.pos, r * 1.4, Color(GOLD, 0.12 + 0.12 * pulse))


func _draw_beam(b: Dictionary, tm: float) -> void:
	var a: Vector2 = b.a
	var e: Vector2 = b.b
	var k: float = b.k
	var flick := 1.0 + 0.12 * sin(tm * 60.0) + 0.06 * sin(tm * 97.0)
	var w: float = b.w * flick
	var col: Color = b.col
	# halo, band, core
	_add.draw_line(a, e, Color(col, 0.18 * k), w * 2.6, true)
	_add.draw_line(a, e, Color(col, 0.55 * k), w * 1.3, true)
	_add.draw_line(a, e, Color(WHITE, 0.95), w * 0.45, true)
	var t := gtex("strahl")
	if t != null:
		var d := e - a
		_add.draw_set_transform(a.lerp(e, 0.5), d.angle(), Vector2.ONE)
		_add.draw_texture_rect(t, Rect2(Vector2(-d.length() * 0.5, -w * 1.1), Vector2(d.length(), w * 2.2)), false, Color(1, 1, 1, 0.8 * k))
		_add.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# ripples along the beam
	var n := int(a.distance_to(e) / 26.0)
	var dir := (e - a).normalized()
	for i in n:
		var p := a + dir * fposmod(i * 26.0 + tm * 420.0, a.distance_to(e))
		_add.draw_arc(p, w * 0.75, 0.0, TAU, 16, Color(WHITE, 0.25 * k), 1.0, true)
	_glow(_add, a, w * 2.0, Color(WHITE, 0.8))
	_glow(_add, a, w * 3.4, Color(col, 0.45 * k))
	_glow(_add, e, w * 2.2, Color(col, 0.6 * k))


func _draw_aura(au: Dictionary, tm: float) -> void:
	var p: Vector2 = au.pos
	var k: float = au.k
	var col: Color = au.col
	var tall: float = au.tall
	_glow(_add, p + Vector2(0, -20), 30.0 + 14.0 * k, Color(col, 0.1 + 0.1 * k))
	# flame tongues: thin teardrops that lick upwards
	for i in 9:
		var ph := tm * (5.0 + i * 0.7) + i * 1.7
		var x := sin(i * 2.3) * (10.0 + 4.0 * k)
		var h := (26.0 + 22.0 * k) * tall * (0.7 + 0.3 * sin(ph))
		var base := p + Vector2(x, -2)
		var tip := base + Vector2(sin(ph * 1.3) * 4.0, -h)
		var wdt := 3.0 + 2.5 * k
		var poly := PackedVector2Array([base + Vector2(-wdt, 0), base.lerp(tip, 0.5) + Vector2(-wdt * 0.6, 0), tip, base.lerp(tip, 0.5) + Vector2(wdt * 0.6, 0), base + Vector2(wdt, 0)])
		_add.draw_colored_polygon(poly, Color(col, (0.12 + 0.16 * k) * (0.6 + 0.4 * sin(ph * 0.7))))
	var t := gtex("aura")
	if t != null:
		var s := (64.0 + 30.0 * k) * tall
		_add.draw_texture_rect(t, Rect2(p + Vector2(-s * 0.5, -s * 0.92), Vector2(s, s)), false, Color(1, 1, 1, 0.12 + 0.18 * k))


func _draw_orb(o: Dictionary, tm: float) -> void:
	var p: Vector2 = o.pos
	var r: float = o.r
	var col: Color = o.col
	if o.corona:
		var t := gtex("sonnenkern")
		if t != null:
			var s := r * 3.0
			_add.draw_set_transform(p, tm * 0.6, Vector2.ONE)
			_add.draw_texture_rect(t, Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, 0.9))
			_add.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in 12:
			var d := Vector2.RIGHT.rotated(i * TAU / 12.0 + tm * 0.8)
			var l := r * (1.25 + 0.25 * sin(tm * 7.0 + i))
			_add.draw_line(p + d * r * 0.9, p + d * l, Color(GOLD, 0.5), 2.0, true)
	_glow(_add, p, r * 2.6, Color(col, 0.35))
	_glow(_add, p, r * 1.5, Color(col, 0.75))
	_add.draw_circle(p, r * 0.75, Color(WHITE, 0.9))
	_add.draw_arc(p, r, 0.0, TAU, 32, Color(col, 0.7), 1.6, true)


func _draw_limbs() -> void:
	super._draw_limbs()
	for r in _rocks:
		var k: float = 1.0 - r.life / r.max
		var a := 1.0 if k < 0.7 else 1.0 - (k - 0.7) / 0.3
		var c: Vector2 = r.pos
		var s: float = r.r
		var pts := PackedVector2Array()
		for i in 5:
			pts.append(c + Vector2.RIGHT.rotated(r.spin + i * TAU / 5.0) * s * (0.8 + 0.3 * (i % 2)))
		_limb_layer.draw_colored_polygon(pts, Color(ROCK, a))
