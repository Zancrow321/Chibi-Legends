class_name FeuerGeschoss
extends Node2D
## A flying fire attack of Lauffeuer: the Flammenfaust (grows while it flies,
## ignites every Brandherd it touches) and the shots of Glühender
## Niederschlag (diagonal, burst on the ground). Drawn with the PixelLab
## strips, glowing additively.

var caster: FeuerCaster
var zug_id := ""
var kind := "faust"  # "faust" or "stoss"
var vel := Vector2.ZERO
var dist := 300.0
var damage := 16.0
var size := 1.0
var pierce := false
var ignites := true
var herd_on_land := false
var ground_burn := false
var kb := 140.0
var profile := "heavy"
var _flown := 0.0
var _hit: Dictionary = {}
var _strip: FeuerStrip
var _t := 0.0
var _done := false


func _ready() -> void:
	z_index = 5
	if kind == "faust":
		_strip = FeuerStrip.spawn(self, "flammenfaust", Vector2.ZERO, {"size": size * 1.25, "hdr": 1.35, "flip": vel.x < 0.0, "frame_override": 0})
	else:
		_strip = FeuerStrip.spawn(self, "feuerstrom", Vector2.ZERO, {"size": 0.55 * size, "hdr": 1.3, "loop": true})
		_strip.rotation = vel.angle()


func _rect() -> Rect2:
	var w := (42.0 if kind == "faust" else 16.0) * size
	var h := (30.0 if kind == "faust" else 14.0) * size
	return Rect2(global_position - Vector2(w / 2.0, h / 2.0), Vector2(w, h))


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var step := vel * delta
	global_position += step
	_flown += step.length()
	var room := caster.world
	if kind == "faust":
		# grows from the hand to full size over the first third
		var k := clampf(_flown / maxf(1.0, dist), 0.0, 1.0)
		_strip.frame_override = clampi(int(k * 8.0), 0, 8)
		if fmod(_t, 0.03) < delta:
			caster.fx.flame(global_position - Vector2(signf(vel.x) * 26.0 * size, 0), 7.0 * size, Vector2(-vel.x * 0.15, -30), 0.3)
			caster.fx.embers(global_position, 1, 10.0 * size, 50.0, 0.6)
		caster.fx.light(global_position, Color(1.0, 0.6, 0.3), 1.6 * size, 0.7, 0.05)
	elif fmod(_t, 0.04) < delta:
		caster.fx.flame(global_position, 5.0 * size, Vector2(0, -30), 0.25)
	# Brandherde in the way erupt
	if ignites:
		var r := _rect().grow(4.0)
		for h in caster.herde.duplicate():
			if is_instance_valid(h) and r.intersects(h.hit_area()):
				h.ignite(1.0, 0.0)
	var hit := GlutHazard.strike(room, _rect(), damage, global_position.x - signf(vel.x) * 40.0, kb, profile, 0.0, _hit)
	if not hit.is_empty():
		caster.on_zug_hit(zug_id, hit)
		for tg in hit:
			var c: Vector2 = tg.get_hurt_rect().get_center()
			caster.fx.anvil(c, 16.0, 8)
			caster.fx.word(c + Vector2(0, -34), "FWOOSH!", Color("ffc94a"), 22)
		room.fx.shake(4.0 * FxSettings.factor("shake"), signf(vel.x))
		room.fx.freeze(0.05 * FxSettings.factor("stop"))
		if not pierce:
			_burst()
			return
	if kind == "stoss":
		var gy := GlutHazard.ground_y(global_position.x, global_position.y - 4.0)
		if global_position.y >= gy - 2.0:
			global_position.y = gy
			_land()
			return
	if _flown >= dist:
		_burst()


## End of the fist's flight: a bright burst.
func _burst() -> void:
	_done = true
	var p := global_position
	if is_instance_valid(_strip):
		_strip.queue_free()
	FeuerStrip.spawn(caster.world.attacks, "einschlag", p + Vector2(0, 6), {"size": 0.55 * size, "hdr": 1.3, "speed": 1.6})
	caster.fx.glow(p, Color(1.0, 0.85, 0.5, 0.9), 22.0 * size, 0.25)
	caster.fx.sparks(p, 0.0 if vel.x > 0.0 else PI, 1.0, 10, 220.0, 0.4)
	queue_free()


## A shot reaches the ground: impact, maybe a Brandherd or burning ground.
func _land() -> void:
	_done = true
	var p := global_position
	if is_instance_valid(_strip):
		_strip.queue_free()
	var room := caster.world
	FeuerStrip.spawn(room.attacks, "einschlag", p + Vector2(0, 8), {"anchor": "bottom", "size": 0.7 * size, "hdr": 1.3})
	caster.fx.ring(p + Vector2(0, -4), 22.0 * size, Color("ff8a2a"), 0.3, 4.0)
	caster.fx.word(p + Vector2(0, -40), "FSSSH!", Color("ffc94a"), 18)
	var hs := _hit
	var tg := GlutHazard.strike(room, Rect2(p.x - 22.0 * size, p.y - 28.0, 44.0 * size, 30.0), damage * 0.6, p.x, 100.0, "heavy", 120.0, hs)
	caster.on_zug_hit(zug_id, tg)
	if herd_on_land:
		caster.place_herd(p.x, p.y)
	if ground_burn:
		caster.burning_ground(p, 1.5, 26.0)
	queue_free()
