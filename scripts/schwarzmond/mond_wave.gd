class_name MondWave
extends Node2D
## The Mondsichel: a black crescent of Mondlast with a cold rim that flies in
## a straight line (never homing). Airborne targets are carried a bit higher
## instead of dropping out of the combo, so it extends air combos of other
## styles. `pierce` lets it pass through targets (enhanced form).

var world: TrainingRoom
var caster: Node  # MondCaster
var zug_id := "mondsichel"
var dir := Vector2.RIGHT
var speed := 430.0
var reach := 240.0
var r := 20.0
var damage := 7.0
var pierce := false
var enhanced := false
var posture := 1.0
var rim_col := MondFx.CYAN
var profile := "light"
var knockback := 90.0

var _travel := 0.0
var _hit: Dictionary = {}
var _fade := -1.0
var _add: Node2D
var _trail := 0.0


func _ready() -> void:
	z_index = 4
	var im := CanvasItemMaterial.new()
	im.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = im
	_add = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_add.material = m
	_add.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_add.draw.connect(_draw_rim)
	add_child(_add)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _area() -> Rect2:
	var w := r * 0.9 + absf(dir.y) * r * 0.6
	var h := r * 1.9 * (1.0 - absf(dir.y) * 0.4)
	return Rect2(global_position + dir * r * 0.35 - Vector2(w, h) * 0.5, Vector2(w, h))


func _physics_process(delta: float) -> void:
	if world.fx.is_frozen():
		return
	if _fade >= 0.0:
		_fade += delta
		if _fade > 0.18:
			queue_free()
		queue_redraw()
		_add.queue_redraw()
		return
	var step := speed * delta
	global_position += dir * step
	_travel += step
	_trail -= delta
	if _trail <= 0.0:
		_trail = 0.03
		var fx: GlutFx = world.glut_fx
		fx.glow(global_position - dir * r * 0.9, Color(rim_col, 0.35), r * 0.35, 0.2)
		if caster != null:
			caster.mfx.ink(global_position - dir * r * 0.2 + Vector2(randf_range(-r, r) * 0.3, randf_range(-r, r) * 0.6), 1, 30.0, 0.4)
		world.glut_fx.light(global_position, rim_col, 1.2, 0.5, 0.06)
	var area := _area()
	var hits: Array = []
	for t in world.get_tree().get_nodes_in_group("targets"):
		var id: int = t.get_instance_id()
		if _hit.has(id) or not area.intersects(t.get_hurt_rect()):
			continue
		_hit[id] = true
		var airborne: bool = t.get("on_ground") == false
		world.deal_hit(t, damage, "", global_position.x - dir.x * 20.0, knockback, profile, 0.0)
		if airborne and t.has_method("launch"):
			t.launch(170.0)  # carried along: the juggle goes on
		if caster != null:
			caster.druckbruch(t, damage * posture, enhanced, global_position.x - dir.x * 20.0)
		hits.append(t)
	if hits.size() > 0 and caster != null:
		caster.on_zug_hit(zug_id, hits)
		caster.mfx.sichel(hits[0].get_hurt_rect().get_center(), dir, r * 0.7, 0.2, rim_col)
		if not pierce:
			_burst()
			return
	var gy := GlutHazard.ground_y(global_position.x, global_position.y - r)
	if _travel >= reach or (dir.y > 0.1 and global_position.y >= gy - 2.0):
		_burst()
	queue_redraw()
	_add.queue_redraw()


func _burst() -> void:
	_fade = 0.0
	if caster != null:
		caster.mfx.ink(global_position, 8, 110.0, 0.5)
		caster.mfx.streaks(global_position, dir.angle(), 0.9, 6, 220.0, 0.25, rim_col)


func _alpha() -> float:
	var a := minf(1.0, _travel / 30.0 + 0.4)
	if _fade >= 0.0:
		a *= 1.0 - _fade / 0.18
	if _travel > reach * 0.8:
		a *= 1.0 - (_travel - reach * 0.8) / (reach * 0.2) * 0.6
	return clampf(a, 0.0, 1.0)


func _draw() -> void:
	var grow := 1.0 + (_fade if _fade >= 0.0 else 0.0) * 2.0
	MondFx.draw_crescent(self, null, Vector2.ZERO, dir, r * grow, _alpha(), rim_col, 1.25, 1.3)


func _draw_rim() -> void:
	var grow := 1.0 + (_fade if _fade >= 0.0 else 0.0) * 2.0
	var a := _alpha()
	var tex := GlutFx.glow_texture()
	var s := r * 0.6 * grow
	_add.draw_texture_rect(tex, Rect2(dir * r * 1.15 - Vector2(s, s), Vector2(s, s) * 2.0), false, Color(rim_col, 0.12 * a))
	MondFx.draw_crescent(null, _add, Vector2.ZERO, dir, r * grow, a, rim_col, 1.25, 1.3)
	# motion smear behind the crescent
	for i in 3:
		var back := -dir * (8.0 + i * 9.0)
		var pts := MondFx.rim(back, dir, r * grow * (1.0 - i * 0.12), 1.0)
		_add.draw_polyline(pts, Color(rim_col, a * (0.35 - i * 0.1)), 1.5, true)
