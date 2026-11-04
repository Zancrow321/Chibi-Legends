class_name Player
extends CharacterBody2D
## Player character: movement (run, double jump, dash, air dash, drop-through)
## and the fighter controls: light, heavy and special, each with a direction
## (neutral, forward, up, down, air). Light + heavy together is a grab.
## Normal attacks come from a MoveSet (frame data in JSON); specials use the
## four skill slots: neutral, forward, up, down (air = neutral).
## With a fighting style (Glutatem) the moveset comes from the style, the
## special button runs the style's Züge (GlutCaster) and the super is the
## style's Meisterzug, paid with the Legendenleiste (3 Stufen of 100).

const GRAVITY := 980.0
const MAX_FALL := 520.0
const RUN_SPEED := 140.0
const ACCEL := 1500.0
const JUMP_VELOCITY := -345.0
const MAX_JUMPS := 2
const DASH_SPEED := 380.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.3
## Feel: jumping just after leaving a ledge still counts as a ground jump;
## gravity is lighter near the top of a held jump and heavier when falling.
const COYOTE_TIME := 0.1
const APEX_SPEED := 70.0
const APEX_GRAVITY := 0.55
const FALL_GRAVITY := 1.3
## Ground attacks: a little steering in recovery, turning in the first frames.
const ATTACK_DRIFT := 0.3
const TURN_FRAMES := 4
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
var moveset_index := 0  # into MoveSet.list_files(), switched with F
## Fighting style (J/K moveset, Züge, Meisterzug) and its runner.
var style: FightingStyle
var glut: GlutCaster

## Legendenleiste: 3 Stufen of 100. Fills with hits, counters and taking hits.
const GAUGE_MAX := 300.0
var gauge := 0.0
## Hit by an enemy: no control for a moment, then a short invulnerability.
var hitstun := 0.0
var hurt_invuln := 0.0

## Guard (Q / right trigger): holding it on the ground blocks hits from the
## front (25 % damage, no stagger). Pressed just before a hit = Perfekt-Block:
## no damage, the attacker staggers, +15 Leiste. The dash is invulnerable;
## dodging a hit with it = Ausweichen (+5 Leiste). Dash while staggered =
## Befreiungsstoß (1 Stufe): breaks free and pushes enemies away.
const PERFECT_WINDOW := 0.14
const BLOCK_FACTOR := 0.25
const BREAKER_COST := 100.0
var blocking := false
var _block_t := 99.0  # seconds since the guard was pressed
var _guard_flash := 0.0
var _dodge_t := 0.0
var guard_fx: Node2D

var facing := 1
var jumps_used := 0
var dash_timer := 0.0
var dash_cd := 0.0
var air_dash_used := false
var _coyote := 0.0
var _fall_speed := 0.0
var _step_timer := 0.0
var _was_on_floor := true
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
	guard_fx = Node2D.new()
	guard_fx.z_index = 6
	guard_fx.draw.connect(_draw_guard)
	add_child(guard_fx)
	add_to_group("profile_user")
	apply_profile(true)
	style = FightingStyle.load_style(str(CreatorCatalog.load_look().get("style", "glutatem")))
	if style.moveset_path() != "":
		moveset = MoveSet.load_file(style.moveset_path())


## Called by the room once the effects exist.
func init_style() -> void:
	if style == null or style.zuege.is_empty():
		return
	if style.data.get("caster", "") == "schwarzmond":
		glut = MondCaster.new()
	elif style.id == "gleichklang":
		glut = KlangCaster.new()
	elif style.id == "spannkraft":
		glut = FederCaster.new()
	elif style.id == "wirbelwille":
		glut = WirbelCaster.new()
	else:
		glut = GlutCaster.new()
	add_child(glut)
	glut.setup(self, style)


func _glut_busy() -> bool:
	return glut != null and glut.busy()


func add_gauge(amount: float) -> void:
	if in_super:
		return
	if amount > 0.0:
		amount *= 1.0 + Profile.bonus("gauge")
	gauge = clampf(gauge + amount, 0.0, GAUGE_MAX)


func get_hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-8, -42), Vector2(16, 42))


