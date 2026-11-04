class_name FighterSprite
extends Node2D
## Shows a fighter from sprite strips in 96 x 96 cells (foot point x 44, y 88,
## facing right). Test figure 2 only has an idle and a sword strip, so the
## other states reuse those drawings with squash, lean and bob in code
## (the style guide asks for few drawings and timing in code anyway).
## The owner flips it via scale.x.

const CELL := 96
const FOOT := Vector2(44, 88)

var strips := {
	"idle": {"tex": preload("res://assets/characters/jus_test/testfigur2_idle.png"), "frames": 5, "fps": 7.0},
	"slash": {"tex": preload("res://assets/characters/jus_test/testfigur2_slash.png"), "frames": 7, "fps": 12.0},
}

var state := "idle"  # idle, run, jump, fall, dash, attack, cast, hurt
var anim_time := 0.0
## While attacking: which frame of the sword strip to show (set by the owner).
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


## Material for the body sprite (the dusk look lights it with rounded normals).
func set_body_material(m: Material) -> void:
	_sprite.material = m


func set_state(new_state: String) -> void:
	if new_state != state:
		state = new_state
		anim_time = 0.0


func _show(strip: String, frame: int) -> void:
	var s: Dictionary = strips[strip]
	if _sprite.texture != s.tex:
		_sprite.texture = s.tex
		_sprite.hframes = s.frames
	_sprite.frame = clampi(frame, 0, s.frames - 1)


func _process(delta: float) -> void:
	anim_time += delta
	flash = maxf(0.0, flash - delta)
	var sc := Vector2.ONE
	var rot := 0.0
	var off := Vector2.ZERO
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
		"attack":
			_show("slash", attack_frame)
		"cast":
			_show("slash", 5 if anim_time < 0.12 else 6)
		"hurt":
			# no hurt drawing yet: guard pose thrown back
			_show("slash", 6)
			rot = -0.28 + minf(anim_time * 0.8, 0.2)
			off.x = -3.0
			sc = Vector2(0.94, 1.04)
	_sprite.position = off
	_sprite.rotation = rot
	_sprite.scale = sc
	var base := Color(1, 1, 1)
	if state == "hurt":
		base = Color(1.6, 0.75, 0.7) if fmod(anim_time, 0.1) < 0.05 else Color(1, 1, 1)
	_sprite.modulate = base.lerp(Color(4, 4, 4), clampf(flash * 10.0, 0.0, 1.0))
