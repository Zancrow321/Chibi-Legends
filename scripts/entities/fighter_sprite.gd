class_name FighterSprite
extends Node2D
## Shows a fighter from sprite strips (one row of equal cells, foot point at
## FOOT, facing right). Test figure 2 only has an idle and a sword strip, so
## the other states reuse those drawings with squash, lean and bob in code
## (the style guide asks for few drawings and timing in code anyway).
## Imported characters (addons/mugen_importer) bring their own strips per
## state and per move, with frame times in ticks: see use_sprite_data().
## The own fighter is the Character Creator figure (LayeredBody: body,
## clothes, hair, weapon at the hand anchor); states and attack phases pick
## its poses, and the same code lean/squash is applied on top.
## The owner flips it via scale.x.

const CELL := 96
const FOOT := Vector2(44, 88)
const DEFAULT_STRIPS := {
	"idle": {"tex": preload("res://assets/characters/jus_test/testfigur2_idle.png"), "frames": 5, "fps": 7.0},
	"slash": {"tex": preload("res://assets/characters/jus_test/testfigur2_slash.png"), "frames": 7, "fps": 12.0},
}

## Optional extra drawings of test figure 2 (PixelLab strips, 96er cells):
## used for their state when the file exists, else code fakes the state.
const EXTRA_STRIPS := {
	"run": ["res://assets/characters/jus_test/testfigur2_run.png", 12.0],
	"jump": ["res://assets/characters/jus_test/testfigur2_jump.png", 12.0],
	"fall": ["res://assets/characters/jus_test/testfigur2_fall.png", 10.0],
	"dash": ["res://assets/characters/jus_test/testfigur2_dash.png", 16.0],
	"hurt": ["res://assets/characters/jus_test/testfigur2_hurt.png", 12.0],
	"heavy": ["res://assets/characters/jus_test/testfigur2_heavy.png", 12.0],
	"slash2": ["res://assets/characters/jus_test/testfigur2_slash2.png", 12.0],
}
## Feel: how fast scale/lean follow their target, and the squash spring.
const FOLLOW := 28.0
const SPRING := 260.0
const DAMP := 16.0

var strips: Dictionary = _default_strips()
## our state -> strip name, only for imported characters
var state_strips: Dictionary = {}

var state := "idle"  # idle, run, jump, fall, dash, attack, cast, hurt
var anim_time := 0.0
## While attacking: which strip and which frame of it to show (set by the owner).
var attack_strip := "slash"
var attack_frame := 0
var flash := 0.0
## Attack phase ("startup", "active", "recovery") and progress 0..1 in it,
## and how strong the attack is (1 = light, 1.6 = heavy): drives the
## anticipation lean, the strike stretch and the settle in code.
var attack_phase := ""
var attack_k := 0.0
var attack_power := 1.0

var _cur_sc := Vector2.ONE
var _cur_rot := 0.0
var _cur_off := Vector2.ZERO
var _squash := Vector2.ZERO  # spring offset on the scale (land, jump)
var _squash_v := Vector2.ZERO

var _sprite: Sprite2D
## Creator figure for the own fighter (false: strips of an imported fighter).
var body: LayeredBody
var use_body := true
## Creator pose for the current attack frame (set by the owner).
var attack_pose := "slash_hit"
var _land_t := 0.0
## Frames of the old sword strip (test figure 2) as creator poses, for
## callers that still think in strip frames (Glutatem's Züge).
const SLASH_POSE := ["slash_wind", "slash_wind", "slash_wind", "slash_hit", "upper_hit", "slash_wind", "slash_side"]
## Our state -> creator animation.
const BODY_ANIM := {"idle": "idle", "run": "run", "jump": "jump", "fall": "fall", "dash": "dash", "hurt": "hit"}


func _init() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.offset = -FOOT
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_show("idle", 0)
	body = LayeredBody.new()
	add_child(body)
	_sprite.visible = false


func _ready() -> void:
	set_look(CreatorCatalog.load_look())


## New creator look (after the Character Creator closed).
func set_look(look: Dictionary) -> void:
	body.look = look.duplicate(true)


## Big weapons (scale 2 and up, or "twohand": true) stand in the two-hand guard.
func _twohand() -> bool:
	var w: Dictionary = CreatorCatalog.data.get("weapons", {}).get(str(body.look.get("weapon", "")), {})
	return bool(w.get("twohand", float(w.get("scale", 1)) >= 2.0))


## Hand and tip of the weapon in the world, or [] without a creator weapon.
func blade_line() -> Array:
	if not use_body or not visible or body._weapon == null or body._weapon.texture == null or body._wdata.is_empty():
		return []
	var g: Array = body._wdata["grip"]
	var t: Array = body._wdata["tip"]
	var xf := body._weapon.get_global_transform()
	return [xf * Vector2.ZERO, xf * Vector2(t[0] - g[0], t[1] - g[1])]


