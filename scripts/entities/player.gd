class_name Player
extends CharacterBody2D
## Player character: movement (run, double jump, dash, air dash, drop-through)
## and the fighter controls: light, heavy and special, each with a direction
## (neutral, forward, up, down, air). Light + heavy together is a grab.
## Normal attacks come from a MoveSet (frame data in JSON); specials use the
## four skill slots: neutral, forward, up, down (air = neutral).

const GRAVITY := 980.0
const MAX_FALL := 520.0
const RUN_SPEED := 140.0
const ACCEL := 1500.0
const JUMP_VELOCITY := -345.0
const MAX_JUMPS := 2
const DASH_SPEED := 380.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.55
const CAST_TIME := 0.22
## A second button within this time after the first turns the move into a grab.
const GRAB_WINDOW := 3.0 / 60.0
## Special slot per direction (index into build).
const SPECIAL_SLOT := {"neutral": 0, "forward": 1, "up": 2, "down": 3, "air": 0}

const LAYER_GROUND := 1
const LAYER_PLATFORM := 2

var world: Node  # TrainingRoom (spawns attacks, numbers, fx)
var visual: ChibiVisual  # roster look (shown with T)
var sprite: FighterSprite  # test figure 2 (default) or an imported fighter
var moveset: MoveSet = MoveSet.load_file("res://assets/combat/movesets/testfigur2.json")
var moveset_index := 0  # into MoveSet.list_files(), switched with M

var facing := 1
var jumps_used := 0
var dash_timer := 0.0
var dash_cd := 0.0
var air_dash_used := false
## Current normal attack (empty = none), time into it, whether it hit,
## whether its hitbox was spawned, and the next button pressed meanwhile.
var move: Dictionary = {}
var move_t := 0.0
var move_hit := false
var _move_spawned := false
var _queued := ""
var _queued_dir := ""
var cast_timer := 0.0
var last_move_name := ""
var drop_timer := 0.0
var ghost_timer := 0.0

var level := 1
var max_hp := 1200.0
var hp := 1200.0
var max_aura := 100.0
var aura := 100.0
var aura_regen := 12.0
var infinite_aura := false

## Presses are buffered briefly, so a tap is never lost between physics
## ticks (low frame rates) and a jump pressed just before landing still counts.
const BUFFER_TIME := 0.12
const BUFFERED := ["jump", "dash", "light", "heavy", "special", "super", "cycle_look", "toggle_figure", "cycle_moveset"]
var _buffer: Dictionary = {}
var _jump_held := false

var build: Array = GameData.START_BUILD.duplicate()
var cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]
var look_index := 0
var super_cd := 0.0
var in_super := false  # locked in place while the super move plays


func _ready() -> void:
	collision_layer = 0
	collision_mask = LAYER_GROUND | LAYER_PLATFORM
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


func _unhandled_input(event: InputEvent) -> void:
	buffer_input(event)


## Also called by CombatFx while the world is frozen (hit-stop, super pause).
func buffer_input(event: InputEvent) -> void:
	for action in BUFFERED:
		if event.is_action_pressed(action, false):
			_buffer[action] = BUFFER_TIME


func _take(action: String) -> bool:
	if _buffer.get(action, 0.0) > 0.0:
		_buffer.erase(action)
		return true
	return false


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_tick_move(delta)
	var on_floor := is_on_floor()
	if on_floor:
		jumps_used = 0
		air_dash_used = false

	if in_super:
		velocity.x = 0.0
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		move_and_slide()
		visual.set_state("cast")
		return

	var dir := Input.get_axis("move_left", "move_right")
	var busy := not move.is_empty() or cast_timer > 0.0

	if dash_timer > 0.0:
		velocity = Vector2(facing * DASH_SPEED, 0.0)
		ghost_timer -= delta
		if ghost_timer <= 0.0:
			ghost_timer = 0.04
			world.spawn_ghost(self)
	else:
		var target_speed := dir * RUN_SPEED
		if busy and on_floor:
			target_speed = 0.0
			if not move.is_empty() and MoveSet.phase_at(move, move_t) != "recovery":
				target_speed = float(move.get("lunge", 0.0)) * facing
		elif busy:
			target_speed *= 0.6
		velocity.x = move_toward(velocity.x, target_speed, ACCEL * delta)
		if dir != 0.0 and not busy:
			facing = 1 if dir > 0.0 else -1
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	if move.is_empty():
		_handle_jump(on_floor)
	if _take("dash") and dash_cd <= 0.0 and move.is_empty() and (on_floor or not air_dash_used):
		dash_timer = DASH_TIME
		dash_cd = DASH_COOLDOWN
		ghost_timer = 0.0
		if not on_floor:
			air_dash_used = true
	_handle_attacks(on_floor, dir)
	if _take("super"):
		use_super()
	if _take("cycle_look"):
		get_tree().call_group("character_select", "open_for", visual)
	if _take("toggle_figure"):
		visual.visible = not visual.visible
		sprite.visible = not visual.visible
		world.toast("Figur: " + ("Sammlung" if visual.visible else moveset.display_name))
	if _take("cycle_moveset"):
		cycle_moveset()

	if infinite_aura:
		aura = max_aura
	else:
		aura = minf(max_aura, aura + aura_regen * delta)

	move_and_slide()
	_update_visual()


