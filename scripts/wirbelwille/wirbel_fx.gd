class_name WirbelFx
extends KlangFx
## Effects of the fighting style Wirbelwille (Windschatten, Kreiselfaust).
## Builds on KlangFx (rings, glow, shards, motes, manga words) and adds the
## animated PixelLab effects from assets/vfx/wirbelwille (strips + frame
## times in effects.json):
##  - anim():  plays an effect once (or for `life` seconds when it loops),
##             additive so the bloom lifts it; smoke ("poff", "strohpuppe")
##             is drawn with normal blend, else it would turn white
##  - hold():  one frame of a looping effect at a moving spot (rings at the
##             fist, the storm cloak around the figure, the flying Sturmrad)
##  - thread(): Willensfäden, thin glowing lines between two points
## Colours: turquoise, white and gold; orange only as a small accent.

const TURQ := Color("5fe3e0")
const ICE := Color("bff6ff")
const GOLD := Color("ffd36a")
const STORM := Color("6f9aa6")
const VFX_DIR := "res://assets/vfx/wirbelwille/"
const SMOKE := ["poff", "strohpuppe"]

static var _meta: Dictionary = {}
static var _tex: Dictionary = {}

var _norm: Node2D
var _held: Array = []      # one-frame looping effects
var _threads: Array = []   # one-frame threads


