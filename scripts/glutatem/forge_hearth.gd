class_name ForgeHearth
extends Node2D
## A small stone forge hearth (Esse) on the training ground, drawn in pixel
## art: stone rim, ash pit with glowing coals, a hood and an anvil next to it.
## The coals pulse; flames, embers and light come from the dusk stage.

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var outline := Color("1a1020")
	var stone := Color("6a6478")
	var stone_d := Color("4a4558")
	var stone_l := Color("8a84a0")
	# base block
	draw_rect(Rect2(-17, -14, 34, 14), outline)
	draw_rect(Rect2(-16, -13, 32, 13), stone)
	for i in 4:
		var x := -16.0 + i * 8.0 + (4.0 if i % 2 else 0.0)
		draw_rect(Rect2(x, -7, 7, 1), stone_d)
	draw_rect(Rect2(-16, -13, 32, 2), stone_l)
	# ash pit and coals
	draw_rect(Rect2(-12, -17, 24, 5), outline)
	draw_rect(Rect2(-11, -16, 22, 4), Color("2a1a1a"))
	for i in 7:
		var k := 0.5 + 0.5 * sin(_t * (5.0 + i) + i * 1.9)
		var col := GlutFx.heat(0.45 + 0.4 * k)
		draw_rect(Rect2(-10 + i * 3, -16 + (i % 2), 3, 2), col)
	draw_rect(Rect2(-6, -16, 2, 1), GlutFx.heat(0.95))
	draw_rect(Rect2(3, -16, 2, 1), GlutFx.heat(0.9))
	# side posts and hood
	draw_rect(Rect2(-17, -40, 5, 26), outline)
	draw_rect(Rect2(-16, -39, 3, 24), stone_d)
	draw_rect(Rect2(12, -40, 5, 26), outline)
	draw_rect(Rect2(13, -39, 3, 24), stone_d)
	draw_colored_polygon(PackedVector2Array([Vector2(-19, -40), Vector2(19, -40), Vector2(8, -52), Vector2(-8, -52)]), outline)
	draw_colored_polygon(PackedVector2Array([Vector2(-17, -41), Vector2(17, -41), Vector2(7, -51), Vector2(-7, -51)]), stone)
	draw_rect(Rect2(-17, -42, 34, 2), stone_l)
	draw_rect(Rect2(-5, -64, 10, 13), outline)
	draw_rect(Rect2(-4, -63, 8, 12), stone_d)
	# anvil to the left
	var a := Vector2(-34, 0)
	draw_rect(Rect2(a + Vector2(-5, -6), Vector2(10, 6)), outline)
	draw_rect(Rect2(a + Vector2(-4, -6), Vector2(8, 5)), Color("3a3446"))
	draw_rect(Rect2(a + Vector2(-9, -12), Vector2(18, 6)), outline)
	draw_rect(Rect2(a + Vector2(-8, -11), Vector2(16, 4)), Color("4a4458"))
	draw_colored_polygon(PackedVector2Array([a + Vector2(8, -11), a + Vector2(14, -11), a + Vector2(8, -8)]), Color("4a4458"))
	draw_rect(Rect2(a + Vector2(-8, -11), Vector2(16, 1)), Color("9a94b0"))
