class_name GlutHazard
extends Node2D
## Things a Zug leaves in the world that keep dealing damage:
##  brocken  glowing slag chunk on a ballistic arc; hits, then lands
##  lache    burning puddle on the ground, ticks
##  welle    glow wave rolling along the ground, hits each target once
##  spur     glowing trail of Funkenflug on the ground, ticks
##  krater   burning crater ring after Essensturz, ticks
##  schild   standing spark cone of Funkenschild, burns enemy projectiles
## Also holds the shared hit helper for all Glutatem attacks.

var world: TrainingRoom
var fx: GlutFx
var caster: Node  # GlutCaster: told about hits for the Atemrhythmus
var zug_id := ""
var kind := "brocken"
var element := "feuer"
var damage := 8.0
var life := 2.0
var max_life := 2.0
var vel := Vector2.ZERO
var size := 3.0
var dir := 1.0
var params: Dictionary = {}
var _hit: Dictionary = {}
var _tick := 0.0
var _emit := 0.0
var _t := 0.0
## spur: start and end x of the trail (world).
var x0 := 0.0
var x1 := 0.0
var _light: PointLight2D


## Hits every target overlapping `rect` that is not in `hit_set` yet.
## Returns the targets hit.
static func strike(room: TrainingRoom, rect: Rect2, dmg: float, from_x: float, knockback: float,
		profile := "", launch := 0.0, hit_set = null, element := "feuer") -> Array:
	var out: Array = []
	for t in room.get_tree().get_nodes_in_group("targets"):
		if hit_set != null and hit_set.has(t.get_instance_id()):
			continue
		if rect.intersects(t.get_hurt_rect()):
			if hit_set != null:
				hit_set[t.get_instance_id()] = true
			room.deal_hit(t, dmg, element, from_x, knockback, profile, launch)
			out.append(t)
	return out


static func ground_y(x: float, from_y := -9999.0) -> float:
	var best := 9999.0
	for g in TrainingRoom.GROUND:
		if x >= g[0] and x <= g[0] + g[2]:
			best = minf(best, g[1])
	for p in TrainingRoom.PLATFORMS:
		if x >= p[0] and x <= p[0] + p[2] and p[1] >= from_y - 2.0:
			best = minf(best, p[1])
	return best


func _ready() -> void:
	max_life = life
	if kind != "spur":
		x0 = global_position.x
	if world.stage != null and kind != "brocken":
		_light = world.stage.make_light(Color(1.0, 0.55, 0.25), 0.0, 0.55)
		if _light != null:
			add_child(_light)
			_light.position = Vector2(0, -8)


func _report(targets: Array) -> void:
	if targets.size() > 0 and caster != null and is_instance_valid(caster):
		caster.on_zug_hit(zug_id, targets)


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	match kind:
		"brocken":
			_update_chunk(delta)
		"lache", "krater", "spur":
			_update_ground_fire(delta)
		"welle":
			_update_wave(delta)
		"schild":
			_update_shield(delta)
	if _light != null:
		var fade := clampf(life / 0.3, 0.0, 1.0) * clampf(_t / 0.1, 0.0, 1.0)
		_light.energy = (1.1 + 0.25 * sin(_t * 23.0) + 0.15 * sin(_t * 9.0)) * fade
	if life <= 0.0:
		queue_free()
	queue_redraw()


# --- brocken ---------------------------------------------------------------

func _update_chunk(delta: float) -> void:
	var old := global_position
	vel.y += 760.0 * delta
	global_position += vel * delta
	_emit -= delta
	if _emit <= 0.0:
		_emit = 0.02
		fx.glow(global_position, GlutFx.heat(0.75), size * 3.4, 0.3, Vector2.ZERO, 0.15)
		fx.flame(global_position, size * 1.2, Vector2(-vel.x * 0.05, -20.0), 0.22, 0.85)
		if randf() < 0.5:
			fx.embers(global_position, 1, 1.0, 10.0, 0.5)
		if randf() < 0.25:
			fx.smoke(global_position, size * 1.5, Vector2(0, -10), 0.6)
	var r := Rect2(global_position - Vector2(size, size) * 1.6, Vector2(size, size) * 3.2)
	var hit := strike(world, r, damage, global_position.x - vel.x, 60.0, "light", 0.0, _hit)
	if hit.size() > 0:
		_report(hit)
		_land(true)
		return
	var gy := ground_y(global_position.x, old.y)
	if vel.y > 0.0 and old.y <= gy and global_position.y >= gy:
		global_position.y = gy
		_land(false)


