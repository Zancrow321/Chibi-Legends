class_name FormFx
extends FederFx
## Effects of the Baukasten fighting styles (scripts/formen). Builds on
## FederFx (PixelLab bursts, rings, glow, shards, manga words, speed lines)
## and adds stretched sprite shapes, all drawn additive so the bloom picks
## them up:
##  - beam    a sprite stretched between two points (Strahl, Sturm streak)
##  - column  a sprite standing on the ground, stretched upward (Säule)
##  - sheet   a sprite filling a rect (Meisterzug fields)
## Sprites come from assets/combat/vfx/<style>/<id>.png (FederFx.tex with
## "<style>/<id>"). A missing sprite falls back to soft glow shapes.


func beam(id: String, a: Vector2, b: Vector2, width: float, col := Color.WHITE, life := 0.08) -> void:
	_fx.append({"type": "beam", "id": id, "a": a, "b": b, "w": width, "col": col, "life": life, "max": life})


func column(id: String, base: Vector2, width: float, height: float, col := Color.WHITE, life := 0.35) -> void:
	_fx.append({"type": "column", "id": id, "pos": base, "w": width, "h": height, "col": col, "life": life, "max": life})


func sheet(id: String, rect: Rect2, col := Color.WHITE, life := 0.1, flip := false) -> void:
	_fx.append({"type": "sheet", "id": id, "rect": rect, "col": col, "life": life, "max": life, "flip": flip})


func _draw_add() -> void:
	super._draw_add()
	for f in _fx:
		var p: float = 1.0 - f.life / f.max
		match f.type:
			"beam":
				var d: Vector2 = f.b - f.a
				var ln := d.length()
				if ln < 1.0:
					continue
				var fade: float = 1.0 if f.max <= 0.1 else (1.0 if p < 0.5 else 1.0 - (p - 0.5) * 2.0)
				var col: Color = Color(f.col, f.col.a * fade)
				_add.draw_set_transform(f.a.lerp(f.b, 0.5), d.angle(), Vector2.ONE)
				var t := tex(f.id)
				if t != null:
					_add.draw_texture_rect(t, Rect2(Vector2(-ln * 0.5, -f.w * 0.5), Vector2(ln, f.w)), false, col)
				else:
					_add.draw_rect(Rect2(Vector2(-ln * 0.5, -f.w * 0.3), Vector2(ln, f.w * 0.6)), Color(col, col.a * 0.5))
				_add.draw_rect(Rect2(Vector2(-ln * 0.5, -f.w * 0.1), Vector2(ln, f.w * 0.2)), Color(1, 1, 1, 0.35 * fade))
				_add.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"column":
				var grow := minf(1.0, p * 4.0)
				var a2: float = 1.0 if p < 0.5 else 1.0 - (p - 0.5) * 2.0
				var h: float = f.h * (0.3 + 0.7 * (1.0 - pow(1.0 - grow, 3.0)))
				var r := Rect2(f.pos.x - f.w * 0.5, f.pos.y - h, f.w, h)
				var t2 := tex(f.id)
				if t2 != null:
					_add.draw_texture_rect(t2, r, false, Color(f.col, f.col.a * a2))
				else:
					_add.draw_rect(r, Color(f.col, 0.4 * a2))
				_glow(_add, f.pos + Vector2(0, -h * 0.5), f.w * 0.9, Color(f.col, 0.2 * a2))
			"sheet":
				var a3: float = minf(1.0, p * 5.0) * (1.0 if p < 0.6 else 1.0 - (p - 0.6) / 0.4)
				var t3 := tex(f.id)
				var rr: Rect2 = f.rect
				if t3 != null:
					if f.flip:
						_add.draw_set_transform(rr.get_center(), 0.0, Vector2(-1, 1))
						_add.draw_texture_rect(t3, Rect2(-rr.size * 0.5, rr.size), false, Color(f.col, f.col.a * a3))
						_add.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
					else:
						_add.draw_texture_rect(t3, rr, false, Color(f.col, f.col.a * a3))
				else:
					_add.draw_rect(rr, Color(f.col, 0.25 * a3))
