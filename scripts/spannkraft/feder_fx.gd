class_name FederFx
extends KlangFx
## Effects of the fighting style Spannkraft (Federleib). Builds on KlangFx
## (rings, glow, shards, manga words) and adds:
##  - bursts: the PixelLab effect sprites (assets/combat/vfx/spannkraft),
##    drawn additive so the bloom picks them up; they pop in, grow and fade
##  - limbs: stretched arms and legs as thick skin-coloured bands with a
##    fist or foot at the end, drawn every frame by the caster (normal blend,
##    above the figure, ink outline like the sprites)
##  - speed lines and steam puffs
## Colours: coral, sun yellow, sky blue, steel blue for Eisenwille.

const CORAL := Color("ff5a4a")
const YELLOW := Color("ffd23c")
const SKY := Color("6fd0ff")
const STEEL := Color("7fa8d8")
const STEAM := Color("d8d4d0")
const FX_DIR := "res://assets/combat/vfx/spannkraft/%s.png"

static var _tex: Dictionary = {}

var _limb_layer: Node2D
var _limbs: Array = []   # one-frame limbs
var _balls: Array = []   # one-frame inflated bodies / arms
var _puffs: Array = []   # steam (normal blend)


static func tex(id: String) -> Texture2D:
	if not _tex.has(id):
		var p := FX_DIR % id
		_tex[id] = load(p) if ResourceLoader.exists(p) else null
	return _tex[id]


func _ready() -> void:
	super._ready()
	_limb_layer = Node2D.new()
	_limb_layer.z_index = -1  # under the glow, above the figure (KlangFx sits at FOCUS_Z + 3)
	_limb_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_limb_layer.draw.connect(_draw_limbs)
	add_child(_limb_layer)
	move_child(_limb_layer, 0)


# --- building blocks ----------------------------------------------------------

## Effect sprite: pops in (scale `grow0` -> 1), stays, fades. `size` is the
## drawn width in px; `rot` turns it, `flip` mirrors it horizontally.
func burst(id: String, pos: Vector2, size: float, life := 0.35, rot := 0.0, flip := false, col := Color.WHITE, grow0 := 0.45) -> void:
	if tex(id) == null:
		return
	_fx.append({"type": "burst", "id": id, "pos": pos, "size": size, "rot": rot, "flip": flip, "col": col,
		"g0": grow0, "life": life, "max": life})


## Burst that follows a line from a to b (stretched along it), e.g. the
## Schnappfaust trail from the shoulder to the fist.
func streak(id: String, a: Vector2, b: Vector2, thick: float, life := 0.2, col := Color.WHITE) -> void:
	if tex(id) == null:
		return
	_fx.append({"type": "streak", "id": id, "a": a, "b": b, "w": thick, "col": col, "life": life, "max": life})


## Straight speed lines around a point (comic motion lines).
func speedlines(pos: Vector2, angle: float, count: int, length := 40.0, col := Color.WHITE, life := 0.18) -> void:
	for i in count:
		var off := Vector2(randf_range(-6, 6), randf_range(-26, 26)).rotated(angle)
		_fx.append({"type": "speed", "pos": pos + off - Vector2(cos(angle), sin(angle)) * randf_range(0, 20),
			"ang": angle, "len": length * randf_range(0.5, 1.2), "col": col, "life": life * randf_range(0.6, 1.0), "max": life})


func steam(pos: Vector2, count := 3, area := 10.0) -> void:
	for i in count:
		_puffs.append({"pos": pos + Vector2(randf_range(-area, area), randf_range(-area, area) * 0.5),
			"vel": Vector2(randf_range(-14, 14), randf_range(-60, -30)), "r": randf_range(3.0, 6.0),
			"life": randf_range(0.5, 0.9), "max": 0.9})


## A stretched limb for this frame: shoulder/hip -> fist/foot.
func limb(from: Vector2, to: Vector2, skin: Color, thick := 4.0, fist := 4.2, tint := Color(0, 0, 0, 0)) -> void:
	_limbs.append({"f": Engine.get_physics_frames(), "a": from, "b": to, "skin": skin, "w": thick, "fist": fist, "tint": tint})


## An inflated ball (Prallbauch body, Prallform arm) for this frame.
func ball(pos: Vector2, r: float, skin: Color, tint := Color(0, 0, 0, 0)) -> void:
	_balls.append({"f": Engine.get_physics_frames(), "pos": pos, "r": r, "skin": skin, "tint": tint})


