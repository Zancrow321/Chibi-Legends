class_name BollwerkGrenade
extends Node2D
## Granate des Splitterwurfs: fliegt im Bogen, prallt von Boden und Raumrand
## ab und explodiert nach dem Zünder. kind: "splitter" (Fläche), "haft" (bleibt
## bei direktem Treffer kleben, blinkt auffällig), "stoer" (Entladungen mit
## Schildstörung, wenig Explosionsschaden).

const GRAV := 900.0
const BOUNCE := 0.45

var caster: BollwerkCaster
var kind := "splitter"
var damage := 16.0
var radius := 46.0
var fuse := 1.2
var zap_time := 0.0
var vel := Vector2.ZERO

var _t := 0.0
var _stuck: Node2D = null
var _stuck_off := Vector2.ZERO
var _resting := false
var _zap_t := -1.0
var _zap_hits := {}
var _zap_tick := 0.0


func _physics_process(delta: float) -> void:
	if caster == null or caster.world == null:
		queue_free()
		return
	if caster.world.fx.is_frozen():
		return
	if _zap_t >= 0.0:
		_tick_zap(delta)
		return
	_t += delta
	if _stuck != null:
		if is_instance_valid(_stuck):
			global_position = _stuck.get_hurt_rect().get_center() + _stuck_off
		else:
			_stuck = null
	elif not _resting:
		vel.y = minf(vel.y + GRAV * delta, 600.0)
		var nxt := global_position + vel * delta
		if nxt.x < 4.0 or nxt.x > TrainingRoom.WIDTH - 4.0:
			vel.x = -vel.x * 0.6
			nxt.x = clampf(nxt.x, 4.0, TrainingRoom.WIDTH - 4.0)
		var gy := GlutHazard.ground_y(nxt.x, global_position.y - 2.0)
		if vel.y > 0.0 and nxt.y >= gy - 2.0:
			nxt.y = gy - 2.0
			if absf(vel.y) < 70.0:
				_resting = true
				vel = Vector2.ZERO
			else:
				vel.y = -vel.y * BOUNCE
				vel.x *= 0.7
				Sfx.play("land", -12.0)
		global_position = nxt
		if kind == "haft" and _t > 0.05:
			for tg in caster.world.get_tree().get_nodes_in_group("targets"):
				var hr: Rect2 = tg.get_hurt_rect()
				if hr.grow(3.0).has_point(global_position):
					_stuck = tg
					_stuck_off = global_position - hr.get_center()
					caster.bfx.word(global_position + Vector2(0, -16), "KLEBT!", caster.style.color("orange"), 15)
					Sfx.play("bw_hook", -6.0)
					break
	# blink faster towards the end; the Haftladung loud and red
	var left := fuse - _t
	var rate := 6.0 if left > 0.5 else 16.0
	if kind == "haft":
		rate *= 1.6
	if fmod(_t * rate, 1.0) < 0.5:
		var col := Color(1, 0.3, 0.2) if kind == "haft" else (caster.style.color("plasma") if kind == "stoer" else caster.style.color("amber"))
		caster.bfx.glow(global_position, Color(col, 0.9), 5.0 if kind != "haft" else 8.0, 0.05)
	queue_redraw()
	if _t >= fuse:
		_explode()


func _explode() -> void:
	var c := global_position + Vector2(0, -4)
	var dmg := damage
	var hit := caster._radial(c, radius, dmg, 180.0, "heavy", 90.0, 6.0, kind == "stoer", {})
	caster.on_zug_hit("splitterwurf", hit)
	if kind == "stoer":
		caster.bfx.zap(c, radius, 8)
		caster.bfx.ring(c, radius, caster.style.color("plasma"), 0.35, 3.0)
		caster.bfx.word(c + Vector2(0, -radius * 0.6), "BZZT!", caster.style.color("plasma"), 22)
		Sfx.play("bw_beam", -6.0)
		if zap_time > 0.0:
			_zap_t = zap_time
			visible = true
			return
	else:
		caster.bfx.explosion(c, radius)
		caster.bfx.word(c + Vector2(0, -radius * 0.7), "WUMMS!", caster.style.color("orange"), 26)
		caster.world.fx.shake(5.0 * FxSettings.factor("shake"))
		caster.world.fx.flash(0.12 * FxSettings.factor("flash"), Color(1.0, 0.7, 0.4))
		Sfx.play("bw_explosion")
	queue_free()


func _tick_zap(delta: float) -> void:
	_zap_t -= delta
	_zap_tick -= delta
	var c := global_position + Vector2(0, -6)
	if randf() < 0.6:
		caster.bfx.zap(c, radius * 0.8, 2)
	if _zap_tick <= 0.0:
		_zap_tick = 0.3
		var hit := caster._radial(c, radius * 0.8, 1.6, 0.0, "light", 0.0, 2.0, true, {})
		caster.on_zug_hit("splitterwurf", hit)
	queue_redraw()
	if _zap_t <= 0.0:
		queue_free()


func _draw() -> void:
	if _zap_t >= 0.0:
		return
	var col := Color("3a3f48")
	draw_circle(Vector2.ZERO, 3.2, Color("121418"))
	draw_circle(Vector2.ZERO, 2.4, col)
	var band := Color(1, 0.3, 0.2) if kind == "haft" else (Color("52f2ff") if kind == "stoer" else Color("ffb02e"))
	draw_line(Vector2(-2.4, 0), Vector2(2.4, 0), band, 1.0)
