class_name Enemy
extends Node2D
## A real enemy of the combat areas. Unlike the dummies it has HP, notices
## the player, walks or hops over, telegraphs its attack (red pulse and a
## "!"), hits the player through Player.receive_hit(), staggers when hit,
## can be juggled, burns with Brand and dies with a little show (and EXP).
##
## The look comes from animation strips in res://assets/enemies/<id>/ and
## their frame data in assets/enemies/frames.json (see the README there):
## Moosling and Rindenwicht are our own PixelLab sprites, Moosgolem,
## Sumpfdorn, Säbeltiger and Glutigel come from the CC0 asset
## "Duelyst Animated Sprites" (Godot Asset Library 1653).
## Motion such as hops, squash, lunges and the fire breath is code on top.
##
## Kinds:
##  slime   hops over, flattens, then lunges (body slam)
##  brute   walks, raises its weapon, smashes in front (super armour while striking)
##  beast   prowls, crouches, then pounces through the player
##  breather walks up to mid range and breathes a short cone of fire

signal died(enemy: Enemy)

const GRAVITY := 900.0
const FRAMES_JSON := "res://assets/enemies/frames.json"

## Per type: stats and attack. "hit" = attack frame where the blow lands.
const TYPES := {
	"moosling": {
		"name": "Moosling", "kind": "slime", "hp": 90.0, "speed": 95.0, "aggro": 340.0,
		"range": 70.0, "damage": 35.0, "windup": 0.5, "cooldown": 1.3, "exp": 12,
		"hurt": Vector2(24, 28), "color": Color("8fd94a"), "hit": 5, "scale": 0.75,
	},
	"rindenwicht": {
		"name": "Rindenwicht", "kind": "brute", "hp": 180.0, "speed": 58.0, "aggro": 380.0,
		"range": 52.0, "damage": 60.0, "windup": 0.6, "cooldown": 1.6, "exp": 30,
		"hurt": Vector2(26, 48), "color": Color("c8743a"), "hit": 4,
	},
	"moosgolem": {
		"name": "Moosgolem", "kind": "brute", "hp": 420.0, "speed": 40.0, "aggro": 420.0,
		"range": 84.0, "damage": 90.0, "windup": 0.85, "cooldown": 2.2, "exp": 80,
		"hurt": Vector2(60, 86), "color": Color("6aa84a"), "hit": 4, "elite": true, "scale": 2.0,
	},
	"sumpfdorn": {
		"name": "Sumpfdorn", "kind": "beast", "hp": 110.0, "speed": 120.0, "aggro": 380.0,
		"range": 90.0, "damage": 40.0, "windup": 0.4, "cooldown": 1.4, "exp": 18,
		"hurt": Vector2(50, 38), "color": Color("b8b070"), "hit": 4, "scale": 1.5,
	},
	"saebeltiger": {
		"name": "Säbeltiger", "kind": "beast", "hp": 160.0, "speed": 135.0, "aggro": 420.0,
		"range": 110.0, "damage": 55.0, "windup": 0.45, "cooldown": 1.5, "exp": 28,
		"hurt": Vector2(56, 42), "color": Color("c83a3a"), "hit": 4, "scale": 1.5,
	},
	"glutigel": {
		"name": "Glutigel", "kind": "breather", "hp": 120.0, "speed": 60.0, "aggro": 360.0,
		"range": 78.0, "damage": 14.0, "windup": 0.55, "cooldown": 2.0, "exp": 22,
		"hurt": Vector2(44, 34), "color": Color("ff9a2a"), "hit": 12, "scale": 1.5,
	},
}

static var _frames: Dictionary = {}

var world: TrainingRoom
var type_id := "moosling"
var data: Dictionary
var look: Dictionary  # cell, foot, anims from frames.json
var label := ""
var status: Dictionary = {}
var hp := 100.0
var max_hp := 100.0
var facing := -1

