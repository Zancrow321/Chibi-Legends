class_name ForestBackground
extends Node2D
## Procedural parallax background for the academy's training forest:
## misty sky, giant vine-wrapped trunks in three depths, floating moss pads.
## Drawn on a CanvasLayer behind the world, scrolled by the camera position.

const PX := 2.0  # one art pixel = 2 screen pixels (matches camera zoom)

var camera: Camera2D
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


static func _h(i: int, salt: float) -> float:
	return fposmod(sin(float(i) * 12.9898 + salt * 78.233) * 43758.5453, 1.0)


func _draw() -> void:
	var screen := get_viewport_rect().size
	var w := screen.x / PX
	var h := screen.y / PX
	var cam_x := camera.get_screen_center_position().x if camera else 0.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(PX, PX))

	# sky: banded mist, brightest near the horizon like light through leaves
	var bands := [Color("6fae7a"), Color("82bd85"), Color("98cb93"), Color("aed7a2"), Color("c2e2b3"), Color("d4ebc2"), Color("ddefca")]
	var bh := h / bands.size()
	for i in bands.size():
		draw_rect(Rect2(0, i * bh, w, bh + 1), bands[i])
	# light shafts
	for i in 4:
		var sx := fposmod(120.0 + i * 170.0 - cam_x * 0.05, w + 200.0) - 100.0
		draw_colored_polygon(PackedVector2Array([Vector2(sx, 0), Vector2(sx + 30, 0), Vector2(sx + 90, h), Vector2(sx + 50, h)]), Color(1, 1, 0.9, 0.08))

	_trunks(cam_x, w, h, 0.12, 150.0, Color("a7cf9c"), Color("b9dcac"), 0.9, 1)
	_moss_pads(cam_x, w, h, 0.25)
	_trunks(cam_x, w, h, 0.3, 190.0, Color("7fb576"), Color("97c78a"), 1.0, 2)
	_trunks(cam_x, w, h, 0.55, 260.0, Color("4f8a4c"), Color("68a35d"), 1.25, 3)
	_bushes(cam_x, w, h, 0.8)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _trunks(cam_x: float, w: float, h: float, factor: float, spacing: float, col: Color, vine: Color, width_scale: float, salt: int) -> void:
	var off := cam_x * factor
	var first := int(floor((off - 80.0) / spacing))
	for i in range(first, first + int(w / spacing) + 3):
		var x := i * spacing - off + _h(i, salt) * 60.0
		var tw := (26.0 + _h(i, salt + 10) * 24.0) * width_scale
		draw_rect(Rect2(x, 0, tw, h), col)
		draw_rect(Rect2(x, 0, 3 * width_scale, h), col.darkened(0.12))
		draw_rect(Rect2(x + tw - 4 * width_scale, 0, 4 * width_scale, h), col.lightened(0.08))
		# spiral vines around the trunk
		var step := 26.0 * width_scale
		var y := fposmod(_h(i, salt + 3) * step, step) - step
		while y < h:
			draw_line(Vector2(x - 2, y), Vector2(x + tw + 2, y + step * 0.6), vine, 3.0 * width_scale)
			draw_line(Vector2(x - 2, y + 2), Vector2(x + tw + 2, y + step * 0.6 + 2), vine.darkened(0.15), 1.0)
			y += step


func _moss_pads(cam_x: float, w: float, h: float, factor: float) -> void:
	var off := cam_x * factor
	var spacing := 210.0
	var first := int(floor(off / spacing)) - 1
	for i in range(first, first + int(w / spacing) + 3):
		var x := i * spacing - off + _h(i, 7) * 90.0
		var y := 40.0 + _h(i, 8) * (h * 0.35)
		var pw := 40.0 + _h(i, 9) * 30.0
		var col := Color("6aa25e")
		draw_rect(Rect2(x, y, pw, 6), col)
		draw_rect(Rect2(x + 4, y - 3, pw - 8, 3), col.lightened(0.15))
		for k in int(pw / 8):
			var dl := 4.0 + _h(i * 13 + k, 11) * 10.0
			draw_rect(Rect2(x + 3 + k * 8, y + 6, 2, dl), col.darkened(0.15))


func _bushes(cam_x: float, w: float, h: float, factor: float) -> void:
	var off := cam_x * factor
	var spacing := 70.0
	var first := int(floor(off / spacing)) - 1
	var base := h - 54.0
	for i in range(first, first + int(w / spacing) + 3):
		var x := i * spacing - off
		var bw := 50.0 + _h(i, 21) * 40.0
		var bh := 18.0 + _h(i, 22) * 22.0
		var col := Color("3d7a3a") if i % 2 == 0 else Color("467f3e")
		draw_rect(Rect2(x, base - bh, bw, bh + 60), col)
		draw_rect(Rect2(x + 6, base - bh - 6, bw - 12, 6), col)
		draw_rect(Rect2(x + 10, base - bh - 4, bw * 0.4, 3), col.lightened(0.18))