## An enemy attack reached the player. Returns true when it did damage
## (false: countered, invulnerable or in a super).
func receive_hit(damage: float, from_x: float, source: Node = null) -> bool:
	if in_super or hurt_invuln > 0.0 or (glut != null and glut.invuln > 0.0):
		return false
	if dash_timer > 0.0:
		_dodged()
		return false
	if glut != null and glut.try_counter(from_x, source if source != null and source.has_method("burn") else null):
		return false
	if glut != null and glut.guard_hit(damage, from_x, source):
		return true
	var dir := signf(global_position.x - from_x)
	if dir == 0.0:
		dir = -facing
	# guard: only against hits from the front
	if blocking and signf(from_x - global_position.x) * facing >= 0.0:
		if _block_t <= PERFECT_WINDOW:
			_perfect_block(source)
			return false
		_block_hit(damage, dir)
		return true
	hp = maxf(0.0, hp - damage)
	hitstun = 0.32
	hurt_invuln = 0.7
	velocity = Vector2(dir * 170.0, -140.0)
	move = {}
	_queued = ""
	if glut != null:
		glut.interrupt()
	sprite.flash = 0.06
	world.numbers.spawn_number(global_position + Vector2(0, -50), int(damage), Color("ff4b3e"), get_instance_id(), false)
	world.fx.hit(global_position + Vector2(0, -22), "", "heavy", dir)
	Sfx.play("hit_heavy")
	add_gauge(5.0)
	if hp <= 0.0:
		hp = max_hp
		world.toast("Getroffen! Im Training geht es mit voller HP weiter")
	return true


func _block_hit(damage: float, dir: float) -> void:
	var dmg := maxf(1.0, damage * BLOCK_FACTOR)
	hp = maxf(1.0, hp - dmg)  # blocking never knocks you out
	velocity.x = dir * 90.0
	_guard_flash = 0.18
	world.numbers.spawn_number(global_position + Vector2(0, -50), int(dmg), Color("9ab8ff"), get_instance_id(), false)
	world.fx.hit(global_position + Vector2(facing * 12.0, -24), "", "light", dir)
	world.effects.burst(global_position + Vector2(facing * 14.0, -24), Color("9ab8ff"), 8, 120.0, 0.0)
	Sfx.play("hit_blade", -2.0)
	add_gauge(3.0)


func _perfect_block(source: Node) -> void:
	_guard_flash = 0.35
	var c := global_position + Vector2(facing * 14.0, -26)
	world.fx.blast(c, Color("fff4d0"), 40.0, "heavy")
	world.effects.ring(c, 34.0, Color("fff4d0"))
	if world.glut_fx != null:
		world.glut_fx.word(c + Vector2(0, -36), "PERFEKT!", Color("fff4d0"), 26)
	Sfx.play("hit_heavy")
	add_gauge(15.0)
	if source != null and source.has_method("parried"):
		source.parried(global_position.x)
	hurt_invuln = maxf(hurt_invuln, 0.25)


func _dodged() -> void:
	if _dodge_t > 0.0:
		return  # one "AUSGEWICHEN" per dash
	_dodge_t = 0.25
	if world.glut_fx != null:
		world.glut_fx.word(global_position + Vector2(0, -64), "AUSGEWICHEN!", Color("9ef0ff"), 18)
	world.spawn_ghost(self)
	add_gauge(5.0)


## Befreiungsstoß: breaks out of a stagger for 1 Stufe of the Leiste.
func _breaker() -> void:
	gauge = maxf(0.0, gauge - BREAKER_COST) if not infinite_aura else gauge
	hitstun = 0.0
	hurt_invuln = 0.6
	velocity = Vector2(0, -120)
	var c := global_position + Vector2(0, -24)
	world.fx.blast(c, Color("ff9a2a"), 70.0, "heavy")
	world.effects.ring(c, 60.0, Color("ffd25c"))
	if world.glut_fx != null:
		world.glut_fx.word(c + Vector2(0, -40), "BEFREIT!", Color("ffd25c"), 24)
		world.glut_fx.sparks(c, 0.0, PI, 26, 260.0)
	for t in get_tree().get_nodes_in_group("enemies"):
		var d: Vector2 = t.global_position - global_position
		if d.length() < 90.0 and t.has_method("take_hit"):
			t.take_hit(220.0, global_position.x)
	Sfx.play("super_flash", -6.0)