var state := "spawn"  # spawn, idle, move, windup, strike, recover, hurt, dead
var _st := 0.0  # time in the current state
var vel := Vector2.ZERO
var on_ground := true
var air := 0.0  # height above the ground
var flash := 0.0
var _cd := 0.8
var _hop_cd := 0.0
var _struck := false
var _tick := 0.0
var _burn_timer := 0.0
var _hp_shown := 0.0  # HP bar shows for a while after a hit
var _hp_trail := 1.0  # the white "lost HP" part of the bar
var _squash := Vector2.ONE
## Haltung: hidden resistance of armored enemies (brutes, the elite). Only
## Druckbruch (enhanced Schwarzmond Züge) wears it down; when it is empty
## the armor is gone for a moment and the enemy reels.
var haltung := 0.0
var _broken := 0.0
var _t := 0.0
var _anim := ""
var _anim_t := 0.0

var sprite: Sprite2D
var _textures: Dictionary = {}
var _overlay: Node2D  # HP bar and "!" (not lit by the dusk light)


static func frame_data() -> Dictionary:
	if _frames.is_empty():
		var f := FileAccess.open(FRAMES_JSON, FileAccess.READ)
		if f:
			_frames = JSON.parse_string(f.get_as_text())
	return _frames


func _ready() -> void:
	data = TYPES[type_id]
	look = frame_data()[type_id]
	label = data.name
	max_hp = data.hp
	hp = max_hp
	add_to_group("targets")
	add_to_group("enemies")
	for anim in look.anims:
		_textures[anim] = load("res://assets/enemies/%s/%s.png" % [type_id, anim])
	var shadow := Node2D.new()
	shadow.z_index = -1
	shadow.draw.connect(_draw_shadow.bind(shadow))
	add_child(shadow)
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.use_parent_material = true  # the dusk light sets the material on this node
	add_child(sprite)
	_overlay = Node2D.new()
	_overlay.z_index = 5
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_play("idle")
	_squash = Vector2(1.4, 0.2)
	# the dusk light: our PixelLab figures get the lit material like the dummies;
	# the darker Duelyst sprites stay unlit so they keep reading at dusk
	if world != null and world.stage != null and str(look.get("source", "")) == "pixellab":
		var r := get_hurt_rect()
		world.stage.light_figure(self, Rect2(r.position - global_position, r.size))


func is_elite() -> bool:
	return data.get("elite", false)


# --- target interface (same as the dummies) ------------------------------------

func get_hurt_rect() -> Rect2:
	var s: Vector2 = data.hurt
	if state == "dead":
		s = Vector2.ZERO
	return Rect2(global_position + Vector2(-s.x / 2.0, -s.y), s)


func head_position() -> Vector2:
	return global_position + Vector2(0, -data.hurt.y - 8)


func take_hit(knockback: float, from_x: float) -> void:
	if state == "dead":
		return
	flash = 0.09
	_hp_shown = 3.0
	var dir := signf(global_position.x - from_x)
	if dir == 0.0:
		dir = -facing
	# brutes keep swinging through hits; the elite golem barely moves at all
	var armored: bool = data.kind == "brute" and (state == "strike" or (is_elite() and state == "windup")) and _broken <= 0.0
	var k := 0.3 if armored else (0.5 if is_elite() else 1.0)
	vel.x = dir * clampf(knockback, 20.0, 260.0) * 0.9 * k
	if armored:
		return
	_squash = Vector2(0.8, 1.2)
	if is_elite() and knockback < 120.0:
		return  # light hits only flash the golem
	if data.kind != "brute" or knockback >= 100.0 or state != "windup":
		_enter("hurt")


## Perfekt-Block by the player: the attack bounces off, the enemy reels.
func parried(from_x: float) -> void:
	if state == "dead":
		return
	_enter("hurt")
	_st = -0.7  # a long stagger: time for a punish
	flash = 0.15
	vel.x = signf(global_position.x - from_x) * 160.0
	_cd = maxf(_cd, 1.2)
	if world.glut_fx != null:
		world.glut_fx.word(head_position() + Vector2(0, -10), "BENOMMEN", Color("ffd25c"), 14)


func haltung_max() -> float:
	if is_elite():
		return 90.0
	return 50.0 if data.kind == "brute" else 30.0


## Druckbruch: posture damage. Returns true when the Haltung broke.
func posture_hit(amount: float, from_x: float) -> bool:
	if state == "dead" or _broken > 0.0:
		return false
	haltung += amount
	if haltung < haltung_max():
		return false
	haltung = 0.0
	_broken = 1.5
	_enter("hurt")
	_st = -1.0
	flash = 0.2
	vel.x = signf(global_position.x - from_x) * 140.0
	_cd = maxf(_cd, 1.5)
	if world.glut_fx != null:
		world.glut_fx.word(head_position() + Vector2(0, -12), "HALTUNG GEBROCHEN", Color("f4f8ff"), 15)
	return true


