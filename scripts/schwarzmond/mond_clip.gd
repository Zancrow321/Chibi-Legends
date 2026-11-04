class_name MondClip
extends Sprite2D
## Plays one PixelLab effect of Schwarzmond (assets/vfx/schwarzmond/<id>/
## effect.png sheet + effect.json frame rects and durations; the anchor of
## the effect comes from response.json and sits on the node position).
## One-shot clips free themselves at the end; looping clips run until
## `life` runs out (or forever with life < 0) and can follow a node.

const DIR := "res://assets/vfx/schwarzmond/%s/effect.%s"

static var _cache: Dictionary = {}  # id -> {tex, frames, durations, w, h} or {}
static var room: Node = null  # TrainingRoom (set by MondCaster): clips pause in hit-stop

var id := ""
var loop := false
var life := -1.0
var follow: Node2D = null
var follow_offset := Vector2.ZERO
var speed := 1.0
var fade := 0.0  # seconds to fade out at the end of `life`

var _data: Dictionary
var _t := 0.0
var _f := 0
var _age := 0.0


static func info(clip_id: String) -> Dictionary:
	if _cache.has(clip_id):
		return _cache[clip_id]
	var d := {}
	var png := DIR % [clip_id, "png"]
	var js := DIR % [clip_id, "json"]
	if ResourceLoader.exists(png) and FileAccess.file_exists(js):
		var meta = JSON.parse_string(FileAccess.get_file_as_string(js))
		var frames: Array = meta.get("frames", []) if typeof(meta) == TYPE_DICTIONARY else []
		if frames.size() > 0:
			var durs: Array = []
			var rects: Array = []
			for fr in frames:
				durs.append(float(fr.get("duration", 50)) / 1000.0)
				rects.append(Rect2(fr.frame.x, fr.frame.y, fr.frame.w, fr.frame.h))
			var w := float(frames[0].frame.w)
			var h := float(frames[0].frame.h)
			var anchor := Vector2(w, h) * 0.5
			var resp := "res://assets/vfx/schwarzmond/%s/response.json" % clip_id
			if FileAccess.file_exists(resp):
				var r = JSON.parse_string(FileAccess.get_file_as_string(resp))
				if typeof(r) == TYPE_DICTIONARY and r.get("last_response", {}).has("anchor"):
					var a: Dictionary = r.last_response.anchor
					anchor = Vector2(float(a.x), float(a.y))
			d = {"tex": load(png), "frames": frames.size(), "durations": durs, "rects": rects,
				"offset": Vector2(w, h) * 0.5 - anchor}
	_cache[clip_id] = d
	return d


static func available(clip_id: String) -> bool:
	return not info(clip_id).is_empty()


## Spawns a clip under `parent` (null when the effect file is missing).
static func play(parent: Node, clip_id: String, pos: Vector2, flip := false, scl := 1.0, rot := 0.0, looping := false, seconds := -1.0) -> MondClip:
	if parent == null or not available(clip_id):
		return null
	var c := MondClip.new()
	c.id = clip_id
	c.loop = looping
	c.life = seconds
	c.global_position = pos
	c.scale = Vector2(-scl if flip else scl, scl)  # mirrored with the anchor
	c.rotation = rot
	parent.add_child(c)
	c.global_position = pos
	return c


func _ready() -> void:
	_data = info(id)
	if _data.is_empty():
		queue_free()
		return
	texture = _data.tex
	region_enabled = true
	region_rect = _data.rects[0]
	offset = _data.offset
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 5
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m


func _process(delta: float) -> void:
	if room != null and is_instance_valid(room) and room.fx.is_frozen() and process_mode != Node.PROCESS_MODE_ALWAYS:
		return
	_age += delta
	if follow != null:
		if not is_instance_valid(follow):
			queue_free()
			return
		global_position = follow.global_position + follow_offset
	_t += delta * speed
	var durs: Array = _data.durations
	while _t >= float(durs[_f]):
		_t -= float(durs[_f])
		_f += 1
		if _f >= durs.size():
			if not loop:
				queue_free()
				return
			_f = 0
	region_rect = _data.rects[_f]
	if life >= 0.0:
		if _age >= life:
			queue_free()
		elif fade > 0.0 and life - _age < fade:
			modulate.a = (life - _age) / fade
