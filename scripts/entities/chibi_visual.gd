class_name ChibiVisual
extends Node2D
## Draws a layered chibi character (about 32 x 48 px) procedurally.
## Origin = between the feet. Faces right; the owner flips it via scale.x.
## Layers: back hair / accessory, legs, body, arms, head, face, front hair, weapon.
## Placeholder art until real sprite sheets replace it, but the look data
## (hair, colors, outfit) already drives it so customization plugs in directly.

const OUTLINE := Color("1a1020")

var look: Dictionary = GameData.LOOK_PRESETS[0].duplicate()
var state := "idle"  # idle, run, jump, fall, attack, dash, cast
var anim_time := 0.0
var attack_phase := 0  # 0..2 combo step, changes the swing pose

var _parts: Array = []  # [Rect2, Color, outlined]


func _process(delta: float) -> void:
	anim_time += delta
	queue_redraw()


func set_state(new_state: String) -> void:
	if new_state != state:
		state = new_state
		anim_time = 0.0


func _r(x: float, y: float, w: float, h: float, col: Color, outlined := true) -> void:
	_parts.append([Rect2(x, y, w, h), col, outlined])


func _draw() -> void:
	_parts.clear()
	var hair: Color = GameData.HAIR_COLORS[look.get("hair_color", 0)]
	var hair_dark := hair.darkened(0.3)
	var hair_light := hair.lightened(0.25)
	var skin: Color = GameData.SKIN_TONES[look.get("skin", 0)]
	var skin_dark := skin.darkened(0.15)
	var eyes: Color = GameData.EYE_COLORS[look.get("eyes", 0)]
	var top: Color = GameData.TOP_COLORS[look.get("top", 0)]
	var top_dark := top.darkened(0.22)
	var pants: Color = GameData.PANTS_COLORS[look.get("pants", 0)]
	var shoe := Color("3a2a26")
	var accent := Color("d23b3b")
	var gold := Color("f2c14e")
	var style: int = look.get("hair_style", 0)

	# --- animation offsets ---
	var bob := 0.0
	var back_leg := Vector2.ZERO
	var front_leg := Vector2.ZERO
	match state:
		"idle":
			bob = -1.0 if fmod(anim_time, 1.0) > 0.5 else 0.0
		"run":
			var f := int(anim_time * 10.0) % 4
			back_leg.x = [-3, 0, 3, 0][f]
			front_leg.x = [3, 0, -3, 0][f]
			back_leg.y = [0, -1, 0, -1][f]
			front_leg.y = [0, -1, 0, -1][f]
			bob = [0, -1, 0, -1][f]
		"jump":
			front_leg = Vector2(2, -3)
			back_leg = Vector2(-1, -1)
		"fall":
			front_leg = Vector2(1, -1)
			back_leg = Vector2(-2, 0)
		"dash":
			front_leg = Vector2(3, -2)
			back_leg = Vector2(-4, -1)
		"attack":
			front_leg = Vector2(3, 0)
			back_leg = Vector2(-3, 0)
	var b := bob
	var scarf_wave := 1.0 if fmod(anim_time * 6.0, 2.0) > 1.0 else 0.0
	if state == "run" or state == "dash":
		scarf_wave += 1.0

	# --- back layers ---
	if look.get("acc", 1) == 1:  # scarf tail
		_r(-13, -22 + b + scarf_wave, 6, 3, accent)
		_r(-17, -21 + b + scarf_wave * 1.5, 4, 3, accent)
	match style:
		1:  # long
			_r(-14, -38 + b, 9, 27, hair_dark)
		2:  # ponytail
			_r(-19, -44 + b, 6, 5, hair_dark)
			_r(-22, -40 + b, 6, 12, hair_dark)
			_r(-21, -28 + b, 4, 6, hair_dark)
	# back arm
	_r(-10, -21 + b, 3, 8, top_dark)
	_r(-10, -13 + b, 3, 3, skin_dark)

	# --- legs ---
	_r(-6 + back_leg.x, -11 + back_leg.y, 4, 7, pants.darkened(0.2))
	_r(-7 + back_leg.x, -4 + back_leg.y, 5, 4, shoe)
	_r(1 + front_leg.x, -11 + front_leg.y, 4, 7, pants)
	_r(1 + front_leg.x, -4 + front_leg.y, 6, 4, shoe)

	# --- torso (academy jacket) ---
	_r(-7, -22 + b, 14, 11, top)
	_r(-7, -22 + b, 3, 11, top_dark, false)
	_r(0, -22 + b, 3, 4, skin, false)  # collar opening
	_r(-7, -13 + b, 14, 2, Color("3a2a46"), false)  # belt
	_r(1, -13 + b, 2, 2, gold, false)  # buckle
	_r(3, -19 + b, 1, 6, gold, false)  # jacket trim

	# --- head ---
	var hy := -45.0 + b
	_r(-11, hy + 1, 22, 22, skin)
	_r(-12, hy + 4, 24, 16, skin)
	_r(-9, hy + 23, 18, 1, skin)
	_r(-12, hy + 14, 3, 8, skin_dark, false)  # cheek shadow (back side)

	# face (facing right)
	var ey := hy + 11
	for ex in [-4.0, 4.0]:
		_r(ex - 1, ey, 6, 1, OUTLINE, false)  # lash line
		_r(ex, ey + 1, 4, 6, eyes, false)
		_r(ex, ey + 1, 4, 2, eyes.darkened(0.35), false)
		_r(ex + 1, ey + 4, 2, 3, eyes.darkened(0.55), false)  # pupil
		_r(ex, ey + 2, 1, 2, Color.WHITE, false)  # highlight
		_r(ex + 3, ey + 5, 1, 1, Color.WHITE, false)
	_r(-5, ey + 8, 3, 1, Color("ff9aa2"), false)  # blush
	_r(7, ey + 8, 3, 1, Color("ff9aa2"), false)
	if state == "attack" or state == "cast":
		_r(4, ey + 10, 3, 2, Color("7a2a2a"), false)  # shout
	else:
		_r(4, ey + 10, 2, 1, Color("7a2a2a"), false)

	# --- front hair ---
	match style:
		0:  # spiky
			_r(-12, hy - 2, 24, 10, hair)
			_r(-13, hy + 1, 26, 6, hair)
			_r(-11, hy - 6, 4, 5, hair)
			_r(-6, hy - 8, 5, 7, hair)
			_r(0, hy - 7, 5, 6, hair)
			_r(6, hy - 5, 5, 4, hair)
			_r(-16, hy + 1, 4, 6, hair)
			_r(-17, hy + 7, 4, 6, hair)
			_r(-13, hy + 6, 7, 12, hair)
			_r(2, hy + 8, 3, 4, hair)
			_r(6, hy + 8, 3, 3, hair)
			_r(10, hy + 6, 3, 9, hair)
			_r(-4, hy - 1, 6, 2, hair_light, false)
		1:  # long
			_r(-12, hy - 2, 24, 10, hair)
			_r(-13, hy + 1, 26, 6, hair)
			_r(-13, hy + 6, 8, 16, hair)
			_r(1, hy + 8, 4, 3, hair)
			_r(5, hy + 8, 3, 4, hair)
			_r(9, hy + 6, 4, 14, hair)
			_r(-3, hy, 7, 2, hair_light, false)
		2:  # ponytail
			_r(-12, hy - 2, 24, 10, hair)
			_r(-13, hy + 1, 26, 6, hair)
			_r(-13, hy + 6, 6, 9, hair)
			_r(3, hy + 8, 4, 3, hair)
			_r(9, hy + 6, 3, 8, hair)
			_r(-16, hy - 1, 4, 4, accent)  # ribbon
			_r(-3, hy, 7, 2, hair_light, false)
		3:  # short
			_r(-12, hy - 1, 24, 8, hair)
			_r(-13, hy + 2, 26, 4, hair)
			_r(-13, hy + 5, 5, 7, hair)
			_r(4, hy + 7, 5, 2, hair)
			_r(-3, hy + 1, 6, 2, hair_light, false)
		_:  # messy
			_r(-14, hy - 4, 28, 12, hair)
			_r(-15, hy, 30, 7, hair)
			_r(-4, hy - 7, 8, 4, hair)
			_r(-16, hy + 5, 5, 10, hair)
			_r(11, hy + 5, 4, 7, hair)
			_r(1, hy + 7, 4, 4, hair)
			_r(6, hy + 7, 3, 3, hair)
			_r(-6, hy - 2, 8, 2, hair_light, false)

	if look.get("acc", 1) == 1:  # scarf front
		_r(-8, -24 + b, 16, 4, accent)
		_r(-8, -21 + b, 16, 1, accent.darkened(0.3), false)

	# --- front arm + weapon ---
	if state == "attack":
		var reach := 2.0 if attack_phase == 1 else 0.0
		_r(5, -21 + b, 7 + reach, 3, top)
		_r(12 + reach, -21 + b, 3, 3, skin)
		_r(15 + reach, -23 + b, 1, 7, gold)  # guard
		_r(16 + reach, -21 + b, 17, 2, Color("e8eef2"))  # blade
		_r(16 + reach, -21 + b, 17, 1, Color.WHITE, false)
	elif state == "cast":
		_r(5, -24 + b, 3, 8, top)
		_r(6, -27 + b, 3, 3, skin)
	else:
		_r(6, -21 + b, 3, 8, top)
		_r(6, -13 + b, 3, 3, skin)
		# sheathed katana at the hip
		for i in 6:
			_r(-12 + i * 3, -9 + b - i, 3, 2, Color("3a2a46"))
		_r(6, -16 + b, 4, 2, gold)

	# outline pass first, then fills, so only the silhouette keeps a dark edge
	for p in _parts:
		if p[2]:
			draw_rect((p[0] as Rect2).grow(1.0), OUTLINE)
	for p in _parts:
		draw_rect(p[0], p[1])