## Juggle: thrown up (positive) or slammed down (negative).
func launch(speed: float) -> void:
	if state == "dead":
		return
	var k := 0.35 if is_elite() else (1.0 if data.kind == "slime" else 0.75)
	if speed > 0.0:
		vel.y = -(maxf(-vel.y, 0.0) * 0.3 + speed * k)
		on_ground = false
		_enter("hurt")
	elif not on_ground:
		vel.y = -speed * k


## Called by TrainingRoom.deal_hit / deal_dot with the final damage.
func apply_damage(amount: float) -> void:
	if state == "dead":
		return
	hp = maxf(0.0, hp - amount)
	_hp_shown = 3.0
	if hp <= 0.0:
		_die()


# --- behaviour -------------------------------------------------------------------

func _enter(s: String) -> void:
	state = s
	_st = 0.0
	_struck = false
	_tick = 0.0
	match s:
		"hurt":
			_play("hurt", true)
		"windup":
			_play("attack", true)
		"idle":
			_play("idle")
		"move":
			_play("walk" if _textures.has("walk") else "idle")


func _play(anim: String, restart := false) -> void:
	if not _textures.has(anim):
		anim = {"idle": "walk", "walk": "idle", "death": "hurt"}.get(anim, "")
		if not _textures.has(anim):
			return
	if _anim == anim and not restart:
		return
	_anim = anim
	_anim_t = 0.0
	sprite.texture = _textures[anim]
	sprite.hframes = int(look.anims[anim][0])
	sprite.frame = 0


func _physics_process(delta: float) -> void:
	_t += delta
	_st += delta
	_anim_t += delta
	flash = maxf(0.0, flash - delta)
	_broken = maxf(0.0, _broken - delta)
	if _broken <= 0.0 and haltung > 0.0:
		haltung = maxf(0.0, haltung - delta * 6.0)  # recovers slowly
	_hp_shown = maxf(0.0, _hp_shown - delta)
	_hp_trail = move_toward(_hp_trail, hp / max_hp, delta * (0.0 if flash > 0.0 else 0.8))
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-12.0 * delta))
	if state != "dead":
		Reactions.tick(status, delta)
		_burn(delta)
		_think(delta)
	else:
		_dying()
	_move(delta)
	_animate()
	queue_redraw()
	_overlay.queue_redraw()


func _burn(delta: float) -> void:
	if status.has("brand"):
		# burning enemies visibly lick with small flames
		if world.glut_fx != null and randf() < 0.45:
			var hs: Vector2 = data.hurt
			var p := global_position + Vector2(randf_range(-0.4, 0.4) * hs.x, -randf_range(0.1, 0.9) * hs.y)
			world.glut_fx.flame(p, randf_range(3.0, 6.0), Vector2(randf_range(-10, 10), -50.0), 0.35, 0.7)
		_burn_timer -= delta
		if _burn_timer <= 0.0:
			_burn_timer = TrainingDummy.BURN_TICK
			world.deal_dot(self, TrainingDummy.BURN_DAMAGE, "feuer")
			if world.glut_fx != null and state != "dead":
				world.glut_fx.embers(global_position + Vector2(0, -data.hurt.y * 0.5), 3, 10.0)
	else:
		_burn_timer = 0.0


