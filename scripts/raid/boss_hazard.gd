class_name BossHazard
extends Node2D
## Danger zones of a raid boss (spawned by RaidDirector.spawn_hazard):
##
##  wave    a shockwave of embers that runs along the ground; jump over it
##  marker  a glowing ring on the ground, after TELEGRAPH an ember falls
##          from the sky and burns the spot
##  flood   Essensturm: the whole floor fills with fire, only the
##          platforms are safe
##
## All of them hit the player through Player.receive_hit (block, dash and
## Perfekt-Block work as against any attack).

const TELEGRAPH := 0.9
const WAVE_SPEED := 250.0

var world: TrainingRoom
var kind := "wave"
var dir := 1.0
var damage := 60.0
var source: Node2D
var _t := 0.0
var _hit := false


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m
	z_index = 4


func _physics_process(delta: float) -> void:
	_t += delta
	match kind:
		"wave":
			position.x += dir * WAVE_SPEED * delta
			var gy := GlutHazard.ground_y(position.x, position.y - 4.0)
			if absf(gy - position.y) > 6.0 or position.x < 0.0 or position.x > TrainingRoom.WIDTH or _t > 4.0:
				_fade()
				return
			if randf() < 0.7 and world.glut_fx != null:
				world.glut_fx.flame(global_position + Vector2(randf_range(-8, 8), -2), randf_range(5, 9), Vector2(-dir * 40.0, -90.0), 0.35)
			_touch(Rect2(global_position + Vector2(-12, -18), Vector2(24, 18)))
		"marker":
			if _t >= TELEGRAPH and not _hit:
				_hit = true
				_touch(Rect2(global_position + Vector2(-30, -40), Vector2(60, 40)))
				world.effects.burst(global_position + Vector2(0, -6), Color("ff8a2a"), 14, 160.0, 380.0)
				world.dust.land(global_position, 1.2)
				world.fx.shake(2.5)
				Sfx.play("hit_heavy", -12.0)
				if world.glut_fx != null:
					for i in 5:
						world.glut_fx.flame(global_position + Vector2(randf_range(-22, 22), -2), randf_range(6, 10), Vector2(0, -110), 0.45)
				if world.stage != null:
					world.stage.flash_light(global_position + Vector2(0, -16), Color(1.0, 0.55, 0.25), 1.2, 0.6, 0.3)
			if _t > TELEGRAPH + 0.45:
				queue_free()
		"flood":
			# rises for 0.5 s, burns for 1.6 s, then sinks
			if _t > 0.5 and _t < 2.1:
				for g in TrainingRoom.GROUND:
					_touch(Rect2(g[0], g[1] - 22.0, g[2], 22.0))
				if world.glut_fx != null and randf() < 0.9:
					var x := randf_range(0.0, TrainingRoom.WIDTH)
					world.glut_fx.flame(Vector2(x, GlutHazard.ground_y(x) - 2.0), randf_range(8, 16), Vector2(0, -140), 0.5)
			if _t > 2.6:
				queue_free()
	queue_redraw()


func _touch(r: Rect2) -> void:
	var p := world.player
	if r.intersects(p.get_hurt_rect()):
		p.receive_hit(damage, global_position.x - dir * 10.0 if kind == "wave" else p.global_position.x - 1.0, source)


func _fade() -> void:
	kind = "gone"
	queue_free()


func _draw() -> void:
	match kind:
		"wave":
			var pulse := 0.8 + 0.2 * sin(_t * 40.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-14, 0), Vector2(-4, -20 * pulse), Vector2(6, -14), Vector2(14, 0)]), Color(2.2, 1.0, 0.35, 0.9))
			draw_colored_polygon(PackedVector2Array([Vector2(-8, 0), Vector2(-2, -12 * pulse), Vector2(8, 0)]), Color(2.6, 2.2, 1.4))
		"marker":
			var k := clampf(_t / TELEGRAPH, 0.0, 1.0)
			var col := Color(2.0, 0.6, 0.25, 0.35 + 0.5 * k)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
			draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 28, col, 3.0)
			draw_circle(Vector2.ZERO, 30.0 * k, Color(2.0, 0.5, 0.2, 0.25))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if not _hit:
				# the falling ember
				var y := -320.0 * (1.0 - k)
				draw_circle(Vector2(0, y - 8), 7.0, Color(2.4, 1.2, 0.4))
				draw_circle(Vector2(0, y - 8), 4.0, Color(3.0, 2.6, 1.8))
				draw_line(Vector2(0, y - 40), Vector2(0, y - 12), Color(2.0, 0.8, 0.3, 0.6), 4.0)
		"flood":
			var rise := clampf(_t / 0.5, 0.0, 1.0) * clampf((2.6 - _t) / 0.5, 0.0, 1.0)
			for g in TrainingRoom.GROUND:
				var top: float = g[1] - 18.0 * rise
				var x: float = g[0]
				var w: float = g[2]
				draw_rect(Rect2(x, top, w, g[1] - top + 6.0), Color(2.0, 0.55, 0.2, 0.55 * rise))
				var pts := PackedVector2Array()
				var i := 0.0
				while i <= w:
					pts.append(Vector2(x + i, top - 4.0 * rise * (0.5 + 0.5 * sin(i * 0.15 + _t * 12.0))))
					i += 8.0
				draw_polyline(pts, Color(2.8, 1.8, 0.8, rise), 2.0)
