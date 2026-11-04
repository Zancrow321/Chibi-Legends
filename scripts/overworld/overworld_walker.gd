class_name OverworldWalker
extends CharacterBody2D
## The player in the overworld: walking, a light jog (Shift), jumping onto
## balconies and terraces. No attacks, no HP: the overworld is calm. Uses the
## same fighter drawings as in combat (FighterSprite) and keeps the roster
## look (ChibiVisual) for the collection menu.

const GRAVITY := 980.0
const MAX_FALL := 480.0
const WALK := 96.0
const JOG := 150.0
const ACCEL := 900.0
const JUMP_VELOCITY := -330.0
const MAX_JUMPS := 2

var sprite: FighterSprite
var visual: ChibiVisual
var facing := 1
## No control while a dialogue or menu is open.
var frozen := false
var _jumps := 0
var _was_floor := true
var _fall_speed := 0.0
var _step_t := 0.0
var idle_time := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Player.LAYER_GROUND | Player.LAYER_PLATFORM
	floor_snap_length = 4.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 40)
	shape.shape = rect
	shape.position = Vector2(0, -20)
	add_child(shape)
	visual = ChibiVisual.new()
	visual.visible = false
	add_child(visual)
	sprite = FighterSprite.new()
	add_child(sprite)


func _physics_process(delta: float) -> void:
	var dir := 0.0
	if not frozen:
		dir = Input.get_axis("move_left", "move_right")
	var speed := JOG if Input.is_action_pressed("dash") else WALK
	velocity.x = move_toward(velocity.x, dir * speed, ACCEL * delta)
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
	velocity.y = minf(velocity.y + GRAVITY * delta * (1.25 if velocity.y > 0.0 else 1.0), MAX_FALL)
	if is_on_floor():
		_jumps = 0
	if not frozen and Input.is_action_just_pressed("jump"):
		if Input.is_action_pressed("move_down") and is_on_floor():
			position.y += 2.0  # drop through a one-way platform
			set_collision_mask_value(2, false)
			get_tree().create_timer(0.25).timeout.connect(func(): set_collision_mask_value(2, true))
		elif _jumps < MAX_JUMPS:
			velocity.y = JUMP_VELOCITY * (1.0 if _jumps == 0 else 0.85)
			_jumps += 1
			sprite.jump()
			Sfx.play("jump", -6.0)
	if not Input.is_action_pressed("jump") and velocity.y < -120.0:
		velocity.y += GRAVITY * delta * 0.8  # short hop
	_fall_speed = velocity.y
	move_and_slide()
	var on_floor := is_on_floor()
	if on_floor and not _was_floor:
		sprite.land(clampf(_fall_speed / MAX_FALL, 0.2, 0.8))
		Sfx.play("land", -6.0)
	_was_floor = on_floor
	sprite.scale.x = facing
	visual.scale.x = facing
	if not on_floor:
		sprite.set_state("jump" if velocity.y < 0.0 else "fall")
	elif absf(velocity.x) > 8.0:
		sprite.set_state("run")
		_step_t -= delta * absf(velocity.x) / WALK
		if _step_t <= 0.0:
			_step_t = 0.36
			Sfx.play("footstep", -4.0)
	else:
		sprite.set_state("idle")
	if absf(velocity.x) < 1.0 and on_floor:
		idle_time += delta
	else:
		idle_time = 0.0
