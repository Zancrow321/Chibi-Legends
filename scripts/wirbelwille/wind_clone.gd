class_name WindClone
extends Node2D
## A Windschatten: a copy of the creator figure made of wind. It only acts
## when a Zug calls it: it plays a short script of timed steps (pose, move,
## hit, ...) and vanishes after it ("POFF"), when an enemy hits it, or at the
## latest after 3 s. Pale blue, see-through, with a glowing blue outline so
## it is always told apart from the real figure.

const MAX_LIFE := 3.0
const TINT := Color(0.62, 0.92, 1.0, 0.72)

var caster: Node  # WirbelCaster
var world: TrainingRoom
var wfx: WirbelFx
var facing := 1
var vel := Vector2.ZERO
var gravity := false
var lure := false   # enemies go for it (Klonköder)
var steps: Array = []  # [[time, Callable], ...] run in order
var life := 0.0
var gone := false

var sprite: FighterSprite
var _t := 0.0
var _i := 0
var _glow_t := 0.0


func _ready() -> void:
	add_to_group("decoys")
	if lure:
		add_to_group("lures")
	sprite = FighterSprite.new()
	add_child(sprite)
	var look: Dictionary = CreatorCatalog.load_look()
	look["weapon"] = ""
	sprite.set_look(look)
	sprite.modulate = TINT
	sprite.scale.x = facing
	z_index = -1
	wfx.anim("windschatten_entstehen", global_position + Vector2(0, -24), 70.0, -1.0, 0.0, false, Color(1, 1, 1, 0.9), 1.6)
	wfx.ring(global_position + Vector2(0, -22), 26.0, WirbelFx.TURQ, 0.25, 2.0)
	pose("idle")


func get_hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-8, -42), Vector2(16, 42))


## Sets the shown pose: a creator pose name ("jab_hit") or a state ("run").
func pose(name: String, phase := "active", power := 1.2) -> void:
	if sprite == null:
		return
	if name in ["idle", "run", "jump", "fall", "dash"]:
		sprite.set_state(name)
		sprite.attack_phase = ""
	else:
		sprite.set_state("attack")
		sprite.attack_pose = name
		sprite.attack_phase = phase
		sprite.attack_k = 0.5
		sprite.attack_power = power


func turn(dir: int) -> void:
	facing = dir
	if sprite != null:
		sprite.scale.x = dir


## An enemy (or an area attack) reached the clone: it vanishes.
func struck() -> void:
	vanish()


func vanish() -> void:
	if gone:
		return
	gone = true
	var c := global_position + Vector2(0, -22)
	wfx.anim("poff", c + Vector2(0, -4), 56.0, -1.0, 0.0, randf() < 0.5)
	wfx.word(c + Vector2(0, -30), "POFF", WirbelFx.ICE, 14)
	wfx.motes(c, 5, 10.0, WirbelFx.ICE, 0.5)
	Sfx.play("dash", -10.0)
	if caster != null and caster.has_method("clone_gone"):
		caster.clone_gone(self)
	queue_free()


func _physics_process(delta: float) -> void:
	if gone:
		return
	_t += delta
	life += delta
	while _i < steps.size() and _t >= float(steps[_i][0]):
		var cb: Callable = steps[_i][1]
		_i += 1
		if cb.is_valid():
			cb.call(self)
		if gone:
			return
	if gravity:
		vel.y = minf(vel.y + Player.GRAVITY * delta, Player.MAX_FALL)
	global_position += vel * delta
	if gravity and vel.y >= 0.0:
		var gy := GlutHazard.ground_y(global_position.x, global_position.y - 4.0)
		if global_position.y >= gy:
			global_position.y = gy
			vel.y = 0.0
			vel.x = move_toward(vel.x, 0.0, 900.0 * delta)
	# soft blue glow around the copy (afterimage of itself, additive)
	_glow_t -= delta
	if _glow_t <= 0.0 and sprite != null:
		_glow_t = 0.03
		var fast := vel.length() > 150.0
		world.afterimages.add(sprite.snapshot(), Color(0.35, 0.85, 1.0, 0.55 if fast else 0.35), Vector2.ZERO, 0.12 if fast else 0.05)
	if randf() < 0.15:
		wfx.motes(global_position + Vector2(randf_range(-6, 6), -randf_range(4, 40)), 1, 2.0, WirbelFx.ICE, 0.4)
	if life >= MAX_LIFE or (_i >= steps.size() and _t > 0.0 and steps.size() > 0 and _t > float(steps.back()[0]) + 0.6):
		vanish()
