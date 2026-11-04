class_name Attack
extends Node2D
## A hitbox that lives for a short time: melee swings follow their owner,
## projectiles fly. Hits every target at most once.

var world: Node
var owner_body: Node2D
var kind := "slash"
var element := ""
var damage := 10.0
var size := Vector2(30, 30)
var offset := Vector2.ZERO
var follow := false
var life := 0.2
var max_life := 0.2
var velocity := Vector2.ZERO
var pierce := true
var knockback := 0.0
var launch := 0.0  # upward throw for juggles (negative = slam down)
var profile := ""  # hit feel (FxSettings.HIT); empty = by knockback
var phase := 0
var facing := 1
## Colour of the drawn swing (the fighting style tints it by blade heat).
var trail := Color("7fd8ff")
var _hit: Dictionary = {}
var _t := 0.0
var _angle := 0.0  # only tilts the drawn arc; the hitbox stays a rectangle


func setup(d: Dictionary) -> void:
	owner_body = d.owner
	kind = d.kind
	element = d.get("element", "")
	damage = d.damage
	size = d.size
	offset = d.get("offset", Vector2.ZERO)
	follow = d.get("follow", false)
	life = d.get("life", 0.2)
	max_life = life
	velocity = d.get("velocity", Vector2.ZERO)
	pierce = d.get("pierce", true)
	knockback = d.get("knockback", 0.0)
	launch = d.get("launch", 0.0)
	profile = d.get("profile", "")
	phase = d.get("phase", 0)
	trail = d.get("trail", trail)
	facing = owner_body.facing
	global_position = owner_body.global_position + Vector2(offset.x * facing, offset.y)
	scale.x = facing
	_angle = deg_to_rad(d.get("angle", 0.0))


func hit_rect() -> Rect2:
	return Rect2(global_position - size / 2.0, size)


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if follow:
		global_position = owner_body.global_position + Vector2(offset.x * facing, offset.y)
	else:
		global_position += velocity * delta
		if randf() < 0.6:
			world.spawn_spark(global_position, GameData.ELEMENTS[element].color)
	var rect := hit_rect()
	for t in get_tree().get_nodes_in_group("targets"):
		if _hit.has(t.get_instance_id()):
			continue
		if rect.intersects(t.get_hurt_rect()):
			_hit[t.get_instance_id()] = true
			world.deal_hit(t, damage, element, owner_body.global_position.x, knockback, profile, launch)
			if owner_body.has_method("on_attack_hit"):
				owner_body.on_attack_hit()
			if not pierce:
				queue_free()
				return
	queue_redraw()


func _draw() -> void:
	var p := 1.0 - life / max_life  # progress 0..1
	var a := 1.0 - p * 0.6
	draw_set_transform(Vector2.ZERO, _angle, Vector2.ONE)
	match kind:
		"thrust":
			var len := size.x * (0.6 + 0.4 * minf(1.0, p * 3.0))
			draw_line(Vector2(-size.x / 2.0, 0), Vector2(-size.x / 2.0 + len, 0), Color(trail, a * 0.6), 6.0)
			draw_line(Vector2(-size.x / 2.0, 0), Vector2(-size.x / 2.0 + len, 0), Color(1, 1, 1, a), 2.0)
			for k in 3:
				var y := -size.y / 2.0 + size.y * (k + 0.5) / 3.0
				draw_line(Vector2(-size.x / 2.0 - 10, y), Vector2(-size.x / 2.0 + len * 0.5, y), Color(1, 1, 1, a * 0.35), 1.0)
		"sweep":
			draw_arc(Vector2(-size.x / 2.0, -size.y), size.x, 0.15, 1.0, 12, Color(trail, a * 0.6), 6.0)
			draw_arc(Vector2(-size.x / 2.0, -size.y), size.x, 0.15, 1.0, 12, Color(1, 1, 1, a), 2.0)
		"grab":
			draw_arc(Vector2.ZERO, 10.0 + p * 6.0, 0.0, TAU, 16, Color("ffe45c", a * 0.8), 2.0)
		"slash":
			var col := Color(1, 1, 1, a)
			var r := size.y * 0.55
			var start := -1.3 if phase != 1 else 1.3
			var sweep := 2.4 * (1.0 if phase != 1 else -1.0)
			var from := start + sweep * p * 0.3
			_smear(Vector2(-6, 0), r, from, from + sweep * 0.8, 9.0 if profile == "heavy" else 6.0, a)
			draw_arc(Vector2(-6, 0), r, from, from + sweep * 0.8, 10, col, 2.0)
		"flammenschnitt":
			var r := size.y * 0.6
			draw_arc(Vector2(-8, 0), r, -1.5, 1.4, 12, Color("ff3d1f", a), 10.0)
			draw_arc(Vector2(-8, 0), r - 2, -1.4, 1.3, 12, Color("ffb347", a), 6.0)
			draw_arc(Vector2(-8, 0), r - 3, -1.2, 1.1, 12, Color("fff0a0", a), 2.0)
		"frostlanze":
			draw_rect(Rect2(-13, -3, 22, 6), Color("1a1020"))
			draw_rect(Rect2(-12, -2, 20, 4), Color("7fd8ff"))
			draw_rect(Rect2(-10, -1, 16, 1), Color.WHITE)
			draw_colored_polygon(PackedVector2Array([Vector2(8, -4), Vector2(15, 0), Vector2(8, 4)]), Color("e8f8ff"))
		"sturmklinge":
			var wob := sin(_t * 30.0) * 1.5
			draw_arc(Vector2(-6 + wob, 0), 15, -1.2, 1.2, 10, Color("4fd18a", 0.8), 6.0)
			draw_arc(Vector2(-4 + wob, 0), 14, -1.0, 1.0, 10, Color("d8ffe6", 0.95), 2.0)


## Filled crescent smear (thick in the middle, thin at both ends) like the
## swipe frames of anime fighters, with a white-hot inner edge.
func _smear(c: Vector2, r: float, a0: float, a1: float, thick: float, alpha: float) -> void:
	var n := 14
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var ang := lerpf(a0, a1, t)
		var w := thick * sin(t * PI) * (0.4 + 0.6 * t)  # grows towards the leading edge
		var d := Vector2(cos(ang), sin(ang))
		outer.append(c + d * (r + w * 0.5))
		inner.append(c + d * (r - w * 0.5))
	inner.reverse()
	var poly := outer + inner
	draw_colored_polygon(poly, Color(trail, alpha * 0.55))
	var core := PackedVector2Array()
	for i in range(n / 3, n + 1):
		var ang2 := lerpf(a0, a1, float(i) / n)
		core.append(c + Vector2(cos(ang2), sin(ang2)) * (r + 1.0))
	draw_polyline(core, Color(1.4, 1.4, 1.4, alpha), 1.5)
