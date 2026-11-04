class_name Dust
extends Node2D
## Soft dust puffs at the feet: steps, take-off, landing, dash start.
## Normal blending and never above white, so it reads as dust, not as a
## glowing effect; unshaded so the dusk light does not swallow it.

const COL := Color(0.8, 0.74, 0.76, 0.85)

var _puffs: Array = []  # {pos, vel, life, max, size}


func _ready() -> void:
	z_index = 1
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m


## A few puffs at `pos`, pushed along `dir` (x sign) with `speed`.
func puff(pos: Vector2, dir: float, count := 3, size := 3.0, speed := 30.0) -> void:
	for i in count:
		var v := Vector2(dir * speed * randf_range(0.5, 1.2) + randf_range(-8, 8), -randf_range(4, 16))
		_add(pos + Vector2(randf_range(-3, 3), -1), v, size * randf_range(0.8, 1.3), randf_range(0.3, 0.5))


## Landing: dust rolls out to both sides, more for a harder landing (0..1).
func land(pos: Vector2, strength: float) -> void:
	var n := int(3 + strength * 5)
	for side in [-1.0, 1.0]:
		puff(pos + Vector2(side * 4, 0), side, n, 2.5 + strength * 2.0, 40.0 + strength * 50.0)


func _add(pos: Vector2, vel: Vector2, size: float, life: float) -> void:
	_puffs.append({"pos": pos, "vel": vel, "life": life, "max": life, "size": size})


func _process(delta: float) -> void:
	for p in _puffs:
		p.life -= delta
		p.vel *= 0.9
		p.vel.y -= 6.0 * delta
		p.pos += p.vel * delta
	_puffs = _puffs.filter(func(p): return p.life > 0.0)
	queue_redraw()


func _draw() -> void:
	for p in _puffs:
		var k: float = 1.0 - p.life / p.max  # 0 -> 1
		var r: float = p.size * (0.9 + k * 1.4)
		var c := Color(COL, COL.a * (1.0 - k) * (1.0 - k))
		draw_circle(p.pos.round(), r, c)
		draw_circle((p.pos + Vector2(-r * 0.3, -r * 0.3)).round(), r * 0.5, Color(1, 1, 1, c.a * 0.4))