func _land(on_target: bool) -> void:
	var p := global_position
	if params.get("big", false):
		var rad: float = params.get("radius", 40)
		fx.anvil(p, rad * 0.8, 9)
		fx.ring(p, rad, GlutFx.heat(0.7), 0.35, 6.0)
		fx.slag_burst(p, 14, 220.0)
		fx.sparks(p, -PI / 2.0, 1.2, 26, 300.0, 0.6)
		for i in 5:
			fx.smoke(p + Vector2(randf_range(-12, 12), -6), randf_range(10, 16), Vector2(randf_range(-20, 20), -30), 1.2)
		fx.word(p + Vector2(0, -30), "BUMM!", GlutFx.heat(0.85), 30)
		world.fx.shake(5.0 * FxSettings.factor("shake"))
		var targets := strike(world, Rect2(p - Vector2(rad, rad), Vector2(rad, rad) * 2.0), damage, p.x, 160.0, "heavy", 140.0, _hit)
		_report(targets)
	else:
		fx.slag_burst(p, 5, 120.0)
		fx.sparks(p, -PI / 2.0, 1.0, 6, 160.0, 0.35)
		fx.glow(p, GlutFx.heat(0.8), 10.0, 0.2)
	var pool: float = params.get("pool_time", 0.0)
	if pool > 0.0 and not on_target:
		var h := GlutHazard.new()
		h.world = world
		h.fx = fx
		h.caster = caster
		h.zug_id = zug_id
		h.kind = "lache"
		h.life = pool
		h.damage = params.get("pool_damage", 3)
		h.size = 22.0 if not params.get("big", false) else 40.0
		h.global_position = Vector2(p.x, ground_y(p.x, p.y - 4.0))
		world.attacks.add_child.call_deferred(h)
	life = 0.0


# --- lache, krater, spur -------------------------------------------------------

func _area() -> Rect2:
	match kind:
		"spur":
			return Rect2(minf(x0, x1), global_position.y - 10, absf(x1 - x0), 12)
		"krater":
			return Rect2(global_position.x - size, global_position.y - 14, size * 2.0, 16)
	return Rect2(global_position.x - size / 2.0, global_position.y - 12, size, 14)


