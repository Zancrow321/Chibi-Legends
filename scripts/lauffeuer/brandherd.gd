class_name Brandherd
extends Node2D
## A Brandherd of Lauffeuer: a small flickering fire on the ground. It does
## no damage by itself. Touched by a Flammenfaust (or a Meisterzug) it is
## used up and erupts: a column of fire that hits and sets Brand. Several
## eruptions on the same target lose damage (100 / 70 / 40 % within 1 s).
## At most 3 at once (the caster removes the oldest).

const LIFE := 6.0
const RADIUS := 18.0
const OUTBREAK := 15.0  # ~120 % of a light hit

var caster: FeuerCaster
var life := LIFE
var wide := 1.0  # wider with wind (later)
var _strip: FeuerStrip
var _t := 0.0
var _gone := false
var _seen: Dictionary = {}  # attacks that already touched this Brandherd


func _ready() -> void:
	z_index = 3
	_strip = FeuerStrip.spawn(self, "brandherd", Vector2(0, 2), {"anchor": "bottom", "size": 0.9 * wide, "hdr": 0.75, "alpha": 0.85, "loop": true})
	caster.fx.glow(global_position + Vector2(0, -6), Color(1.0, 0.55, 0.2, 0.7), 16.0, 0.3)
	caster.fx.embers(global_position + Vector2(0, -4), 6, 8.0, 40.0, 0.7)


func _process(delta: float) -> void:
	if _gone:
		return
	_t += delta
	life -= delta
	if life < 0.6:
		_strip.alpha = 0.85 * maxf(0.0, life / 0.6)
	if life <= 0.0:
		caster.fx.smoke(global_position + Vector2(0, -4), 7.0, Vector2(0, -20), 0.8)
		remove()
		return
	_element_check()
	if fmod(_t, 0.18) < delta:
		caster.fx.embers(global_position + Vector2(randf_range(-6, 6), -6), 1, 4.0, 30.0, 0.6)
	if fmod(_t, 0.12) < delta:
		var f := 0.6 + 0.3 * sin(_t * 17.0)
		caster.fx.light(global_position + Vector2(0, -8), Color(1.0, 0.55, 0.25), f, 0.35, 0.14)
	queue_redraw()


## Wind fans the fire (+50 % width, once); water shortens it and steams.
func _element_check() -> void:
	var area := hit_area().grow(6.0)
	for a in caster.world.attacks.get_children():
		var el = a.get("element")
		if not (el is String) or el == "" or el == "feuer" or not (a is Node2D):
			continue
		if not area.has_point(a.global_position) or _seen.has(a.get_instance_id()):
			continue
		_seen[a.get_instance_id()] = true
		if el == "wind" and wide < 1.5:
			wide = 1.5
			_strip.size = 0.9 * wide
			caster.fx.ring(global_position + Vector2(0, -6), 26.0, Color("9cf2b4"), 0.3, 3.0)
			caster.fx.word(global_position + Vector2(0, -40), "ANGEFACHT!", Color("9cf2b4"), 16)
		elif el in ["wasser", "frost"]:
			if life < 1.0:
				life = 0.0
			else:
				life *= 0.5
			for i in 4:
				caster.fx.smoke(global_position + Vector2(randf_range(-10, 10), -8), 10.0, Vector2(0, -30), 1.0)
			caster.fx.word(global_position + Vector2(0, -40), "DAMPF", Color("e8eef2"), 16)


func remove() -> void:
	if _gone:
		return
	_gone = true
	caster.herde.erase(self)
	queue_free()


func hit_area() -> Rect2:
	return Rect2(global_position - Vector2(RADIUS * wide, 26), Vector2(RADIUS * 2.0 * wide, 30))


## The eruption. `mul` scales the damage (Meisterzug), `delay` lets chains
## go off one after another (domino feel).
func ignite(mul := 1.0, delay := 0.0) -> void:
	if _gone:
		return
	_gone = true
	caster.herde.erase(self)
	if delay > 0.0:
		visible = true
		await get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(caster):
		queue_free()
		return
	var room := caster.world
	var p := global_position
	FeuerStrip.spawn(room.attacks, "ausbruch", p + Vector2(0, 4), {"anchor": "bottom", "size": 2.0 * wide, "hdr": 1.3})
	caster.fx.glow(p + Vector2(0, -40), Color(1.0, 0.7, 0.3, 0.9), 34.0, 0.35, Vector2(0, -40))
	caster.fx.ring(p + Vector2(0, -6), 26.0 * wide, Color("ffc94a"), 0.3, 4.0)
	caster.fx.sparks(p + Vector2(0, -20), -PI / 2.0, 0.5, 14, 300.0, 0.6)
	caster.fx.light(p + Vector2(0, -40), Color(1.0, 0.65, 0.3), 2.6, 0.9, 0.35)
	caster.fx.word(p + Vector2(0, -96), "BOOM!", Color("ffc94a"), 22 + int(caster.chain_n) * 3)
	room.fx.shake(minf(3.0 + caster.chain_n * 1.5, 9.0) * FxSettings.factor("shake"))
	caster.chain_n += 1
	Sfx.play("hit_heavy", -4.0)
	Sfx.play("lauf_impact", -4.0)
	var out: Array = []
	var area := Rect2(p.x - 22.0 * wide, p.y - 110.0, 44.0 * wide, 112.0)
	for tg in room.get_tree().get_nodes_in_group("targets"):
		if area.intersects(tg.get_hurt_rect()):
			var k := caster.outbreak_factor(tg)
			room.deal_hit(tg, OUTBREAK * mul * k, "feuer", p.x, 60.0, "heavy", 300.0 * k)
			out.append(tg)
	caster.on_zug_hit("herd", out)
	queue_free()
