class_name KlangWave
extends Node2D
## A crescent of soul energy that flies straight ahead (Seelenwelle) or runs
## along the ground (shock of the verstärkte Fallende Sichel). Hits every
## target once, tells the caster about hits for the Einklang.

var world: TrainingRoom
var kfx: KlangFx
var caster: Node  # KlangCaster
var zug_id := ""
var dir := 1.0
var dist := 213.0
var damage := 10.0
var ground := false
var col := Color("8fd3ff")
var speed := 420.0
var _gone := 0.0
var _hit: Dictionary = {}
var _emit := 0.0


func _ready() -> void:
	z_index = 4
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if ground:
		speed = 300.0


func _physics_process(delta: float) -> void:
	var step := speed * delta
	position.x += dir * step
	_gone += step
	var h := 18.0 if ground else 30.0
	var rect := Rect2(global_position + Vector2(-10, -h * 0.5 - (6.0 if ground else 0.0)), Vector2(20, h))
	var targets := GlutHazard.strike(world, rect, damage, global_position.x - dir * 30.0, 110.0, "heavy", 0.0, _hit, "seele")
	if not targets.is_empty() and caster != null:
		caster.on_zug_hit(zug_id, targets)
	_emit -= delta
	if _emit <= 0.0:
		_emit = 0.03
		kfx.motes(global_position, 1, 6.0, col, 0.4)
	if _gone >= dist:
		kfx.glow(global_position, Color(col, 0.6), 12.0, 0.2)
		queue_free()
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - clampf((_gone - dist * 0.7) / (dist * 0.3), 0.0, 1.0)
	var r := 12.0 if ground else 18.0
	var a0 := -1.2 if dir > 0 else PI - 1.2
	var a1 := 1.2 if dir > 0 else PI + 1.2
	var n := 16
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in n + 1:
		var k := float(i) / n
		var a := lerpf(a0, a1, k)
		var th := 7.0 * sin(k * PI)
		var d := Vector2(cos(a), sin(a))
		outer.append(Vector2(-dir * 8.0, 0) + d * (r + th * 0.5))
		inner.append(Vector2(-dir * 8.0, 0) + d * (r - th * 0.5))
	inner.reverse()
	draw_colored_polygon(outer + inner, Color(col, 0.75 * fade))
	draw_arc(Vector2(-dir * 8.0, 0), r + 2.0, a0 + 0.3, a1 - 0.3, 12, Color(1, 1, 1, 0.9 * fade), 1.2, true)
	draw_texture_rect(GlutFx.glow_texture(), Rect2(Vector2(-r - 6, -r - 6), Vector2(r + 6, r + 6) * 2.0), false, Color(col, 0.35 * fade))
