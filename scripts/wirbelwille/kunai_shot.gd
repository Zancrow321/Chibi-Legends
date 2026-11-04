class_name KunaiShot
extends Node2D
## A thrown kunai (Wirbelwille): flies straight, hits the first target once
## (optionally holds it a moment) and sticks in the ground or fades.

const TEX := preload("res://assets/creator/weapons/wirbelwille/kunai.png")

var caster: Node  # WirbelCaster
var world: TrainingRoom
var wfx: WirbelFx
var vel := Vector2.ZERO
var damage := 4.0
var hold := false   # the hit holds the target briefly (Kunai-Auftakt)
var life := 1.2
var _done := false
var _stuck := 0.0


func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _physics_process(delta: float) -> void:
	if _stuck > 0.0:
		_stuck -= delta
		modulate.a = clampf(_stuck / 0.3, 0.0, 1.0)
		if _stuck <= 0.0:
			queue_free()
		return
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var old := global_position
	global_position += vel * delta
	rotation = vel.angle()
	if randf() < 0.5:
		wfx.thread(old, global_position, WirbelFx.ICE, 0.8)
	if not _done:
		var r := Rect2(global_position - Vector2(6, 6), Vector2(12, 12))
		for tg in world.get_tree().get_nodes_in_group("targets"):
			if r.intersects(tg.get_hurt_rect()):
				_done = true
				world.deal_hit(tg, damage, "", global_position.x - vel.x, 30.0 if not hold else 10.0, "light", 0.0)
				if hold and tg.get("vel") != null:
					tg.vel = Vector2.ZERO
				wfx.shards(global_position, vel.angle() + PI, 0.6, 5, 160.0, WirbelFx.ICE)
				wfx.word(global_position + Vector2(0, -16), "TSCHAK", WirbelFx.WHITE, 12)
				if caster != null and caster.has_method("on_kunai_hit"):
					caster.on_kunai_hit([tg])
				queue_free()
				return
	var gy := GlutHazard.ground_y(global_position.x, old.y - 2.0)
	if global_position.y >= gy:
		global_position.y = gy - 2.0
		_stuck = 0.6
		wfx.shards(global_position, -PI / 2.0, 0.8, 3, 80.0, WirbelFx.ICE)


func _draw() -> void:
	# 48 px item (blade to the right, centred at y 24) drawn about 19 px long
	draw_texture_rect(TEX, Rect2(Vector2(-24, -24) * 0.4, Vector2(48, 48) * 0.4), false)