## Switches to the drawings of a moveset's "sprite" block; empty = test figure 2.
static func _default_strips() -> Dictionary:
	var out := DEFAULT_STRIPS.duplicate()
	for name in EXTRA_STRIPS:
		var e: Array = EXTRA_STRIPS[name]
		if ResourceLoader.exists(e[0]):
			var tex := load(e[0]) as Texture2D
			out[name] = {"tex": tex, "frames": maxi(1, tex.get_width() / CELL), "fps": e[1]}
	return out


## Squash on landing (0..1 = how hard), stretch on take-off.
func land(strength := 1.0) -> void:
	_squash_v += Vector2(4.5, -4.5) * strength
	_land_t = 0.05 + 0.07 * strength


func jump() -> void:
	_squash_v += Vector2(-3.5, 4.0)


## Copy of what is shown right now, for afterimages: every visible drawing
## with its texture region and global transform.
func snapshot() -> Dictionary:
	var parts: Array = []
	var list: Array = [_sprite]
	if use_body:
		list = body._rig.get_children()
	for n in list:
		var sp := n as Sprite2D
		if sp == null or not sp.visible or sp.texture == null:
			continue
		var src := sp.region_rect if sp.region_enabled else Rect2(
			float(sp.texture.get_width()) / maxi(1, sp.hframes) * sp.frame, 0,
			float(sp.texture.get_width()) / maxi(1, sp.hframes), sp.texture.get_height())
		parts.append({"tex": sp.texture, "src": src, "xform": sp.get_global_transform(), "offset": sp.offset})
	return {"parts": parts}


func use_sprite_data(sp: Dictionary) -> void:
	use_body = sp.is_empty()
	body.visible = use_body
	_sprite.visible = not use_body
	strips = _default_strips()
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
		if use_body:
			body.play("")
			body.set_pose(attack_pose)
		else:
			_show(attack_strip, attack_frame)
		var p := attack_power
		match attack_phase:
			"startup":
				# anticipation: lean back and crouch a little
				var k := attack_k
				rot = -0.07 * p * k
				sc = Vector2(1.0 - 0.06 * p * k, 1.0 + 0.05 * p * k)
				off.x = -1.5 * p * k
			"active":
				# strike: stretch forward
				rot = 0.09 * p
				sc = Vector2(1.0 + 0.1 * p, 1.0 - 0.07 * p)
				off.x = 2.5 * p
			"recovery":
				var k2 := 1.0 - attack_k
				rot = 0.05 * p * k2
				sc = Vector2(1.0 + 0.04 * p * k2, 1.0 - 0.03 * p * k2)
	elif use_body:
		_land_t = maxf(0.0, _land_t - delta)
		match state:
			"cast":
				body.play("")
				body.set_pose("cast_wind" if anim_time < 0.1 else "cast_hit")
			"idle", "run":
				if _land_t > 0.0:
					body.play("")
					body.set_pose("land_0")
				elif state == "idle":
					body.play("twohand_idle" if _twohand() else "idle")
				else:
					body.play("run")
					rot = 0.04
			_:
				body.play(BODY_ANIM.get(state, "idle"))
		if state == "idle":
			var br := sin(anim_time * 3.2)
			sc = Vector2(1.0 - br * 0.012, 1.0 + br * 0.015)
		elif state == "dash":
			sc = Vector2(1.08, 0.95)
			rot = 0.08
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
	if strips.has(state) and state != "idle":
		# own PixelLab drawing for this state; code only adds a bit of lean
		var st: Dictionary = strips[state]
		var f := int(anim_time * st.fps)
		_show(state, f % st.frames if state in ["run", "dash"] else mini(f, st.frames - 1))
		match state:
			"run":
				rot = 0.05
			"dash":
				rot = 0.1
				sc = Vector2(1.08, 0.95)
		_apply(sc, rot, off)
		return
	match state:
		"idle":
			_show("idle", int(anim_time * strips.idle.fps) % strips.idle.frames)
			var br := sin(anim_time * 3.2)
			sc = Vector2(1.0 - br * 0.012, 1.0 + br * 0.015)
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
	var dt := get_process_delta_time()
	# ease towards the pose instead of snapping (attack strikes snap faster)
	var w := 1.0 - exp(-(FOLLOW * (2.0 if attack_phase == "active" and state == "attack" else 1.0)) * dt)
	_cur_sc = _cur_sc.lerp(sc, w)
	_cur_rot = lerpf(_cur_rot, rot, w)
	_cur_off = _cur_off.lerp(off, w)
	# squash spring (land / jump), keeps the area roughly the same
	_squash_v += (-_squash * SPRING - _squash_v * DAMP) * dt
	_squash += _squash_v * dt
	_squash = _squash.clamp(Vector2(-0.3, -0.3), Vector2(0.3, 0.3))
	var node: Node2D = body if use_body else _sprite
	node.position = _cur_off
	node.rotation = _cur_rot
	node.scale = _cur_sc + _squash
	var base := Color(1, 1, 1)
	if state == "hurt":
		base = Color(1.6, 0.75, 0.7) if fmod(anim_time, 0.1) < 0.05 else Color(1, 1, 1)
	node.modulate = base.lerp(Color(4, 4, 4), clampf(flash * 10.0, 0.0, 1.0))
