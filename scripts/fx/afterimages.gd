class_name Afterimages
extends Node2D
## Glowing copies of the fighter's current drawing (dash, heavy strikes),
## drawn additively BEHIND the fighter so the body itself stays readable.
## Each copy keeps the sprite's full transform (flip, lean, squash).

const LIFE := 0.2

var _ghosts: Array = []  # {tex, hframes, frame, xform, offset, col, life}


func _ready() -> void:
	z_index = -1
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m


func add(snap: Dictionary, col: Color) -> void:
	if snap.get("tex") == null:
		return
	snap["col"] = col
	snap["life"] = LIFE
	_ghosts.append(snap)


func _process(delta: float) -> void:
	for g in _ghosts:
		g.life -= delta
	_ghosts = _ghosts.filter(func(g): return g.life > 0.0)
	queue_redraw()


func _draw() -> void:
	var inv := get_global_transform().affine_inverse()
	for g in _ghosts:
		var tex: Texture2D = g.tex
		var hf: int = maxi(1, g.hframes)
		var fw := float(tex.get_width()) / hf
		var fh := float(tex.get_height())
		draw_set_transform_matrix(inv * (g.xform as Transform2D))
		var k: float = g.life / LIFE
		var c: Color = g.col
		draw_texture_rect_region(tex, Rect2(g.offset, Vector2(fw, fh)), Rect2(fw * g.frame, 0, fw, fh), Color(c, c.a * k))
	draw_set_transform_matrix(Transform2D.IDENTITY)
