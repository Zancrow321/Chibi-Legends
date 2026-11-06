class_name FormHazard
extends Node2D
## Things a Baukasten Zug leaves in the world (scripts/formen):
##  shot    projectile: straight, ballistic (grav), homing or boomerang;
##          pierce or stop at the first target; burst = small explosion at the end
##  pillar  a column bursting out of the ground (Säule), hits once, launches
##  wave    glow wave rolling along the ground, hits each target once
##  zone    field on the ground: ticks, may pull targets to its centre
##  drop    falling piece of a Regen, hits on the way down and bursts on the ground
## Hits go through the caster (FormCaster.strike_for), so the style's Kern
## (marks, echo, charge ...) sees them. The sprite is the Zug's PixelLab
## effect, drawn additive (bloom).

var world: TrainingRoom
var caster: FormCaster
var zug_id := ""
var fx_id := ""
var kind := "shot"
var damage := 8.0
var life := 2.0
var max_life := 2.0
var vel := Vector2.ZERO
var size := 1.0
var dir := 1.0
var params: Dictionary = {}
var col := Color.WHITE
var width := 60.0
var height := 80.0
var _hit: Dictionary = {}
var _tick := 0.0
var _t := 0.0
var _start := Vector2.ZERO
var _back := false
var _gone := false


func _ready() -> void:
	max_life = life
	_start = global_position
	z_index = CombatFx.FOCUS_Z + 2
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m


func _strike(rect: Rect2, dmg: float, kb: float, profile := "", launch := 0.0, hs = null) -> Array:
	if caster == null or not is_instance_valid(caster):
		return GlutHazard.strike(world, rect, dmg, global_position.x - dir * 20.0, kb, profile, launch, hs, "")
	return caster.strike_for(zug_id, rect, dmg, kb, profile, launch, hs, global_position.x - dir * 20.0)


func _radius() -> float:
	return 9.0 * size


func _physics_process(delta: float) -> void:
	if world == null or world.fx.is_frozen():
		return
	_t += delta
	life -= delta
	match kind:
		"shot":
			_tick_shot(delta)
		"pillar":
			_tick_pillar()
		"wave":
			_tick_wave(delta)
		"zone":
			_tick_zone(delta)
		"drop":
			_tick_drop(delta)
	if life <= 0.0 and not _gone:
		_gone = true
		if kind == "shot" and bool(params.get("burst", false)):
			_burst()
		queue_free()
	queue_redraw()


# --- shot -------------------------------------------------------------------------

func _nearest() -> Node2D:
	var best: Node2D = null
	var best_d := 260.0
	for t in get_tree().get_nodes_in_group("targets"):
		var c: Vector2 = t.get_hurt_rect().get_center()
		if _hit.has(t.get_instance_id()):
			continue
		var d := c.distance_to(global_position)
		if d < best_d and signf(c.x - global_position.x) * signf(vel.x) >= -0.2:
			best = t
			best_d = d
	return best


func _tick_shot(delta: float) -> void:
	var homing := float(params.get("homing", 0.0))
	if homing > 0.0 and not _back:
		var tg := _nearest()
		if tg != null:
			var want: Vector2 = (tg.get_hurt_rect().get_center() - global_position).normalized() * vel.length()
			vel = vel.lerp(want, clampf(homing * delta * 4.0, 0.0, 1.0))
	var grav := float(params.get("grav", 0.0))
	vel.y += grav * delta
	if bool(params.get("boomerang", false)):
		var dist := float(params.get("dist", 240))
		if not _back and global_position.distance_to(_start) >= dist:
			_back = true
			_hit = {}
		if _back and caster != null and is_instance_valid(caster):
			var home: Vector2 = caster.player.global_position + Vector2(0, -24)
			vel = (home - global_position).normalized() * maxf(vel.length(), 300.0)
			if global_position.distance_to(home) < 16.0:
				life = 0.0
	global_position += vel * delta
	var r := _radius()
	var rect := Rect2(global_position - Vector2(r, r), Vector2(r, r) * 2.0)
	var pierce := bool(params.get("pierce", false)) or bool(params.get("boomerang", false))
	var hits := _strike(rect, damage, 80.0 if pierce else 140.0, "heavy" if size >= 1.4 else "", 0.0, _hit)
	if hits.size() > 0:
		if caster != null and is_instance_valid(caster):
			caster.ffx.burst(fx_id, global_position, 34.0 * size, 0.18, randf() * TAU, false, col)
		if not pierce:
			life = 0.0
	# ground: ballistic shots break on the floor
	if grav > 0.0 and global_position.y >= GlutHazard.ground_y(global_position.x, global_position.y - 8.0):
		life = 0.0
	if not bool(params.get("boomerang", false)) and global_position.distance_to(_start) > float(params.get("dist", 320)):
		life = 0.0


func _burst() -> void:
	var r := 34.0 * maxf(1.0, size)
	_strike(Rect2(global_position - Vector2(r, r), Vector2(r, r) * 2.0), damage * 0.7, 150.0, "heavy", 80.0, {})
	if caster != null and is_instance_valid(caster):
		caster.ffx.burst(fx_id, global_position, r * 2.4, 0.35, 0.0, false, col)
		caster.ffx.ring(global_position, r * 1.2, col, 0.3, 4.0)
		caster.ffx.shards(global_position, 0.0, PI, 12, 220.0, col.lightened(0.4))
	world.fx.shake(3.0 * FxSettings.factor("shake"))


