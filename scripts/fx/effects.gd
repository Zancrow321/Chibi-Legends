class_name Effects
extends Node2D
## World-space pixel effects: square particles, dash afterimages,
## lightning chains and reaction shockwave rings.

var _parts: Array = []  # {pos, vel, life, max, color, size, grav}
var _ghosts: Array = []  # {pos, look, facing, state, life}
var _bolts: Array = []  # {points, life}
var _rings: Array = []  # {pos, radius, color, life}


func burst(pos: Vector2, color: Color, count: int, speed := 90.0, grav := 160.0) -> void:
	for i in count:
		var ang := randf() * TAU
		var v := Vector2(cos(ang), sin(ang)) * randf_range(speed * 0.3, speed)
		_parts.append({"pos": pos, "vel": v, "life": randf_range(0.25, 0.55), "max": 0.55, "color": color, "size": float(randi_range(1, 3)), "grav": grav})


func spark(pos: Vector2, color: Color) -> void:
	_parts.append({"pos": pos + Vector2(randf_range(-4, 4), randf_range(-4, 4)), "vel": Vector2(randf_range(-20, 20), randf_range(-30, 5)), "life": 0.3, "max": 0.3, "color": color, "size": 2.0, "grav": 0.0})


func ghost(player: Player) -> void:
	_ghosts.append({"pos": player.global_position, "look": player.visual.look.duplicate(), "facing": player.facing, "life": 0.22})


func bolt(points: PackedVector2Array) -> void:
	_bolts.append({"points": points, "life": 0.22})


func ring(pos: Vector2, radius: float, color: Color) -> void:
	_rings.append({"pos": pos, "radius": radius, "color": color, "life": 0.35})


func _process(delta: float) -> void:
	for p in _parts:
		p.life -= delta
		p.vel.y += p.grav * delta
		p.pos += p.vel * delta
	_parts = _parts.filter(func(p): return p.life > 0.0)
	for g in _ghosts:
		g.life -= delta
	_ghosts = _ghosts.filter(func(g): return g.life > 0.0)
	for b in _bolts:
		b.life -= delta
	_bolts = _bolts.filter(func(b): return b.life > 0.0)
	for r in _rings:
		r.life -= delta
	_rings = _rings.filter(func(r): return r.life > 0.0)
	queue_redraw()


func _draw() -> void:
	for g in _ghosts:
		# afterimage: a flat tinted silhouette block (cheap stand-in for a sprite copy)
		var a: float = g.life / 0.22 * 0.45
		var col := Color(0.55, 0.85, 1.0, a)
		var x: Vector2 = g.pos
		draw_rect(Rect2(x + Vector2(-12, -46), Vector2(24, 24)), col)
		draw_rect(Rect2(x + Vector2(-7, -22), Vector2(14, 22)), col)
	for r in _rings:
		var t: float = 1.0 - r.life / 0.35
		var c: Color = r.color
		c.a = 1.0 - t
		draw_arc(r.pos, r.radius * (0.3 + 0.7 * t), 0, TAU, 32, c, 4.0 * (1.0 - t) + 1.0)
		var c2 := c
		c2.a *= 0.25
		draw_circle(r.pos, r.radius * (0.3 + 0.7 * t), c2)
	for b in _bolts:
		var pts: PackedVector2Array = b.points
		for i in pts.size() - 1:
			var seg := _jag(pts[i], pts[i + 1])
			draw_polyline(seg, Color("fff6a0", b.life / 0.22), 4.0)
			draw_polyline(seg, Color.WHITE, 1.5)
	for p in _parts:
		var c: Color = p.color
		c.a = clampf(p.life / p.max, 0.0, 1.0)
		draw_rect(Rect2(p.pos.round(), Vector2(p.size, p.size)), c)


func _jag(a: Vector2, b: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array([a])
	var n := 5
	var normal := (b - a).orthogonal().normalized()
	for i in range(1, n):
		out.append(a.lerp(b, float(i) / n) + normal * randf_range(-7, 7))
	out.append(b)
	return out