func _think(delta: float) -> void:
	var p := world.player
	var dx := p.global_position.x - global_position.x
	var dist := absf(dx)
	var near: bool = dist < data.aggro and absf(p.global_position.y - global_position.y) < 120.0
	_cd -= delta
	match state:
		"spawn":
			vel.x = 0.0
			if _st > 0.55:
				_enter("idle")
		"idle", "move":
			if not near:
				if state != "idle":
					_enter("idle")
				return
			facing = 1 if dx > 0.0 else -1
			if dist <= data.range and _cd <= 0.0 and on_ground:
				_enter("windup")
				return
			if data.kind == "slime":
				if state != "move":
					_enter("move")
				_hop(delta, dist)
			elif dist > data.range * (0.85 if data.kind != "brute" else 0.7):
				if state != "move":
					_enter("move")
				vel.x = facing * data.speed
			else:
				if state != "idle":
					_enter("idle")
		"windup":
			vel.x = move_toward(vel.x, 0.0, 600.0 * delta)
			if data.kind == "slime":
				_squash = Vector2(1.25 + sin(_t * 60.0) * 0.04, 0.72)  # flattens and trembles
			elif data.kind == "beast":
				_squash = Vector2(1.12, 0.86)  # crouches
			if _st >= data.windup:
				_enter("strike")
				_strike_start()
		"strike":
			_strike(delta)
		"recover":
			vel.x = move_toward(vel.x, 0.0, 500.0 * delta)
			if _st > 0.5:
				_enter("idle")
		"hurt":
			if _st > 0.28 and on_ground:
				_enter("idle")
				_cd = maxf(_cd, 0.35)


func _hop(delta: float, dist: float) -> void:
	_hop_cd -= delta
	if on_ground:
		vel.x = move_toward(vel.x, 0.0, 700.0 * delta)
		if _hop_cd <= 0.0:
			_hop_cd = randf_range(0.45, 0.7)
			var reach := minf(dist - data.range * 0.6, 70.0)
			vel = Vector2(facing * maxf(reach, 25.0) * 1.9, -210.0)
			on_ground = false
			_squash = Vector2(0.7, 1.35)
			world.dust.puff(global_position, -facing, 2)


func _strike_start() -> void:
	_anim_t = float(data.hit) / float(look.anims.attack[1])  # jump to the blow
	match data.kind:
		"slime":
			vel = Vector2(facing * 330.0, -150.0)
			on_ground = false
			_squash = Vector2(1.35, 0.75)
			Sfx.play("dash", -6.0)
		"beast":
			vel = Vector2(facing * 420.0, -120.0)
			on_ground = false
			_squash = Vector2(1.3, 0.8)
			world.dust.puff(global_position, -facing, 4)
			Sfx.play("dash", -6.0)
		"breather":
			Sfx.play("swing_heavy", -8.0)


func _body_hit(r: Rect2) -> void:
	var p := world.player
	if not _struck and r.intersects(p.get_hurt_rect()):
		_struck = true
		p.receive_hit(data.damage, global_position.x, self)


func _strike(delta: float) -> void:
	var p := world.player
	match data.kind:
		"slime", "beast":
			var s: Vector2 = data.hurt
			_body_hit(Rect2(global_position + Vector2(-s.x * 0.6, -s.y), Vector2(s.x * 1.2, s.y)))
			if _struck and data.kind == "slime" and _st < 0.1:
				vel = Vector2(-facing * 120.0, -160.0)  # bounces off
			if (_st > 0.12 and on_ground) or _st > 0.8:
				_squash = Vector2(1.3, 0.75)
				_enter("recover")
		"brute":
			if not _struck and _st >= 0.06:
				var reach: float = data.range + 8.0
				var r := Rect2(global_position.x + (0.0 if facing > 0 else -reach), global_position.y - data.hurt.y, reach, data.hurt.y)
				_body_hit(r)
				_struck = true
				var impact := global_position + Vector2(facing * data.range * 0.7, 0)
				var heavy := is_elite()
				world.dust.land(impact, 2.0 if heavy else 1.4)
				world.effects.burst(impact + Vector2(0, -2), Color("b08850"), 16 if heavy else 10, 140.0, 400.0)
				world.fx.shake(5.0 if heavy else 2.5, facing)
				Sfx.play("hit_heavy", -4.0 if heavy else -8.0)
				if world.glut_fx != null:
					world.glut_fx.word(impact + Vector2(0, -44), "KRACH!" if heavy else "BUMM!", Color("e8c890"), 20 if heavy else 16)
			if _st > 0.45:
				_enter("recover")
		"breather":
			# short fire cone in front, ticks while the breath lasts
			var mouth := global_position + Vector2(facing * 22.0, -18.0)
			if world.glut_fx != null and randf() < 0.9:
				world.glut_fx.flame(mouth + Vector2(facing * randf_range(4, 40), randf_range(-6, 6)), randf_range(6.0, 11.0), Vector2(facing * 160.0, -20.0), 0.35)
			_tick -= delta
			if _tick <= 0.0:
				_tick = 0.2
				var r := Rect2(mouth.x + (0.0 if facing > 0 else -data.range), mouth.y - 16.0, data.range, 32.0)
				if r.intersects(p.get_hurt_rect()):
					p.receive_hit(data.damage, global_position.x, self)
			if _st > 0.7:
				_enter("recover")
	if state == "recover":
		_cd = data.cooldown * randf_range(0.85, 1.2)


