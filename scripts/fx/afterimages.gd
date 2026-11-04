class_name Afterimages
extends Node2D
## Glowing copies of the fighter's current drawing (dash, heavy strikes),
## drawn additively BEHIND the fighter so the body itself stays readable.
## Each copy keeps the sprite's full transform (flip, lean, squash).

const LIFE := 0.2

var _ghosts: Array = []  # {parts: [{tex, src, xform, offset}], col, life}


func _ready() -> void:
	z_index = -1
	process_mode = Node.PROCESS_MODE_ALWAYS  # trails of the super play during its pause
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m


## `snap` from FighterSprite.snapshot(): all drawings of the figure.
## `shift` moves the copy (trails along a path).
func add(snap: Dictionary, col: Color, shift := Vector2.ZERO, life := LIFE) -> void:
	if snap.get("parts", []).is_empty():
		return
	var parts: Array = []
	for part in snap.parts:
		var q: Dictionary = part.duplicate()
		q.xform = Transform2D(0.0, shift) * (part.xform as Transform2D)
		parts.append(q)
	_ghosts.append({"parts": parts, "col": col, "life": life, "max": life})


func _process(delta: float) -> void:
	for g in _ghosts:
		g.life -= delta
	_ghosts = _ghosts.filter(func(g): return g.life > 0.0)
	queue_redraw()


func _draw() -> void:
	var inv := get_global_transform().affine_inverse()
	for g in _ghosts:
		var k: float = g.life / g.max
		var c: Color = g.col
		for part in g.parts:
			var src: Rect2 = part.src
			draw_set_transform_matrix(inv * (part.xform as Transform2D))
			draw_texture_rect_region(part.tex, Rect2(part.offset, src.size), src, Color(c, c.a * k))
	draw_set_transform_matrix(Transform2D.IDENTITY)
