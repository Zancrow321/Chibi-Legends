class_name Player
extends CharacterBody2D
## Player character: movement (run, double jump, dash, drop-through),
## 3-hit katana combo and four equipped skills paid with Aura.

const GRAVITY := 980.0
const MAX_FALL := 520.0
const RUN_SPEED := 140.0
const ACCEL := 1500.0
const JUMP_VELOCITY := -345.0
const MAX_JUMPS := 2
const DASH_SPEED := 380.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.55
const ATTACK_COOLDOWN := 0.26
const COMBO_WINDOW := 0.6
const CAST_TIME := 0.22

const LAYER_GROUND := 1
const LAYER_PLATFORM := 2

var world: Node  # TrainingRoom (spawns attacks, numbers, fx)
var visual: ChibiVisual

var facing := 1
var jumps_used := 0
var dash_timer := 0.0
var dash_cd := 0.0
var attack_timer := 0.0
var attack_cd := 0.0
var combo := 0
var combo_timer := 0.0
var cast_timer := 0.0
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
const BUFFERED := ["jump", "dash", "attack", "skill_1", "skill_2", "skill_3", "skill_4", "super", "cycle_look"]
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
	add_child(visual)


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
	var on_floor := is_on_floor()
	if on_floor:
		jumps_used = 0

	if in_super:
		velocity.x = 0.0
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		move_and_slide()
		visual.set_state("cast")
		return

	var dir := Input.get_axis("move_left", "move_right")

	if dash_timer > 0.0:
		velocity = Vector2(facing * DASH_SPEED, 0.0)
		ghost_timer -= delta
		if ghost_timer <= 0.0:
			ghost_timer = 0.04
			world.spawn_ghost(self)
	else:
		var target_speed := dir * RUN_SPEED
		if (attack_timer > 0.0 or cast_timer > 0.0) and on_floor:
			target_speed *= 0.35
		velocity.x = move_toward(velocity.x, target_speed, ACCEL * delta)
		if dir != 0.0 and attack_timer <= 0.0 and cast_timer <= 0.0:
			facing = 1 if dir > 0.0 else -1
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	_handle_jump(on_floor)
	if _take("dash") and dash_cd <= 0.0:
		dash_timer = DASH_TIME
		dash_cd = DASH_COOLDOWN
		ghost_timer = 0.0
	if _take("attack") and attack_cd <= 0.0 and dash_timer <= 0.0:
		_basic_attack()
	for i in 4:
		if _take("skill_%d" % (i + 1)):
			use_skill(i)
	if _take("super"):
		use_super()
	if _take("cycle_look"):
		get_tree().call_group("character_select", "open_for", visual)

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
	attack_timer = maxf(0.0, attack_timer - delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	cast_timer = maxf(0.0, cast_timer - delta)
	combo_timer = maxf(0.0, combo_timer - delta)
	if combo_timer <= 0.0:
		combo = 0
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


func _basic_attack() -> void:
	attack_cd = ATTACK_COOLDOWN
	attack_timer = 0.2
	visual.attack_phase = combo
	var dmg: float = GameData.COMBO_DAMAGE[combo]
	var finisher := combo == 2
	world.spawn_attack({
		"owner": self, "kind": "slash", "element": "", "damage": dmg,
		"size": Vector2(40, 34) if finisher else Vector2(34, 30),
		"offset": Vector2(22, -20), "follow": true, "life": 0.12,
		"knockback": 180.0 if finisher else 60.0, "phase": combo,
	})
	combo = (combo + 1) % 3
	combo_timer = COMBO_WINDOW


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
			attack_timer = 0.22
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
	if dash_timer > 0.0:
		visual.set_state("dash")
	elif attack_timer > 0.0:
		visual.set_state("attack")
	elif cast_timer > 0.0:
		visual.set_state("cast")
	elif not is_on_floor():
		visual.set_state("jump" if velocity.y < 0.0 else "fall")
	elif absf(velocity.x) > 10.0:
		visual.set_state("run")
	else:
		visual.set_state("idle")


func combat_power() -> int:
	var total := 0.0
	for id in build:
		total += GameData.SKILLS[id].damage
	return int(total * 10.0 + max_hp * 0.2)