func _tick_timers(delta: float) -> void:
	for key in _buffer.keys():
		_buffer[key] -= delta
		if _buffer[key] <= 0.0:
			_buffer.erase(key)
	dash_timer = maxf(0.0, dash_timer - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	cast_timer = maxf(0.0, cast_timer - delta)
	for i in cooldowns.size():
		cooldowns[i] = maxf(0.0, cooldowns[i] - delta)
	super_cd = maxf(0.0, super_cd - delta)
	if drop_timer > 0.0:
		drop_timer -= delta
		if drop_timer <= 0.0:
			set_collision_mask_value(LAYER_PLATFORM, true)


func _handle_jump(on_floor: bool) -> void:
	if _buffer.get("jump", 0.0) > 0.0:
		if Input.is_action_pressed("move_down") and on_floor:
			_buffer.erase("jump")
			set_collision_mask_value(LAYER_PLATFORM, false)
			drop_timer = 0.25
			position.y += 2.0
		elif on_floor or jumps_used < MAX_JUMPS:
			_buffer.erase("jump")
			if not on_floor and jumps_used == 0:
				jumps_used = 1  # walked off a ledge: first jump is spent
			if jumps_used >= MAX_JUMPS:
				return
			velocity.y = JUMP_VELOCITY
			_jump_held = true
			jumps_used += 1
			dash_timer = 0.0
			if jumps_used == 2:
				world.spawn_burst(global_position, Color(1, 1, 1, 0.8), 8)
	# releasing early cuts the jump short (once per jump)
	if _jump_held and not Input.is_action_pressed("jump"):
		_jump_held = false
		if velocity.y < -120.0:
			velocity.y *= 0.5


## Direction held right now, relative to facing. Up and down win over sideways.
func _input_dir(dir_x: float) -> String:
	if Input.is_action_pressed("move_up"):
		return "up"
	if Input.is_action_pressed("move_down"):
		return "down"
	if dir_x != 0.0:
		return "forward"
	return "neutral"


func _handle_attacks(on_floor: bool, dir_x: float) -> void:
	var light := _take("light")
	var heavy := _take("heavy")
	var special := _take("special")
	if dash_timer > 0.0 or in_super:
		return
	var d := _input_dir(dir_x)
	# a grab: both buttons together, or the second one right after the first
	if (light and heavy) or (not move.is_empty() and move_t < GRAB_WINDOW
			and ((light and move.button == "heavy") or (heavy and move.button == "light"))):
		_start_move(moveset.pick("grab", "neutral", false))
		return
	var pressed := "light" if light else ("heavy" if heavy else ("special" if special else ""))
	if pressed == "":
		_try_queued(on_floor)
		return
	if move.is_empty() and cast_timer <= 0.0:
		if dir_x != 0.0:
			facing = 1 if dir_x > 0.0 else -1
		_start(pressed, d, on_floor)
	else:
		_queued = pressed
		_queued_dir = d
		_try_queued(on_floor)


## Run a button pressed during a move as soon as the rules allow:
## light chains into the next light from the first active frame on;
## after a hit, light cancels into heavy and anything into special;
## otherwise it waits for the move to end.
func _try_queued(on_floor: bool) -> void:
	if _queued == "" or cast_timer > 0.0:
		return
	if move.is_empty():
		var q := _queued
		_queued = ""
		var dx := Input.get_axis("move_left", "move_right")
		if dx != 0.0:
			facing = 1 if dx > 0.0 else -1
		_start(q, _queued_dir, on_floor)
		return
	var ph := MoveSet.phase_at(move, move_t)
	if ph == "startup":
		return
	var rank := {"light": 0, "heavy": 1, "grab": 1, "special": 2}
	var chain: String = move.get("chain", "")
	if _queued == "light" and chain != "" and _queued_dir == "neutral" and ph == "recovery":
		_queued = ""
		_start_move(moveset.get_move(chain))
	elif move_hit and rank[_queued] > rank[move.button]:
		var q := _queued
		_queued = ""
		move = {}
		_start(q, _queued_dir, on_floor)


## Next fighter (moveset + drawings): test figure 2, then imported ones.
func cycle_moveset() -> void:
	var files := MoveSet.list_files()
	if files.is_empty():
		return
	moveset_index = (moveset_index + 1) % files.size()
	moveset = MoveSet.load_file(files[moveset_index])
	sprite.use_sprite_data(moveset.sprite_data)
	move = {}
	visual.visible = false
	sprite.visible = true
	if world:
		world.toast("Kämpfer: " + moveset.display_name)


func _start(button: String, d: String, on_floor: bool) -> void:
	if button == "special":
		# imported fighters bring their own specials; else the skill slots
		var m := moveset.pick("special", d, not on_floor)
		if not m.is_empty():
			_start_move(m)
		else:
			use_skill(SPECIAL_SLOT[d if on_floor else "air"])
	else:
		_start_move(moveset.pick(button, d, not on_floor))


func _start_move(m: Dictionary) -> void:
	if m.is_empty():
		return
	move = m
	move_t = 0.0
	move_hit = false
	_move_spawned = false
	last_move_name = m.name
	if not is_on_floor() and velocity.y > 0.0:
		velocity.y *= 0.4  # air attacks hang a little


func _tick_move(delta: float) -> void:
	if move.is_empty():
		return
	move_t += delta
	var ph := MoveSet.phase_at(move, move_t)
	if ph != "startup" and not _move_spawned:
		_move_spawned = true
		var hb: Array = move.hitbox
		world.spawn_attack({
			"owner": self, "kind": move.get("draw", "slash"), "element": move.get("element", ""),
			"damage": float(move.damage), "size": Vector2(hb[2], hb[3]), "offset": Vector2(hb[0], hb[1]),
			"follow": true, "life": float(move.active) / MoveSet.FPS,
			"knockback": float(move.get("knockback", 0.0)), "launch": float(move.get("launch", 0.0)),
			"profile": move.get("profile", "light"), "phase": int(move.get("phase", 0)),
			"angle": float(move.get("angle", 0.0)),
		})
	if move_t >= MoveSet.length(move):
		move = {}


## Called by Attack when the current move's hitbox connects.
func on_attack_hit() -> void:
	move_hit = true


func _attack_frame() -> int:
	var ph := MoveSet.phase_at(move, move_t)
	var pose: Array = move.get("pose", {}).get(ph, [3])
	var start := 0.0
	var dur := float(move.startup)
	if ph == "active":
		start = move.startup
		dur = move.active
	elif ph == "recovery":
		start = move.startup + move.active
		dur = move.recovery
	var k := clampf((move_t * MoveSet.FPS - start) / maxf(1.0, dur), 0.0, 0.999)
	return int(pose[int(k * pose.size())])


func use_skill(slot: int) -> void:
	if slot >= build.size() or cast_timer > 0.0:
		return
	var id: String = build[slot]
	var s: Dictionary = GameData.SKILLS[id]
	if cooldowns[slot] > 0.0:
		return
	if not infinite_aura and aura < s.cost:
		world.toast("Zu wenig Aura")
		return
	if not infinite_aura:
		aura -= s.cost
	cooldowns[slot] = s.cooldown
	cast_timer = CAST_TIME
	match s.kind:
		"melee":
			visual.attack_phase = 2
			world.spawn_attack({
				"owner": self, "kind": id, "element": s.element, "damage": s.damage,
				"size": s.size, "offset": Vector2(26, -22), "follow": true, "life": 0.18,
				"knockback": s.knockback,
			})
		"projectile":
			world.spawn_attack({
				"owner": self, "kind": id, "element": s.element, "damage": s.damage,
				"size": s.size, "offset": Vector2(16, -24), "follow": false, "life": s.life,
				"velocity": Vector2(s.speed * facing, 0), "pierce": s.pierce,
				"knockback": s.knockback,
			})
		"chain":
			world.cast_chain(self, s)


func use_super() -> void:
	var s: Dictionary = GameData.SUPER
	if super_cd > 0.0 or cast_timer > 0.0 or dash_timer > 0.0:
		return
	if not infinite_aura and aura < s.cost:
		world.toast("Zu wenig Aura")
		return
	if not infinite_aura:
		aura -= s.cost
	super_cd = s.cooldown
	in_super = true
	velocity.x = 0.0
	visual.set_state("cast")
	world.cast_super(self, s)


func reset_cooldowns() -> void:
	super_cd = 0.0
	for i in cooldowns.size():
		cooldowns[i] = 0.0
	dash_cd = 0.0


func _update_visual() -> void:
	visual.scale.x = facing
	sprite.scale.x = facing
	var st := "idle"
	if dash_timer > 0.0:
		st = "dash"
	elif not move.is_empty():
		st = "attack"
		visual.attack_phase = int(move.get("phase", 0))
		sprite.attack_strip = move.get("strip", "slash")
		sprite.attack_frame = _attack_frame()
	elif cast_timer > 0.0:
		st = "cast"
	elif not is_on_floor():
		st = "jump" if velocity.y < 0.0 else "fall"
	elif absf(velocity.x) > 10.0:
		st = "run"
	visual.set_state(st)
	sprite.set_state(st)


func combat_power() -> int:
	var total := 0.0
	for id in build:
		total += GameData.SKILLS[id].damage
	return int(total * 10.0 + max_hp * 0.2)
