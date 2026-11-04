class_name SuperBeam
extends Node2D
## Super move "Legendenstrahl": the full fighting-game super sequence.
##  1. Super flash: world freezes, screen dims, rays and aura around the
##     caster, camera punches in, cut-in banner on the HUD.
##  2. Charge: an energy orb grows at the hand and sucks in particles.
##  3. Beam: a huge glowing beam, multi-hit with continuous shake.
##  4. Finale: big blast on every target hit, hit-stop and white flash.
## Always processes (it runs during the super pause), but respects hit-stop.

enum Phase { FLASH, CHARGE, BEAM, END }

const FLASH_TIME := 0.8
const CHARGE_TIME := 0.3
const BEAM_TIME := 1.1
const END_TIME := 0.35
const LENGTH := 470.0
const HEIGHT := 30.0
const TICK := 0.09
const BEAM_COLOR := Color("5cc8ff")
const AURA_COLOR := Color("ffd25c")

var room: Node2D
var player: Node2D
var skill: Dictionary

var phase := Phase.FLASH
var _t := 0.0
var _total := 0.0
var _tick := 0.0
var _len := 0.0
var _emit := 0.0
var _hit_ids: Dictionary = {}  # target id -> beam damage so far


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = CombatFx.FOCUS_Z + 2
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_follow()
	var fx: CombatFx = room.fx
	fx.hold(true)
	fx.dim(0.78)
	fx.punch(0.22)
	fx.flash(0.35, AURA_COLOR)
	player.z_index = CombatFx.FOCUS_Z
	var c := _center()
	fx.sparks.glow(c, Color.WHITE, 46.0, 0.35)
	fx.sparks.ring(c, AURA_COLOR, 60.0, 0.45)
	fx.sparks.star(c, Color("fff3c0"), 10, 70.0)
	if room.hud != null:
		room.hud.show_cutin(skill.name + "!", BEAM_COLOR)


func _center() -> Vector2:
	return player.global_position + Vector2(0, -22)


func _follow() -> void:
	global_position = player.global_position + Vector2(player.facing * 18.0, -24.0)
	scale.x = player.facing


func _process(delta: float) -> void:
	var fx: CombatFx = room.fx
	if phase != Phase.FLASH and fx.is_frozen():
		queue_redraw()
		return  # hit-stop: freeze with the world
	_t += delta
	_total += delta
	_follow()
	match phase:
		Phase.FLASH:
			_emit_aura(delta)
			if _t >= FLASH_TIME:
				_next(Phase.CHARGE)
				fx.hold(false)
				fx.dim(0.45)
		Phase.CHARGE:
			_emit_charge(delta)
			fx.shake(2.0 * FxSettings.factor("shake"))
			if _t >= CHARGE_TIME:
				_next(Phase.BEAM)
				fx.flash(0.4 * FxSettings.factor("flash"), BEAM_COLOR)
				fx.punch(0.06)
		Phase.BEAM:
			_len = minf(LENGTH, _len + delta * LENGTH * 8.0)
			fx.shake(3.0 * FxSettings.factor("shake"))
			_emit_beam(delta)
			_tick -= delta
			if _tick <= 0.0:
				_tick = TICK
				_hit_targets(false)
			if _t >= BEAM_TIME:
				_next(Phase.END)
				_hit_targets(true)
				fx.dim(0.0)
		Phase.END:
			if _t >= END_TIME:
				_finish()
	queue_redraw()


func _next(p: Phase) -> void:
	phase = p
	_t = 0.0


func _finish() -> void:
	player.z_index = 0
	player.in_super = false
	room.fx.dim(0.0)
	queue_free()


func _beam_rect() -> Rect2:
	var h := HEIGHT * 1.2
	var x := global_position.x if player.facing > 0 else global_position.x - _len
	return Rect2(x, global_position.y - h / 2.0, _len, h)


func _hit_targets(final: bool) -> void:
	var rect := _beam_rect()
	for t in get_tree().get_nodes_in_group("targets"):
		if final:
			if _hit_ids.has(t.get_instance_id()):
				var c: Vector2 = t.get_hurt_rect().get_center()
				var total: int = _hit_ids[t.get_instance_id()]
				total += room.deal_hit(t, skill.final_damage, skill.element, player.global_position.x, 220.0, "super_final")
				room.numbers.spawn_number(t.head_position() + Vector2(0, -14), total, BEAM_COLOR, t.get_instance_id() + 1, true)
				room.fx.blast(c, BEAM_COLOR, 70.0, "super_final")
		elif rect.intersects(t.get_hurt_rect()):
			var id: int = t.get_instance_id()
			_hit_ids[id] = _hit_ids.get(id, 0) + room.deal_hit(t, skill.damage, skill.element, player.global_position.x, 30.0, "super")
	if final and _hit_ids.is_empty():
		var end := global_position + Vector2(player.facing * _len, 0)
		room.fx.blast(end, BEAM_COLOR, 60.0, "super_final")


# --- particles -------------------------------------------------------------

