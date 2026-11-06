class_name ShieldCrystal
extends Node2D
## Schild-Kristall of a boss shield phase: floats above a platform, takes
## hits like a dummy, and breaks after a few. The boss (Boss.crystal_broken)
## drops its shield when the last one is gone.

const TEX := preload("res://assets/raid/kristall.png")
const HP := 140.0

var world: TrainingRoom
var boss: Boss
var delay := 0.4  # rises after this many seconds
var label := "Schild-Kristall"
var status: Dictionary = {}
var hp := HP
var flash := 0.0
var _t := 0.0
var _gone := false
var _vanish := -1.0
var _sprite: Sprite2D
var _light: PointLight2D


func _ready() -> void:
	add_to_group("crystals")
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.hframes = 9
	_sprite.position = Vector2(0, -34)
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED  # glows in the dusk
	material = m
	_sprite.use_parent_material = true
	_sprite.scale = Vector2.ZERO
	add_child(_sprite)
	if world.stage != null:
		_light = world.stage.make_light(Color(1.0, 0.7, 0.3), 0.8, 0.35)
		if _light != null:
			_light.position = Vector2(0, -34)
			add_child(_light)


func get_hurt_rect() -> Rect2:
	if _gone or _t < delay:
		return Rect2(global_position, Vector2.ZERO)
	return Rect2(global_position + Vector2(-13, -60), Vector2(26, 52))


func head_position() -> Vector2:
	return global_position + Vector2(0, -66)


func weight() -> float:
	return 4.0


func take_hit(_knockback: float, _from_x: float) -> void:
	flash = 0.08


func apply_damage(amount: float) -> void:
	if _gone:
		return
	hp -= amount
	if hp <= 0.0:
		_shatter()


func _shatter() -> void:
	_gone = true
	remove_from_group("targets")
	var c := global_position + Vector2(0, -34)
	world.effects.burst(c, Color("ffd25c"), 26, 200.0, 300.0)
	world.effects.burst(c, Color("ff8a2a"), 12, 140.0, 200.0)
	world.effects.ring(c, 40.0, Color("fff4d0"))
	world.fx.shake(4.0)
	Sfx.play("hit_heavy", -4.0)
	if world.stage != null:
		world.stage.flash_light(c, Color(1.0, 0.8, 0.4), 1.6, 0.8, 0.35)
	if is_instance_valid(boss):
		boss.crystal_broken(self)
	queue_free()


## Shield time ran out: the crystal sinks away without a show.
func vanish() -> void:
	if _gone:
		return
	_gone = true
	remove_from_group("targets")
	_vanish = 0.0


func _process(delta: float) -> void:
	_t += delta
	flash = maxf(0.0, flash - delta)
	if _vanish >= 0.0:
		_vanish += delta
		_sprite.scale = Vector2.ONE * maxf(0.0, 1.0 - _vanish * 3.0)
		if _vanish > 0.4:
			queue_free()
		return
	if _t < delay:
		return
	if not is_in_group("targets") and not _gone:
		add_to_group("targets")
		world.effects.ring(global_position + Vector2(0, -30), 30.0, Color("ffd25c"))
		Sfx.play("dash", -10.0)
	var grow := clampf((_t - delay) * 5.0, 0.0, 1.0)
	_sprite.scale = Vector2.ONE * grow
	_sprite.position = Vector2(0, -34 + sin(_t * 2.4) * 3.0)
	_sprite.frame = int(_t * 8.0) % 9
	var hp_k := hp / HP
	_sprite.modulate = Color(3, 3, 3) if flash > 0.0 else Color(1.0, 0.75 + 0.25 * hp_k, 0.6 + 0.4 * hp_k)
	if world.glut_fx != null and randf() < 0.08:
		world.glut_fx.glow(global_position + Vector2(randf_range(-10, 10), -20), Color(1.6, 1.2, 0.5), 2.5, 0.6, Vector2(0, -25))
	queue_redraw()


func _draw() -> void:
	if _gone or _t < delay:
		return
	# beam to the boss: shows what the crystal protects
	if is_instance_valid(boss) and boss.shielded:
		var a := Vector2(0, -34)
		var b := boss.get_hurt_rect().get_center() - global_position
		var pulse := 0.35 + 0.2 * sin(_t * 8.0)
		draw_line(a, b, Color(1.6, 1.1, 0.4, pulse), 2.0)
	# small HP bar
	var w := 26.0
	var r := Rect2(-w / 2.0, -74.0, w, 3.0)
	draw_rect(r.grow(1), Color("1a1020"))
	draw_rect(Rect2(r.position, Vector2(w * hp / HP, 3.0)), Color("ffd25c"))