static func info(id: String) -> Dictionary:
	if _meta.is_empty():
		var f := FileAccess.open(VFX_DIR + "effects.json", FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if typeof(d) == TYPE_DICTIONARY:
				_meta = d
	return _meta.get(id, {})


static func tex(id: String) -> Texture2D:
	if not _tex.has(id):
		var p := VFX_DIR + id + ".png"
		_tex[id] = load(p) if ResourceLoader.exists(p) else null
	return _tex[id]


## Total play time of an effect in seconds.
static func length(id: String) -> float:
	var ms := 0.0
	for d in info(id).get("durations_ms", []):
		ms += float(d)
	return maxf(0.05, ms / 1000.0)


## Frame index at time t (loops when the effect loops or `loop` is set).
static func frame_at(id: String, t: float, loop := false) -> int:
	var durs: Array = info(id).get("durations_ms", [])
	if durs.is_empty():
		return 0
	var total := length(id)
	var tt := t
	if loop or info(id).get("loop", false):
		tt = fmod(t, total)
	var acc := 0.0
	for i in durs.size():
		acc += float(durs[i]) / 1000.0
		if tt < acc:
			return i
	return durs.size() - 1


func _ready() -> void:
	super._ready()
	_norm = Node2D.new()
	_norm.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_norm.material = m
	_norm.draw.connect(_draw_norm)
	add_child(_norm)
	move_child(_norm, 0)
	_add.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


# --- building blocks ----------------------------------------------------------

## Plays effect `id` at `pos`, `size` = drawn width in px (height keeps the
## ratio). `life` < 0 = once through; looping effects need a life.
## `speed` scales the playback, `follow` (a Node2D) keeps it on that node.
func anim(id: String, pos: Vector2, size: float, life := -1.0, rot := 0.0, flip := false, col := Color.WHITE, speed := 1.0, follow: Node2D = null) -> void:
	if tex(id) == null:
		return
	var l := life if life > 0.0 else length(id) / speed
	var off := Vector2.ZERO
	if follow != null:
		off = pos - follow.global_position
	_fx.append({"type": "anim", "id": id, "pos": pos, "size": size, "rot": rot, "flip": flip, "col": col,
		"speed": speed, "t": 0.0, "life": l, "max": l, "follow": follow, "off": off})


## One frame of a (looping) effect, drawn this frame only. `t` picks the frame.
func hold(id: String, pos: Vector2, size: float, t: float, rot := 0.0, flip := false, col := Color.WHITE) -> void:
	if tex(id) == null:
		return
	_held.append({"f": Engine.get_physics_frames(), "id": id, "pos": pos, "size": size, "t": t, "rot": rot, "flip": flip, "col": col})


## Willensfaden: a thin glowing line for this frame.
func thread(a: Vector2, b: Vector2, col := TURQ, width := 1.2) -> void:
	_threads.append({"f": Engine.get_physics_frames(), "a": a, "b": b, "col": col, "w": width})


## Wind streaks: short white curved lines rushing in a direction.
func gust(pos: Vector2, angle: float, count := 6, length := 40.0, col := ICE) -> void:
	for i in count:
		var off := Vector2(randf_range(-10, 10), randf_range(-22, 22)).rotated(angle)
		_fx.append({"type": "streak", "pos": pos + off, "ang": angle + randf_range(-0.15, 0.15),
			"len": length * randf_range(0.6, 1.2), "col": col, "life": randf_range(0.16, 0.26), "max": 0.26,
			"vel": Vector2(cos(angle), sin(angle)) * randf_range(120.0, 220.0)})


# --- update / draw -------------------------------------------------------------------

func _process(delta: float) -> void:
	for f in _fx:
		if f.type == "anim":
			f.t += delta * f.speed
			if is_instance_valid(f.follow):
				f.pos = f.follow.global_position + f.off
	super._process(delta)
	var now := Engine.get_physics_frames()
	_held = _held.filter(func(h): return h.f >= now - 1)
	_threads = _threads.filter(func(h): return h.f >= now - 1)
	if not _held.is_empty():
		var newest: int = _held.back().f
		_held = _held.filter(func(h): return h.f == newest)
	if not _threads.is_empty():
		var newest_t: int = _threads.back().f
		_threads = _threads.filter(func(h): return h.f == newest_t)
	_norm.queue_redraw()


func _draw_frame(ci: CanvasItem, id: String, frame: int, pos: Vector2, size: float, rot: float, flip: bool, col: Color) -> void:
	var t := tex(id)
	var inf := info(id)
	if t == null or inf.is_empty():
		return
	var fw := float(inf.frame_w)
	var fh := float(inf.frame_h)
	var w := size
	var h := size * fh / fw
	ci.draw_set_transform(pos, rot, Vector2(-1.0 if flip else 1.0, 1.0))
	ci.draw_texture_rect_region(t, Rect2(Vector2(-w, -h) * 0.5, Vector2(w, h)), Rect2(frame * fw, 0, fw, fh), col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_add() -> void:
	super._draw_add()
	for th in _threads:
		_add.draw_line(th.a, th.b, Color(th.col, 0.35), th.w * 3.0, true)
		_add.draw_line(th.a, th.b, Color(WHITE, 0.8), th.w, true)
	for h in _held:
		if h.id in SMOKE:
			continue
		_draw_frame(_add, h.id, frame_at(h.id, h.t, true), h.pos, h.size, h.rot, h.flip, h.col)
		_glow(_add, h.pos, h.size * 0.35, Color(TURQ, 0.12 * h.col.a))
	for f in _fx:
		var p: float = 1.0 - f.life / f.max
		match f.type:
			"anim":
				if f.id in SMOKE:
					continue
				var a: float = 1.0 if p < 0.8 else 1.0 - (p - 0.8) / 0.2
				_draw_frame(_add, f.id, frame_at(f.id, f.t), f.pos, f.size, f.rot, f.flip, Color(f.col, f.col.a * a))
				_glow(_add, f.pos, f.size * 0.4, Color(TURQ, 0.16 * a * (1.0 - p)))
			"streak":
				var dir := Vector2(cos(f.ang), sin(f.ang))
				var a2: float = 1.0 - p
				var n := dir.orthogonal() * 3.0 * sin(p * PI)
				_add.draw_polyline(PackedVector2Array([f.pos, f.pos + dir * f.len * 0.5 + n, f.pos + dir * f.len]), Color(f.col, 0.85 * a2), 1.5, true)


func _draw_norm() -> void:
	for h in _held:
		if h.id in SMOKE:
			_draw_frame(_norm, h.id, frame_at(h.id, h.t, true), h.pos, h.size, h.rot, h.flip, h.col)
	for f in _fx:
		if f.type != "anim" or not (f.id in SMOKE):
			continue
		var p: float = 1.0 - f.life / f.max
		var a: float = 1.0 if p < 0.75 else 1.0 - (p - 0.75) / 0.25
		_draw_frame(_norm, f.id, frame_at(f.id, f.t), f.pos, f.size, f.rot, f.flip, Color(f.col, f.col.a * a))