func _emit_aura(delta: float) -> void:
	var sp: HitSparks = room.fx.sparks
	_emit += delta
	while _emit > 0.02:
		_emit -= 0.02
		var base := player.global_position + Vector2(randf_range(-14, 14), randf_range(-6, 0))
		sp.flame(base, AURA_COLOR if randf() < 0.7 else Color.WHITE, randf_range(4, 8), Vector2(randf_range(-10, 10), randf_range(-140, -70)), 0.45)
		var ang := randf() * TAU
		var from := _center() + Vector2(cos(ang), sin(ang)) * randf_range(60, 100)
		sp.streak(from, Color("fff3c0"), (_center() - from) * 4.0, 0.22)


func _emit_charge(delta: float) -> void:
	var sp: HitSparks = room.fx.sparks
	_emit += delta
	while _emit > 0.015:
		_emit -= 0.015
		var ang := randf() * TAU
		var from := global_position + Vector2(cos(ang), sin(ang)) * randf_range(30, 60)
		sp.streak(from, BEAM_COLOR, (global_position - from) * 6.0, 0.16)


func _emit_beam(delta: float) -> void:
	var sp: HitSparks = room.fx.sparks
	_emit += delta
	var f: float = player.facing
	while _emit > 0.012:
		_emit -= 0.012
		var x := randf() * _len
		var y := randf_range(-HEIGHT * 0.6, HEIGHT * 0.6)
		sp.streak(global_position + Vector2(x * f, y), Color("c8f0ff"), Vector2(f * randf_range(500, 900), y * 2.0), 0.18)
	if randf() < 0.5:
		var end := global_position + Vector2(f * _len, randf_range(-12, 12))
		sp.flame(end, BEAM_COLOR, randf_range(6, 12), Vector2(f * 60.0, randf_range(-80, 80)), 0.3)


# --- drawing (local space, beam points to +x) ------------------------------

func _draw() -> void:
	var glow := HitSparks.glow_texture()
	match phase:
		Phase.FLASH:
			_draw_rays(to_local(_center()), minf(1.0, _t / 0.15) * (1.0 - _t / FLASH_TIME * 0.4))
		Phase.CHARGE:
			var r := 6.0 + 18.0 * (_t / CHARGE_TIME)
			r += sin(_total * 60.0) * 1.5
			draw_texture_rect(glow, Rect2(Vector2(-r, -r) * 2.0, Vector2(r, r) * 4.0), false, Color(BEAM_COLOR, 0.7))
			draw_circle(Vector2.ZERO, r * 0.6, Color(1, 1, 1, 0.9))
		Phase.BEAM, Phase.END:
			var k := 1.0
			if phase == Phase.END:
				k = 1.0 - _t / END_TIME
			_draw_beam(k * k, glow)


func _draw_rays(c: Vector2, a: float) -> void:
	var n := 14
	for i in n:
		var ang := _total * 1.4 + TAU * i / n
		var w := 0.09
		var l := 260.0
		var pts := PackedVector2Array([c, c + Vector2(cos(ang - w), sin(ang - w)) * l, c + Vector2(cos(ang + w), sin(ang + w)) * l])
		var col := AURA_COLOR if i % 2 == 0 else Color.WHITE
		draw_colored_polygon(pts, Color(col, 0.22 * a))
	var glow := HitSparks.glow_texture()
	var r := 40.0 + sin(_total * 30.0) * 4.0
	draw_texture_rect(glow, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(AURA_COLOR, 0.8 * a))


func _draw_beam(k: float, glow: Texture2D) -> void:
	var h := HEIGHT * k * (0.9 + 0.1 * sin(_total * 45.0))
	var l := _len
	# outer glow layers
	for i in 3:
		var hh := h * (2.2 - i * 0.45)
		draw_rect(Rect2(0, -hh / 2.0, l, hh), Color(BEAM_COLOR, 0.12 + i * 0.06))
	# body and hot core
	draw_rect(Rect2(0, -h / 2.0, l, h), Color(BEAM_COLOR, 0.75))
	draw_rect(Rect2(0, -h * 0.22, l, h * 0.44), Color(1, 1, 1, 0.95))
	# travelling bulges on the edges
	var x := fmod(_total * 700.0, 36.0)
	while x < l:
		var b := 3.0 + 2.0 * sin(x * 0.2 + _total * 20.0)
		draw_rect(Rect2(x, -h / 2.0 - b, 14, b), Color(BEAM_COLOR, 0.6 * k))
		draw_rect(Rect2(x + 18, h / 2.0, 14, b), Color(BEAM_COLOR, 0.6 * k))
		x += 36.0
	# muzzle and impact flares
	var r := h * 1.6
	draw_texture_rect(glow, Rect2(Vector2(-r, -r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, k))
	var re := h * 1.3 + sin(_total * 50.0) * 3.0
	draw_texture_rect(glow, Rect2(Vector2(l - re, -re), Vector2(re, re) * 2.0), false, Color(BEAM_COLOR, k))
	draw_circle(Vector2(l, 0), h * 0.45, Color(1, 1, 1, 0.9 * k))