# --- pillar ----------------------------------------------------------------------

func _tick_pillar() -> void:
	if _t < 0.03:
		return
	var rect := Rect2(global_position.x - width * 0.5, global_position.y - height, width, height)
	_strike(rect, damage, 40.0, "heavy", float(params.get("launch", 300)), _hit)


# --- wave ------------------------------------------------------------------------

func _tick_wave(delta: float) -> void:
	global_position.x += dir * 260.0 * delta
	var gy := GlutHazard.ground_y(global_position.x, global_position.y - 30.0)
	if gy > 9000.0:
		life = 0.0
		return
	global_position.y = gy
	var rect := Rect2(global_position.x - 12.0, global_position.y - 22.0, 24.0, 22.0)
	_strike(rect, damage, 120.0, "", 160.0, _hit)


# --- zone ------------------------------------------------------------------------

func _tick_zone(delta: float) -> void:
	_tick -= delta
	var rect := Rect2(global_position.x - width * 0.5, global_position.y - 46.0, width, 48.0)
	var pull := float(params.get("pull", 0.0))
	if pull != 0.0:
		for t in get_tree().get_nodes_in_group("targets"):
			if not (t is Node2D):
				continue
			var tn: Node2D = t
			if rect.grow(30.0).intersects(t.get_hurt_rect()) and not tn.is_in_group("bosses"):
				var dx := global_position.x - tn.global_position.x
				if absf(dx) > 4.0:
					tn.global_position.x += signf(dx) * minf(absf(dx), pull * delta)
	if _tick <= 0.0:
		_tick = float(params.get("tick", 0.35))
		_strike(rect, damage, 20.0, "light", float(params.get("launch", 0.0)), {})


# --- drop (Regen) ------------------------------------------------------------------

func _tick_drop(delta: float) -> void:
	global_position += vel * delta
	var r := _radius()
	_strike(Rect2(global_position - Vector2(r, r * 1.6), Vector2(r * 2.0, r * 3.2)), damage, 60.0, "", 0.0, _hit)
	var gy := GlutHazard.ground_y(global_position.x, global_position.y - 10.0)
	if global_position.y >= gy:
		global_position.y = gy
		if caster != null and is_instance_valid(caster):
			caster.ffx.burst(fx_id, global_position + Vector2(0, -10), 30.0 * size, 0.22, 0.0, false, col)
			caster.ffx.shards(global_position, -PI / 2.0, 1.0, 5, 160.0, col.lightened(0.4))
		_strike(Rect2(global_position - Vector2(r * 2.0, r * 2.0), Vector2(r * 4.0, r * 2.2)), damage * 0.5, 80.0, "", 0.0, _hit)
		life = 0.0


# --- draw ------------------------------------------------------------------------

func _draw() -> void:
	var t := FederFx.tex(fx_id)
	var fade := clampf(life / 0.15, 0.0, 1.0)
	match kind:
		"shot", "drop":
			var s := 30.0 * size
			var spin := _t * 9.0 if bool(params.get("boomerang", false)) else (vel.angle() if kind == "drop" or float(params.get("grav", 0.0)) > 0.0 else 0.0)
			draw_set_transform(Vector2.ZERO, spin, Vector2(-1.0 if vel.x < 0.0 and kind == "shot" else 1.0, 1.0))
			_glow(Vector2.ZERO, s * 0.8, Color(col, 0.35 * fade))
			if t != null:
				draw_texture_rect(t, Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, fade))
			else:
				draw_circle(Vector2.ZERO, s * 0.3, Color(col, fade))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"pillar":
			var k := clampf(_t / 0.12, 0.0, 1.0)
			var a := clampf(life / maxf(0.01, max_life * 0.5), 0.0, 1.0)
			var h := height * (0.35 + 0.65 * k)
			var r := Rect2(-width * 0.8, -h, width * 1.6, h)
			if t != null:
				draw_texture_rect(t, r, false, Color(1, 1, 1, a))
			else:
				draw_rect(r, Color(col, 0.5 * a))
			_glow(Vector2(0, -h * 0.4), width, Color(col, 0.25 * a))
		"wave":
			var a2 := clampf(life / 0.3, 0.0, 1.0)
			if t != null:
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(dir, 1.0))
				draw_texture_rect(t, Rect2(Vector2(-18, -32), Vector2(36, 34)), false, Color(1, 1, 1, a2))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_glow(Vector2(0, -8), 18.0, Color(col, 0.4 * a2))
		"zone":
			var a3 := clampf(life / 0.4, 0.0, 1.0) * clampf(_t / 0.15, 0.0, 1.0)
			var pulse := 0.85 + 0.15 * sin(_t * 9.0)
			if t != null:
				draw_texture_rect(t, Rect2(-width * 0.6, -width * 0.55, width * 1.2, width * 0.6), false, Color(1, 1, 1, 0.75 * a3 * pulse))
			_glow(Vector2(0, -6), width * 0.6, Color(col, 0.22 * a3))
			draw_rect(Rect2(-width * 0.5, -3, width, 3), Color(col, 0.6 * a3))


func _glow(pos: Vector2, r: float, c: Color) -> void:
	draw_texture_rect(GlutFx.glow_texture(), Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0), false, c)