func _update_ground_fire(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.4 if kind != "spur" else 0.3
		var targets := strike(world, _area(), damage, global_position.x, 10.0, "light", 0.0, null, element)
		_report(targets)
	_emit -= delta
	var fade := clampf(life / 0.5, 0.0, 1.0)
	if _emit <= 0.0:
		_emit = 0.045
		var a := _area()
		var n := maxi(1, int(a.size.x / 14.0))
		for i in n:
			if randf() < 0.65 * fade:
				var x := randf_range(a.position.x + 2, a.end.x - 2)
				var y := a.end.y - 2.0
				fx.flame(Vector2(x, y), randf_range(3.0, 6.0) * (0.6 + 0.4 * fade), Vector2(randf_range(-8, 8), randf_range(-60, -30)), randf_range(0.3, 0.5), 0.75)
		if randf() < 0.3 * fade:
			fx.embers(Vector2(randf_range(a.position.x, a.end.x), a.end.y - 4), 1, 2.0, 40.0, 0.9)
		if randf() < 0.12:
			fx.smoke(Vector2(randf_range(a.position.x, a.end.x), a.end.y - 10), 8.0, Vector2(randf_range(-6, 6), -18), 1.3)
	if _light != null and kind == "spur":
		_light.position = Vector2((x0 + x1) * 0.5 - global_position.x, -8)


# --- welle -----------------------------------------------------------------

func _update_wave(delta: float) -> void:
	var reach: float = params.get("wave", 50)
	var speed := 320.0
	var travelled := absf(global_position.x - x0)
	if travelled < reach:
		global_position.x += dir * speed * delta
		global_position.y = ground_y(global_position.x, global_position.y - 6.0)
		if global_position.y > 2000.0:
			life = 0.0
			return
	else:
		life = minf(life, 0.15)
	var h := 22.0 + 8.0 * sin(_t * 30.0)
	var r := Rect2(global_position.x - 8, global_position.y - h, 16, h)
	var targets := strike(world, r, damage, global_position.x - dir * 20.0, 90.0, "heavy", 180.0, _hit)
	_report(targets)
	_emit -= delta
	if _emit <= 0.0:
		_emit = 0.02
		fx.flame(global_position + Vector2(randf_range(-4, 4), -2), randf_range(5, 9), Vector2(dir * 30.0, randf_range(-160, -90)), 0.35, 0.95)
		fx.sparks(global_position + Vector2(0, -4), -PI / 2.0 + dir * 0.4, 0.5, 2, 200.0, 0.4)
		if randf() < 0.3:
			fx.smoke(global_position + Vector2(0, -12), 9.0, Vector2(dir * 10.0, -20), 0.9)


# --- schild ----------------------------------------------------------------

func _update_shield(delta: float) -> void:
	var length: float = params.get("len", 60)
	var o := global_position
	var r := Rect2(o.x if dir > 0.0 else o.x - length, o.y - 22, length, 40)
	for pr in get_tree().get_nodes_in_group("enemy_projectiles"):
		if pr.has_method("get_hurt_rect") and r.intersects(pr.get_hurt_rect()):
			pr.burn()
			fx.anvil(pr.global_position, 14.0, 6)
			fx.word(pr.global_position + Vector2(0, -18), "ZSSH!", GlutFx.heat(0.9), 22)
	_emit -= delta
	if _emit <= 0.0:
		_emit = 0.03
		fx.sparks(o, 0.0 if dir > 0.0 else PI, 0.35, 4, length * 6.0, 0.35, 300.0)
		fx.glow(o + Vector2(dir * length * 0.4, 0), GlutFx.heat(0.6), length * 0.35, 0.12, Vector2.ZERO, 0.8)


# --- draw (dark slag body; the glow comes from GlutFx) ------------------------

func _draw() -> void:
	match kind:
		"brocken":
			var s := size * (1.6 if params.get("big", false) else 1.0)
			var pts := PackedVector2Array()
			for i in 7:
				var a := TAU * i / 7.0 + _t * 6.0
				pts.append(Vector2(cos(a), sin(a)) * s * (0.8 + 0.3 * sin(i * 2.7)))
			draw_colored_polygon(pts, Color("2a1414"))
			draw_circle(Vector2.ZERO, s * 0.55, GlutFx.heat(0.8))
			draw_circle(Vector2(-s * 0.15, -s * 0.15), s * 0.25, GlutFx.heat(1.0))
		"lache", "krater":
			var fade := clampf(life / 0.5, 0.0, 1.0)
			var w := size if kind == "lache" else size * 2.0
			var c := GlutFx.heat(0.55 + 0.1 * sin(_t * 17.0))
			draw_rect(Rect2(-w / 2.0, -2, w, 2), Color(c, 0.85 * fade))
			draw_rect(Rect2(-w / 2.0 + 3, -3, w - 6, 1), Color(GlutFx.heat(0.85), 0.8 * fade))
		"spur":
			var fade2 := clampf(life / 0.5, 0.0, 1.0)
			var lx := minf(x0, x1) - global_position.x
			var w2 := absf(x1 - x0)
			draw_rect(Rect2(lx, -2, w2, 2), Color(GlutFx.heat(0.5), 0.8 * fade2))
			var k := 0.0
			while k < w2:
				var hh := 1.0 + 1.5 * (0.5 + 0.5 * sin(_t * 20.0 + k * 0.7))
				draw_rect(Rect2(lx + k, -2 - hh, 2, hh), Color(GlutFx.heat(0.8), 0.7 * fade2))
				k += 5.0
