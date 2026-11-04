class_name LootDrop
extends Node2D
## A dropped item in the world: hops out of the enemy, lands, glows in its
## rarity colour with a light pillar (taller for better items), and flies
## into the player when they come close or after a few seconds.

var world: TrainingRoom
var item: Dictionary
var vel := Vector2.ZERO
var _t := 0.0
var _landed := false
var _fly := false
var _floor_y := 0.0


func _ready() -> void:
	z_index = 5
	_floor_y = GlutHazard.ground_y(global_position.x, global_position.y - 4.0)
	vel = Vector2(randf_range(-70.0, 70.0), -260.0)


func _physics_process(delta: float) -> void:
	_t += delta
	var p := world.player.global_position + Vector2(0, -20)
	if _fly:
		var to := p - global_position
		global_position += to.normalized() * minf(to.length(), (380.0 + _t * 500.0) * delta)
		if to.length() < 10.0:
			_collect()
		queue_redraw()
		return
	if not _landed:
		vel.y += 900.0 * delta
		global_position += vel * delta
		if global_position.y >= _floor_y and vel.y > 0.0:
			global_position.y = _floor_y
			_landed = true
			world.dust.land(global_position, 0.6)
			if int(item.rarity) >= 2:
				world.effects.ring(global_position + Vector2(0, -4), 22.0, Loot.color(item))
				Sfx.play("rare_drop", -8.0 + float(item.rarity) * 2.0)
	elif _t > 3.2 or global_position.distance_to(p) < 46.0:
		_fly = true
		_t = 0.0
	queue_redraw()


func _collect() -> void:
	var col := Loot.color(item)
	if Profile.add_item(item):
		world.toast("%s: %s" % [Loot.rarity_info(item).name, item.name])
		if world.glut_fx != null and int(item.rarity) >= 1:
			world.glut_fx.word(world.player.global_position + Vector2(0, -70), "%s!" % Loot.rarity_info(item).name.to_upper(), col, 22 + int(item.rarity) * 3)
	else:
		var gain := int(Loot.salvage_value(item))
		Profile.add_splitter(gain)
		world.toast("Tasche voll: +%d Splitter" % gain)
	world.effects.burst(global_position, col, 10, 90.0, 160.0)
	Sfx.play("pickup", -2.0)
	queue_free()


func _draw() -> void:
	var col := Loot.color(item)
	var hdr := Color(col.r * FxSettings.boost(), col.g * FxSettings.boost(), col.b * FxSettings.boost(), 1.0)
	var r := int(item.rarity)
	if _landed and not _fly:
		# light pillar: taller and brighter for rarer finds
		var h := 40.0 + r * 30.0
		var pulse := 0.6 + 0.4 * sin(_t * 5.0)
		for i in 4:
			var w := 10.0 - i * 2.2
			draw_rect(Rect2(-w * 0.5, -h, w, h), Color(hdr, (0.06 + 0.05 * i) * pulse))
		draw_circle(Vector2(0, -1), 9.0, Color(hdr, 0.25 * pulse))
	var bob := -6.0 + sin(_t * 4.0) * 2.0 if _landed else -6.0
	ItemIcon.draw_icon(self, Vector2(0, bob), item, 1.0)
