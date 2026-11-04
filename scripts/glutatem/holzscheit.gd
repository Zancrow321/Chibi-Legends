class_name Holzscheit
extends Node2D
## A log thrown by the sparring post. Hurts the player, can be burnt
## (Funkenschild, Konter) or thrown back burning (Spiegelschmiede): then it
## flies at the targets and sets them on fire.

const GRAVITY := 520.0
const DAMAGE := 30.0

var world: TrainingRoom
var vel := Vector2.ZERO
var reflected := false
var _owner: Node = null
var _hit: Dictionary = {}
var _rot := 0.0
var _life := 3.0
var _emit := 0.0


func _ready() -> void:
	add_to_group("enemy_projectiles")


func get_hurt_rect() -> Rect2:
	return Rect2(global_position - Vector2(8, 5), Vector2(16, 10))


## Burnt by fire: crumbles into embers.
func burn() -> void:
	if world.glut_fx != null:
		var fx := world.glut_fx
		fx.flame(global_position, 9.0, Vector2(0, -50), 0.4)
		fx.embers(global_position, 8, 6.0, 50.0, 0.9)
		fx.smoke(global_position, 10.0, Vector2(0, -20), 1.2)
		fx.sparks(global_position, -PI / 2.0, 1.4, 10, 160.0, 0.4)
	queue_free()


## Thrown back: it flies at the post (or straight ahead) and burns.
func reflect(by: Node) -> void:
	reflected = true
	_owner = by
	remove_from_group("enemy_projectiles")
	vel = Vector2(-vel.x * 1.3, -160.0)
	if absf(vel.x) < 200.0:
		vel.x = signf(vel.x if vel.x != 0.0 else 1.0) * 260.0
	_life = 2.0
	if world.glut_fx != null:
		world.glut_fx.word(global_position + Vector2(0, -20), "ZURÜCK!", Color("ffd25c"), 22)


func _physics_process(delta: float) -> void:
	_life -= delta
	vel.y += GRAVITY * delta
	global_position += vel * delta
	_rot += delta * (14.0 if vel.x > 0.0 else -14.0)
	if reflected:
		_emit -= delta
		if _emit <= 0.0 and world.glut_fx != null:
			_emit = 0.03
			world.glut_fx.flame(global_position, 6.0, Vector2(-vel.x * 0.1, -30), 0.3)
			world.glut_fx.glow(global_position, GlutFx.heat(0.7), 12.0, 0.2)
		var hits := GlutHazard.strike(world, get_hurt_rect().grow(4), 24.0, global_position.x - vel.x, 160.0, "heavy", 120.0, _hit)
		if hits.size() > 0:
			if _owner != null and is_instance_valid(_owner) and _owner.has_method("on_zug_hit"):
				_owner.on_zug_hit("ambosshaltung", hits)
			burn()
			return
	else:
		var p := world.player
		if get_hurt_rect().intersects(p.get_hurt_rect()):
			p.receive_hit(DAMAGE, global_position.x - vel.x * 0.05, self)
			if is_instance_valid(self) and not is_queued_for_deletion() and not reflected:
				_break()
			return
	if global_position.y >= GlutHazard.ground_y(global_position.x, global_position.y - 8.0) or _life <= 0.0:
		_break()
	queue_redraw()


func _break() -> void:
	if world.glut_fx != null:
		world.glut_fx.word(global_position + Vector2(0, -14), "KRACK", Color("e8d8c0"), 16)
		world.glut_fx.smoke(global_position, 6.0, Vector2(0, -10), 0.6)
	world.spawn_burst(global_position, Color("a8744a"), 6)
	queue_free()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, _rot, Vector2.ONE)
	draw_rect(Rect2(-8, -4, 16, 8), Color("1a1020"))
	draw_rect(Rect2(-7, -3, 14, 6), Color("8a5a34") if not reflected else Color("5a2a14"))
	draw_rect(Rect2(-7, -3, 14, 2), Color("a8744a") if not reflected else GlutFx.heat(0.6))
	draw_rect(Rect2(5, -3, 2, 6), Color("e0b878"))
	if reflected:
		draw_rect(Rect2(-6, 1, 10, 1), GlutFx.heat(0.85))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