func _move(delta: float) -> void:
	if not on_ground or vel.y < 0.0:
		vel.y += GRAVITY * delta
	var nx := clampf(global_position.x + vel.x * delta, 20.0, TrainingRoom.WIDTH - 20.0)
	var ny := global_position.y + vel.y * delta
	var gy := GlutHazard.ground_y(nx, global_position.y)
	# a high ledge stops walkers (they do not climb)
	if gy < global_position.y - 8.0 and air < 8.0:
		nx = global_position.x
		gy = GlutHazard.ground_y(nx, global_position.y)
		vel.x = 0.0
	if ny >= gy and vel.y >= 0.0:
		if not on_ground:
			_land(vel.y)
		ny = gy
		vel.y = 0.0
		on_ground = true
	elif ny < gy - 1.0:
		on_ground = false
	if on_ground and state != "move":
		vel.x = move_toward(vel.x, 0.0, 420.0 * delta)
	global_position = Vector2(nx, ny)
	air = maxf(0.0, gy - ny)


func _land(speed: float) -> void:
	if speed > 120.0:
		_squash = Vector2(1.0 + minf(speed, 500.0) / 900.0, 1.0 - minf(speed, 500.0) / 1300.0)
		world.dust.land(global_position, minf(speed / 300.0, 1.5))


func _animate() -> void:
	var a: Array = look.anims[_anim]
	var n := int(a[0])
	var f := int(_anim_t * float(a[1]))
	match _anim:
		"hurt", "death":
			f = mini(f, n - 1)
		"attack":
			var hit: int = mini(data.hit, n - 1)
			if state == "windup":
				f = mini(int(_st / data.windup * hit), hit - 1)  # stretched over the wind-up
			elif state == "strike" or state == "recover":
				f = mini(f, n - 1)
			else:
				f = f % n
		_:
			f = f % n
	sprite.frame = f
	sprite.flip_h = facing < 0
	# squash and stretch around the feet
	var cell: Array = look.cell
	var foot: float = look.foot
	var sc: Vector2 = _squash * float(data.get("scale", 1.0))
	sprite.scale = sc
	sprite.position = Vector2(-float(cell[0]) * 0.5 * sc.x, -foot * sc.y)
	var tint := Color.WHITE
	if state == "windup":
		var pulse := 0.5 + 0.5 * sin(_st * 30.0)
		tint = Color(1.0 + pulse * 0.9, 1.0 - pulse * 0.25, 1.0 - pulse * 0.35)
	if status.has("brand"):
		tint = tint * Color(1.15, 0.92, 0.85)
	if flash > 0.0:
		tint = Color(3.0, 3.0, 3.0)
	sprite.modulate = tint


# --- death ------------------------------------------------------------------------

func _die() -> void:
	state = "dead"
	_st = 0.0
	_struck = false
	remove_from_group("targets")
	status.clear()
	vel.x = -facing * 60.0
	_play("death" if _textures.has("death") else "hurt", true)
	var c := global_position + Vector2(0, -data.hurt.y * 0.5)
	world.fx.hit(c, "", "heavy", -facing)
	world.numbers.spawn_text(head_position() + Vector2(0, -12), "+%d EXP" % data.exp, Color("9ef0ff"))
	world.on_enemy_died(self)
	died.emit(self)


