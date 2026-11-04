class_name FighterSprite
extends Node2D
## Shows a fighter from sprite strips (one row of equal cells, foot point at
## FOOT, facing right). Test figure 2 only has an idle and a sword strip, so
## the other states reuse those drawings with squash, lean and bob in code
## (the style guide asks for few drawings and timing in code anyway).
## Imported characters (addons/mugen_importer) bring their own strips per
## state and per move, with frame times in ticks: see use_sprite_data().
## The owner flips it via scale.x.

const CELL := 96
const FOOT := Vector2(44, 88)
const DEFAULT_STRIPS := {
	"idle": {"tex": preload("res://assets/characters/jus_test/testfigur2_idle.png"), "frames": 5, "fps": 7.0},
	"slash": {"tex": preload("res://assets/characters/jus_test/testfigur2_slash.png"), "frames": 7, "fps": 12.0},
}

var strips: Dictionary = DEFAULT_STRIPS.duplicate()
## our state -> strip name, only for imported characters
var state_strips: Dictionary = {}

var state := "idle"  # idle, run, jump, fall, dash, attack, cast, hurt
var anim_time := 0.0
## While attacking: which strip and which frame of it to show (set by the owner).
var attack_strip := "slash"
var attack_frame := 0
var flash := 0.0

var _sprite: Sprite2D


func _init() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.offset = -FOOT
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_show("idle", 0)


## Switches to the drawings of a moveset's "sprite" block; empty = test figure 2.
func use_sprite_data(sp: Dictionary) -> void:
	strips = DEFAULT_STRIPS.duplicate()
	state_strips = {}
	_sprite.offset = -FOOT
	if sp.is_empty():
		_sprite.texture = null
		_show("idle", 0)
		return
	strips = {}
	for name in sp.get("strips", {}):
		var d: Dictionary = sp.strips[name]
		var tex := load(String(d.file)) as Texture2D
		if tex == null:
			push_warning("FighterSprite: %s fehlt" % d.file)
			continue
		strips[name] = {"tex": tex, "frames": int(d.frames), "ticks": d.get("ticks", []), "loop": int(d.get("loop", 0))}
	for st in sp.get("states", {}):
		if strips.has(sp.states[st]):
			state_strips[st] = sp.states[st]
	if not state_strips.has("idle") and not strips.is_empty():
		state_strips["idle"] = strips.keys()[0]
	if state_strips.has("idle"):
		strips["idle"] = strips[state_strips.idle]
	var foot: Array = sp.get("foot", [FOOT.x, FOOT.y])
	_sprite.offset = -Vector2(foot[0], foot[1])
	_sprite.texture = null
	_show("idle", 0)


## Material for the body sprite (the dusk look lights it with rounded normals).
func set_body_material(m: Material) -> void:
	_sprite.material = m


func set_state(new_state: String) -> void:
	if new_state != state:
		state = new_state
		anim_time = 0.0


func _show(strip: String, frame: int) -> void:
	if not strips.has(strip):
		strip = "idle"
	var s: Dictionary = strips[strip]
	if _sprite.texture != s.tex:
		_sprite.texture = s.tex
		_sprite.hframes = s.frames
	_sprite.frame = clampi(frame, 0, s.frames - 1)


## Frame of a looping strip at time t: by its ticks (60 per second) if it
## has them, else by fps. Frames before "loop" play once.
func _frame_at(strip: String, t: float) -> int:
	var s: Dictionary = strips[strip]
	var ticks: Array = s.get("ticks", [])
	if ticks.is_empty():
		return int(t * s.get("fps", 8.0)) % s.frames
	var total := 0
	for k in ticks.size():
		total += maxi(1, int(ticks[k]))
	var tick := int(t * 60.0)
	if tick < total:
		var acc := 0
		for k in ticks.size():
			acc += maxi(1, int(ticks[k]))
			if tick < acc:
				return k
	var loop: int = clampi(s.get("loop", 0), 0, ticks.size() - 1)
	var loop_len := 0
	for k in range(loop, ticks.size()):
		loop_len += maxi(1, int(ticks[k]))
	var lt := (tick - total) % maxi(1, loop_len)
	var acc2 := 0
	for k in range(loop, ticks.size()):
		acc2 += maxi(1, int(ticks[k]))
		if lt < acc2:
			return k
	return loop


func _process(delta: float) -> void:
	anim_time += delta
	flash = maxf(0.0, flash - delta)
	var sc := Vector2.ONE
	var rot := 0.0
	var off := Vector2.ZERO
	var own: String = state_strips.get(state, "")
	if state == "attack":
		_show(attack_strip, attack_frame)
	elif own != "":
		_show(own, _frame_at(own, anim_time))
		if state == "dash":
			rot = 0.12
	elif not state_strips.is_empty():
		# imported figure without a drawing for this state: idle pose + code
		_show("idle", 0)
		match state:
			"run":
				var step := absf(sin(anim_time * 14.0))
				off.y = -step * 2.0
				rot = 0.12
			"jump":
				sc = Vector2(0.9, 1.1)
			"fall":
				sc = Vector2(1.04, 0.97)
			"dash":
				rot = 0.22
				sc = Vector2(1.15, 0.9)
			"hurt":
				rot = -0.28 + minf(anim_time * 0.8, 0.2)
				off.x = -3.0
				sc = Vector2(0.94, 1.04)
	else:
		_default_state(delta, sc, rot, off)
		return
	_apply(sc, rot, off)


func _default_state(_delta: float, sc: Vector2, rot: float, off: Vector2) -> void:
	match state:
		"idle":
			_show("idle", int(anim_time * strips.idle.fps) % strips.idle.frames)
		"run":
			# no run drawings yet: idle pose, leaning forward with a step bob
			_show("idle", 0)
			var step := absf(sin(anim_time * 14.0))
			off.y = -step * 2.0
			rot = 0.12
			sc = Vector2(1.0 + step * 0.04, 1.0 - step * 0.04)
		"jump":
			_show("idle", 1)
			sc = Vector2(0.9, 1.1)
		"fall":
			_show("idle", 2)
			sc = Vector2(1.04, 0.97)
		"dash":
			_show("slash", 3)
			rot = 0.22
			sc = Vector2(1.15, 0.9)
		"cast":
			_show("slash", 5 if anim_time < 0.12 else 6)
		"hurt":
			# no hurt drawing yet: guard pose thrown back
			_show("slash", 6)
			rot = -0.28 + minf(anim_time * 0.8, 0.2)
			off.x = -3.0
			sc = Vector2(0.94, 1.04)
	_apply(sc, rot, off)


func _apply(sc: Vector2, rot: float, off: Vector2) -> void:
	_sprite.position = off
	_sprite.rotation = rot
	_sprite.scale = sc
	var base := Color(1, 1, 1)
	if state == "hurt":
		base = Color(1.6, 0.75, 0.7) if fmod(anim_time, 0.1) < 0.05 else Color(1, 1, 1)
	_sprite.modulate = base.lerp(Color(4, 4, 4), clampf(flash * 10.0, 0.0, 1.0))