# --- update / draw -------------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	for p in _puffs:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= pow(0.92, delta * 60.0)
		p.r += delta * 10.0
	_puffs = _puffs.filter(func(p): return p.life > 0.0)
	# limbs live until the next physics frame replaces them (no flicker on fast monitors)
	var now := Engine.get_physics_frames()
	_limbs = _limbs.filter(func(l): return l.f >= now - 1)
	_balls = _balls.filter(func(b): return b.f >= now - 1)
	if not _limbs.is_empty():
		var newest: int = _limbs.back().f
		_limbs = _limbs.filter(func(l): return l.f == newest)
	if not _balls.is_empty():
		var newest_b: int = _balls.back().f
		_balls = _balls.filter(func(b): return b.f == newest_b)
	_limb_layer.queue_redraw()


func _draw_add() -> void:
	super._draw_add()
	for f in _fx:
		var p: float = 1.0 - f.life / f.max
		match f.type:
			"burst":
				var t := tex(f.id)
				var k := minf(1.0, p * 5.0)
				var sc: float = lerpf(f.g0, 1.0, 1.0 - pow(1.0 - k, 3.0)) * (1.0 + 0.15 * p)
				var a: float = 1.0 if p < 0.45 else 1.0 - (p - 0.45) / 0.55
				var s: float = f.size * sc
				_add.draw_set_transform(f.pos, f.rot, Vector2(-1.0 if f.flip else 1.0, 1.0))
				_add.draw_texture_rect(t, Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)), false, Color(f.col, f.col.a * a))
				_add.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				_glow(_add, f.pos, s * 0.45, Color(f.col, 0.18 * a))
			"streak":
				var t2 := tex(f.id)
				var d: Vector2 = f.b - f.a
				var a2: float = 1.0 - p
				# the sprite runs diagonally (bottom left -> top right): turn it flat first
				var left: bool = d.x < 0.0
				_add.draw_set_transform(f.a.lerp(f.b, 0.5), d.angle() + (-0.62 if left else 0.62), Vector2(1.0, -1.0) if left else Vector2.ONE)
				_add.draw_texture_rect(t2, Rect2(Vector2(-d.length() * 0.5, -f.w * 0.5), Vector2(d.length(), f.w)), false, Color(f.col, a2))
				_add.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"speed":
				var dir := Vector2(cos(f.ang), sin(f.ang))
				var a3: float = 1.0 - p
				_add.draw_line(f.pos, f.pos + dir * f.len * (0.4 + 0.6 * p), Color(f.col, 0.8 * a3), 1.6, true)


func _draw_limbs() -> void:
	for p in _puffs:
		var k: float = 1.0 - p.life / p.max
		_limb_layer.draw_circle(p.pos, p.r, Color(STEAM, 0.55 * (1.0 - k)))
	for b in _balls:
		var c: Color = b.skin
		if b.tint.a > 0.0:
			c = c.lerp(b.tint, b.tint.a)
		_limb_layer.draw_circle(b.pos, b.r + 1.6, INK)
		_limb_layer.draw_circle(b.pos, b.r, c)
		_limb_layer.draw_circle(b.pos + Vector2(-b.r * 0.3, -b.r * 0.35), b.r * 0.35, Color(1, 1, 1, 0.35))
	for l in _limbs:
		var c2: Color = l.skin
		if l.tint.a > 0.0:
			c2 = c2.lerp(l.tint, l.tint.a)
		var shade := c2.darkened(0.25)
		_limb_layer.draw_line(l.a, l.b, INK, l.w + 2.4, true)
		_limb_layer.draw_line(l.a, l.b, c2, l.w, true)
		var n: Vector2 = (l.b - l.a).normalized().orthogonal()
		_limb_layer.draw_line(l.a + n * l.w * 0.25, l.b + n * l.w * 0.25, shade, l.w * 0.35, true)
		_limb_layer.draw_circle(l.b, l.fist + 1.2, INK)
		_limb_layer.draw_circle(l.b, l.fist, c2)
		_limb_layer.draw_circle(l.b + (l.b - l.a).normalized() * l.fist * 0.3, l.fist * 0.45, Color(1, 1, 1, 0.3))