func _dying() -> void:
	var c := global_position + Vector2(0, -data.hurt.y * 0.4)
	if data.kind == "slime":
		# melts flat, then pops into moss and leaves
		_squash = Vector2(1.0 + _st * 1.4, maxf(0.15, 1.0 - _st * 2.2))
		if _st > 0.38 and not _struck:
			_struck = true
			world.effects.burst(c, data.color, 26, 150.0, 260.0)
			world.effects.burst(c, Color("e8597a"), 6, 110.0, 260.0)  # the mushroom cap
			world.dust.land(global_position, 1.2)
			_spawn_orbs()
	else:
		var n := float(look.anims.death[0]) / float(look.anims.death[1])
		if _st > n and not _struck:
			_struck = true
			world.effects.burst(c, data.color, 18, 100.0, 140.0)
			world.effects.burst(c, Color("2a1a1a"), 10, 60.0, -40.0)  # dark wisps rise
			_spawn_orbs()
	var gone := 0.5 if data.kind == "slime" else float(look.anims.death[0]) / float(look.anims.death[1]) + 0.5
	if _st > gone - 0.4:
		sprite.visible = fmod(_st, 0.08) < 0.05
	if _st > gone:
		queue_free()


## Little glowing orbs that fly up to the player (EXP).
func _spawn_orbs() -> void:
	if world.glut_fx == null:
		return
	var c := global_position + Vector2(0, -16)
	for i in (12 if is_elite() else 6):
		var to := world.player.global_position + Vector2(0, -26) - c
		var v := Vector2(randf_range(-80, 80), randf_range(-160, -60)) + to * 0.9
		world.glut_fx.glow(c, Color(0.55, 1.6, 2.0), 5.0, 0.7, v, 0.0)


# --- drawing -----------------------------------------------------------------------

func _draw_shadow(n: Node2D) -> void:
	if state == "dead" and _st > 0.6:
		return
	var w: float = data.hurt.x * 0.65 * (1.0 - clampf(air / 160.0, 0.0, 0.6))
	n.draw_set_transform(Vector2(0, air), 0.0, Vector2(1.0, 0.28))
	n.draw_circle(Vector2.ZERO, w, Color(0.05, 0.02, 0.08, 0.35))
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_overlay() -> void:
	var top: float = -data.hurt.y - 14.0
	if state == "windup":
		var a := 0.65 + 0.35 * sin(_st * 40.0)
		var p := Vector2(0, top - 10)
		var o := Color("1a1020")
		var y := Color(1.0, 0.35, 0.2, a)
		_overlay.draw_rect(Rect2(p + Vector2(-3, -12), Vector2(6, 12)), Color(o, a))
		_overlay.draw_rect(Rect2(p + Vector2(-2, -11), Vector2(4, 10)), y)
		_overlay.draw_rect(Rect2(p + Vector2(-3, 2), Vector2(6, 5)), Color(o, a))
		_overlay.draw_rect(Rect2(p + Vector2(-2, 3), Vector2(4, 3)), y)
	var show := clampf(_hp_shown, 0.0, 1.0)
	if is_elite():
		show = 1.0  # the elite always shows its bar
	if state == "dead":
		show = maxf(0.0, 1.0 - _st * 3.0)
	if show <= 0.0:
		return
	var w := 48.0 if is_elite() else 34.0
	var r := Rect2(-w / 2.0, top, w, 4)
	_overlay.draw_rect(r.grow(1), Color(0.07, 0.04, 0.1, show))
	_overlay.draw_rect(r, Color(0.25, 0.1, 0.12, show))
	_overlay.draw_rect(Rect2(r.position, Vector2(w * _hp_trail, 4)), Color(1, 0.95, 0.85, show))
	var frac := hp / max_hp
	var col := Color("e8433a") if frac < 0.35 else Color("f2a23a") if frac < 0.65 else Color("8fd94a")
	_overlay.draw_rect(Rect2(r.position, Vector2(w * frac, 4)), Color(col, show))
	_overlay.draw_rect(Rect2(r.position, Vector2(w * frac, 1)), Color(col.lightened(0.4), show))
	if is_elite():
		# a small golden crown marks the elite
		var cp := Vector2(-w / 2.0 - 8.0, top - 2.0)
		_overlay.draw_rect(Rect2(cp, Vector2(6, 5)), Color("1a1020"))
		_overlay.draw_rect(Rect2(cp + Vector2(1, 1), Vector2(4, 3)), Color("ffd25c"))
	var x := w / 2.0 + 4.0
	for key in status.keys():
		var c: Color = GameData.STATUS[key].color
		_overlay.draw_rect(Rect2(Vector2(x, top - 2), Vector2(7, 7)), Color("1a1020"))
		_overlay.draw_rect(Rect2(Vector2(x + 1, top - 1), Vector2(5, 5)), c)
		x += 9.0