func _draw_guard() -> void:
	var a := 0.0
	if blocking:
		a = 0.55
	a = maxf(a, _guard_flash * 3.0)
	if a <= 0.0:
		return
	var perfect := blocking and _block_t <= PERFECT_WINDOW
	var col := Color("fff4d0") if perfect or _guard_flash > 0.2 else Color("9ab8ff")
	var c := Vector2(facing * 10.0, -24)
	var from := -1.2 if facing > 0 else PI - 1.2
	guard_fx.draw_arc(c, 22.0, from, from + 2.4, 16, Color(col, a * 0.35), 7.0)
	guard_fx.draw_arc(c, 22.0, from, from + 2.4, 16, Color(col, a), 2.0)


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
	if glut != null:
		glut.tick(delta)
	var on_floor := is_on_floor()
	if on_floor:
		jumps_used = 0
		air_dash_used = false
		_coyote = COYOTE_TIME
		if not _was_on_floor:
			var hard := clampf(_fall_speed / MAX_FALL, 0.3, 1.0)
			sprite.land(hard)
			world.dust.land(global_position, hard)
			Sfx.play("land", -8.0 + hard * 6.0)
		elif absf(velocity.x) > 60.0 and dash_timer <= 0.0 and move.is_empty():
			_step_timer -= get_physics_process_delta_time()
			if _step_timer <= 0.0:
				_step_timer = 0.21
				world.dust.puff(global_position, -signf(velocity.x), 2, 2.2, 18.0)
				Sfx.play("footstep")
	_was_on_floor = on_floor
	_fall_speed = maxf(velocity.y, 0.0)
	if infinite_aura:
		gauge = GAUGE_MAX

	if hitstun > 0.0 and _take("dash") and (gauge >= BREAKER_COST or infinite_aura):
		_breaker()
	if hitstun > 0.0:
		blocking = false
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		move_and_slide()
		_update_visual()
		return

	if in_super:
		velocity.x = 0.0
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		move_and_slide()
		visual.set_state("cast")
		return

	var dir := Input.get_axis("move_left", "move_right")
	if _glut_busy():
		# a Zug drives the body; buttons pressed meanwhile are queued
		velocity = glut.drive_velocity(velocity, delta, on_floor)
		_handle_attacks(on_floor, dir)
		move_and_slide()
		_update_visual()
		return
	var busy := not move.is_empty() or cast_timer > 0.0
	# guard: only on the ground and outside of attacks
	var want_block := Input.is_action_pressed("block") and on_floor and not busy and dash_timer <= 0.0
	if want_block and not blocking:
		_block_t = 0.0
	blocking = want_block
	if blocking:
		velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
		velocity.y = minf(velocity.y + _gravity() * delta, MAX_FALL)
		if dir != 0.0:
			facing = 1 if dir > 0.0 else -1
		if _buffer.get("dash", 0.0) <= 0.0:
			move_and_slide()
			_update_visual()
			return
		blocking = false  # dash out of the guard

	if dash_timer > 0.0:
		velocity = Vector2(facing * DASH_SPEED, 0.0)
		ghost_timer -= delta
		if ghost_timer <= 0.0:
			ghost_timer = 0.04
			world.spawn_ghost(self)
	else:
		var target_speed := dir * RUN_SPEED
		if busy and on_floor:
			target_speed *= ATTACK_DRIFT
			if not move.is_empty() and MoveSet.phase_at(move, move_t) != "recovery":
				target_speed = float(move.get("lunge", 0.0)) * facing
		elif busy:
			target_speed *= 0.6
		velocity.x = move_toward(velocity.x, target_speed, ACCEL * delta)
		if dir != 0.0 and (not busy or _can_turn()):
			facing = 1 if dir > 0.0 else -1
		velocity.y = minf(velocity.y + _gravity() * delta, MAX_FALL)

	if move.is_empty() or _can_cancel():
		_handle_jump(on_floor)
	if _buffer.get("dash", 0.0) > 0.0 and dash_cd <= 0.0 and (move.is_empty() or _can_cancel()) \
			and (on_floor or not air_dash_used):
		_take("dash")
		_cancel_move()
		if dir != 0.0:
			facing = 1 if dir > 0.0 else -1
		dash_timer = DASH_TIME
		dash_cd = DASH_COOLDOWN
		Sfx.play("dash")
		if on_floor:
			world.dust.puff(global_position, -facing, 5, 3.0, 70.0)
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
	_block_t += delta
	_guard_flash = maxf(0.0, _guard_flash - delta)
	_dodge_t = maxf(0.0, _dodge_t - delta)
	guard_fx.queue_redraw()
	_coyote = maxf(0.0, _coyote - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	cast_timer = maxf(0.0, cast_timer - delta)
	for i in cooldowns.size():
		cooldowns[i] = maxf(0.0, cooldowns[i] - delta)
	super_cd = maxf(0.0, super_cd - delta)
	hitstun = maxf(0.0, hitstun - delta)
	hurt_invuln = maxf(0.0, hurt_invuln - delta)
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
				# walked off a ledge: within the coyote time it is still the
				# ground jump, later the first jump is spent
				if _coyote <= 0.0:
					jumps_used = 1
			if jumps_used >= MAX_JUMPS:
				return
			_cancel_move()
			velocity.y = JUMP_VELOCITY
			_jump_held = true
			_coyote = 0.0
			jumps_used += 1
			dash_timer = 0.0
			sprite.jump()
			Sfx.play("jump", -4.0)
			if on_floor or jumps_used == 1:
				world.dust.puff(global_position, 0.0, 4, 2.5, 0.0)
			if jumps_used == 2:
				world.spawn_burst(global_position, Color(1, 1, 1, 0.8), 8)
	# releasing early cuts the jump short (once per jump)
	if _jump_held and not Input.is_action_pressed("jump"):
		_jump_held = false
		if velocity.y < -120.0:
			velocity.y *= 0.5


## Lighter gravity at the top of a held jump (hang time), heavier when falling.
func _gravity() -> float:
	if velocity.y > 0.0:
		return GRAVITY * FALL_GRAVITY
	if _jump_held and absf(velocity.y) < APEX_SPEED:
		return GRAVITY * APEX_GRAVITY
	return GRAVITY


## Jump and dash may cancel a normal once it has hit (not specials).
func _can_cancel() -> bool:
	return not move.is_empty() and move_hit and move.button != "special" \
		and MoveSet.phase_at(move, move_t) != "startup"


## Facing can still change in the first frames of a move (reverse attacks).
func _can_turn() -> bool:
	return not move.is_empty() and move_t * MoveSet.FPS < TURN_FRAMES


func _cancel_move() -> void:
	if not move.is_empty():
		move = {}
		_queued = ""


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
	if _glut_busy():
		var p := "light" if light else ("heavy" if heavy else "")
		if p != "":
			_queued = p
			_queued_dir = d
		return
	# a grab: both buttons together, or the second one right after the first
	if (light and heavy) or (not move.is_empty() and move_t < GRAB_WINDOW
			and ((light and move.button == "heavy") or (heavy and move.button == "light"))):
		_start_move(moveset.pick("grab", "neutral", false))
		return
	var pressed := "light" if light else ("heavy" if heavy else ("special" if special else ""))
	if pressed == "":
		_try_queued(on_floor)
		return
	if move.is_empty() and cast_timer <= 0.0 and not _glut_busy():
		if dir_x != 0.0:
			facing = 1 if dir_x > 0.0 else -1
		_start(pressed, d, on_floor)
	else:
		_queued = pressed
		_queued_dir = d
		_try_queued(on_floor)


## Run a button pressed during a move as soon as the rules allow:
## light chains into the next light once it hit (or in recovery on a whiff);
## after a hit, light cancels into heavy and anything into special;
## otherwise it waits for the move to end.
func _try_queued(on_floor: bool) -> void:
	if _queued == "" or cast_timer > 0.0 or _glut_busy():
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
	if _queued == "light" and chain != "" and _queued_dir == "neutral" and (ph == "recovery" or move_hit):
		_queued = ""
		_start_move(moveset.get_move(chain))
	elif move_hit and rank[_queued] > rank[move.button]:
		var q := _queued
		_queued = ""
		move = {}
		_start(q, _queued_dir, on_floor)


## Next fighter: the own one (test figure 2 with its fighting style), then
## every imported fighter (movesets with their own drawings).
func cycle_moveset() -> void:
	var own := "res://assets/combat/movesets/testfigur2.json"
	if style != null and style.moveset_path() != "":
		own = style.moveset_path()
	var files := PackedStringArray([own])
	for f in MoveSet.list_files():
		if f != own and not MoveSet.load_file(f).sprite_data.is_empty():
			files.append(f)
	moveset_index = (moveset_index + 1) % files.size()
	moveset = MoveSet.load_file(files[moveset_index])
	sprite.use_sprite_data(moveset.sprite_data)
	move = {}
	visual.visible = false
	sprite.visible = true
	if world:
		world.toast("Kämpfer: " + ("Testfigur 2" if moveset_index == 0 else moveset.display_name))


func _start(button: String, d: String, on_floor: bool) -> void:
	if button == "special":
		# imported fighters bring their own specials; else the style's Züge
		# (Glutatem) or the skill slots
		var m := moveset.pick("special", d, not on_floor)
		if not m.is_empty():
			_start_move(m)
		elif glut != null:
			glut.cast(d)
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
	move_t += delta * (glut.normal_speed() if glut != null else 1.0)
	var ph := MoveSet.phase_at(move, move_t)
	if ph != "startup" and not _move_spawned:
		_move_spawned = true
		var heavy_swing: bool = move.button == "heavy" or move.get("profile", "") == "heavy"
		Sfx.play("swing_heavy" if heavy_swing else "swing_light")
		var hb: Array = move.hitbox
		var el: String = move.get("element", "")
		var mul := 1.0
		var trail := Color("7fd8ff")
		if glut != null:
			if glut.normal_element() != "":
				el = glut.normal_element()
			mul = glut.normal_mul()
			trail = glut.trail_color()
		# bigger weapons reach further: the box grows forward, its back edge stays
		var r := sprite.reach() if move.button != "grab" else 1.0
		var w := float(hb[2]) * r
		var ox := float(hb[0]) + (w - float(hb[2])) * 0.5
		world.spawn_attack({
			"owner": self, "kind": move.get("draw", "slash"), "element": el, "trail": trail,
			"damage": float(move.damage) * mul, "size": Vector2(w, hb[3]), "offset": Vector2(ox, hb[1]),
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
	add_gauge(4.0)
	if glut != null:
		glut.on_normal_hit()


## Phase and progress for the sprite's code animation; heavy moves lean
## further and leave afterimages while they strike.
func _set_attack_feel() -> void:
	var ph := MoveSet.phase_at(move, move_t)
	var f := move_t * MoveSet.FPS
	var start := 0.0
	var dur := float(move.startup)
	if ph == "active":
		start = move.startup
		dur = move.active
	elif ph == "recovery":
		start = move.startup + move.active
		dur = move.recovery
	sprite.attack_phase = ph
	sprite.attack_k = clampf((f - start) / maxf(1.0, dur), 0.0, 1.0)
	var heavy: bool = move.button == "heavy" or move.get("profile", "") == "heavy"
	sprite.attack_power = 1.6 if heavy else 1.0
	if heavy and ph == "active" and absf(velocity.x) > 60.0:
		ghost_timer -= get_physics_process_delta_time()
		if ghost_timer <= 0.0:
			ghost_timer = 0.03
			world.spawn_ghost(self)


## Creator pose for the current move frame: the move's "creator" lists per
## phase, else the old strip frame translated.
func _attack_pose() -> String:
	var ph := MoveSet.phase_at(move, move_t)
	var list: Array = move.get("creator", {}).get(ph, [])
	if list.is_empty():
		return FighterSprite.SLASH_POSE[clampi(sprite.attack_frame, 0, FighterSprite.SLASH_POSE.size() - 1)]
	return str(list[mini(int(sprite.attack_k * list.size()), list.size() - 1)])


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
	if glut != null:
		_use_meisterzug()
		return
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
	Sfx.play("super_flash")
	world.cast_super(self, s)


## Meisterzug of the fighting style: costs 3 Stufen of the Legendenleiste.
func _use_meisterzug() -> void:
	if in_super or _glut_busy() or dash_timer > 0.0:
		return
	var cost := style.super_cost()
	var mond := glut as MondCaster
	if mond != null and style.super_variant == "mondfinsternis" and mond.eclipse_used:
		world.toast("Mondfinsternis gibt es nur einmal pro Kampf (R setzt zurück)")
		return
	if not infinite_aura and gauge < cost:
		world.toast("Legendenleiste: %d von 3 Stufen" % int(gauge / 100.0))
		return
	if not infinite_aura:
		gauge -= cost
	in_super = true
	velocity.x = 0.0
	move = {}
	_queued = ""
	Sfx.play("super_flash")
	if mond != null:
		var ms := MondSuper.new()
		ms.room = world
		ms.player = self
		ms.caster = mond
		ms.fx = world.glut_fx
		ms.variant = style.super_variant
		ms.title = style.variant().get("name", "Meisterzug")
		world.add_child(ms)
		return
	if glut is WirbelCaster:
		var ws := WirbelSuper.new()
		ws.room = world
		ws.player = self
		ws.caster = glut
		ws.wfx = glut.wfx
		ws.variant = style.super_variant
		ws.title = style.variant().get("name", "Meisterzug")
		world.add_child(ws)
		return
	if glut is FederCaster:
		var fs := FederSuper.new()
		fs.room = world
		fs.player = self
		fs.caster = glut
		fs.ffx = glut.ffx
		fs.variant = style.super_variant
		fs.title = style.variant().get("name", "Meisterzug")
		world.add_child(fs)
		return
	if glut is KlangCaster:
		var ks := KlangSuper.new()
		ks.room = world
		ks.player = self
		ks.caster = glut
		ks.kfx = glut.kfx
		ks.variant = style.super_variant
		ks.title = style.variant().get("name", "Meisterzug")
		world.add_child(ks)
		return
	var s := GlutSuper.new()
	s.room = world
	s.player = self
	s.caster = glut
	s.fx = world.glut_fx
	s.variant = style.super_variant
	s.title = style.variant().get("name", "Meisterzug")
	world.add_child(s)


func reset_cooldowns() -> void:
	if glut != null:
		for z in glut.cooldowns:
			glut.cooldowns[z] = 0.0
		glut.reset_fight()
	super_cd = 0.0
	for i in cooldowns.size():
		cooldowns[i] = 0.0
	dash_cd = 0.0


func _update_visual() -> void:
	visual.scale.x = facing
	sprite.scale.x = facing
	var st := "idle"
	sprite.attack_phase = ""
	if hitstun > 0.0:
		st = "hurt"
	elif _glut_busy():
		st = "attack"
		sprite.attack_frame = glut.pose_frame()
		var named := glut.pose_name()
		sprite.attack_pose = named if named != "" else FighterSprite.SLASH_POSE[clampi(sprite.attack_frame, 0, FighterSprite.SLASH_POSE.size() - 1)]
	elif dash_timer > 0.0:
		st = "dash"
	elif not move.is_empty():
		st = "attack"
		visual.attack_phase = int(move.get("phase", 0))
		sprite.attack_strip = move.get("strip", "slash")
		sprite.attack_frame = _attack_frame()
		_set_attack_feel()
		sprite.attack_pose = _attack_pose()
	elif cast_timer > 0.0:
		st = "cast"
	elif not is_on_floor():
		st = "jump" if velocity.y < 0.0 else "fall"
	elif absf(velocity.x) > 10.0:
		st = "run"
	visual.set_state("cast" if st == "hurt" else st)
	sprite.set_state(st)
	# blink while invulnerable after a hit
	sprite.modulate.a = 0.55 if hurt_invuln > 0.0 and hitstun <= 0.0 and fmod(hurt_invuln, 0.12) < 0.06 else 1.0


## Level and worn gear from the Profile: max HP (and full HP when refill).
func apply_profile(refill := false) -> void:
	level = Profile.level
	var frac := hp / max_hp
	max_hp = roundf(1200.0 * (1.0 + Profile.bonus("hp")))
	hp = max_hp if refill else max_hp * frac


func combat_power() -> int:
	var total := 0.0
	for id in build:
		total += GameData.SKILLS[id].damage
	return int(total * 10.0 * (1.0 + Profile.bonus("atk")) + max_hp * 0.2 + Profile.gear_score())
