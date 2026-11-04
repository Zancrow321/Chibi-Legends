class_name TrainingRoom
extends Node2D
## The academy's training forest: terrain, dummies, the player, the camera,
## and the combat hub (hits, reactions, damage-over-time, stats for the HUD).

const WIDTH := 1400.0
const GROUND_Y := 300.0
const DPS_WINDOW := 4.0

## Emitted on every hit (for lights, sounds, ...): world position and element color.
signal hit_landed(pos: Vector2, color: Color, strong: bool)

## Solid ground pieces [x, y, w] (extend down past the screen) and
## one-way floating platforms [x, y, w].
const GROUND := [[0.0, 300.0, 1000.0], [1000.0, 262.0, 400.0]]
const PLATFORMS := [[170.0, 236.0, 110.0], [360.0, 196.0, 90.0], [800.0, 214.0, 110.0], [1120.0, 196.0, 120.0]]
const DUMMIES := [[470.0, 300.0, false], [540.0, 300.0, false], [610.0, 300.0, false], [720.0, 300.0, true]]
## Sparring post that fights back (tests counter, reflect and shield).
const POST_POS := Vector2(1300.0, 262.0)

var player: Player
var camera: Camera2D
var effects: Effects
var fx: CombatFx  # hit-stop, shake, glowing sparks, super flash
var hud: Node  # set by Main (cut-in banner for supers)
var numbers: DamageNumbers  # set by Main (lives on the HUD layer)
var attacks: Node2D
var afterimages: Afterimages  # glowing sprite copies behind the player
## Off when another view draws the ground (HD-2D variant B builds it in 3D).
var draw_terrain := true
var glut_fx: GlutFx  # fire effects of the fighting style
var stage: DuskStage  # dusk light look (only in the "Licht" view, see Main)
var post: SparringPost

# stats for the HUD
var total_damage := 0.0
var last_reaction := ""
var reactions_found: Dictionary = {}
var toast_text := ""
var toast_time := 0.0
var _hits: Array = []  # [time, damage]
var _clock := 0.0


func _ready() -> void:
	_build_terrain()
	attacks = Node2D.new()
	effects = Effects.new()
	effects.z_index = 50
	for d in DUMMIES:
		var dummy := TrainingDummy.new()
		dummy.world = self
		dummy.big = d[2]
		dummy.position = Vector2(d[0], d[1])
		add_child(dummy)
	post = SparringPost.new()
	post.world = self
	post.position = POST_POS
	add_child(post)
	player = Player.new()
	player.world = self
	player.position = Vector2(110, GROUND_Y - 1)
	afterimages = Afterimages.new()
	add_child(afterimages)
	add_child(player)
	add_child(attacks)
	add_child(effects)

	camera = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.limit_left = 0
	camera.limit_right = int(WIDTH)
	camera.limit_top = -200
	camera.limit_bottom = 360
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.process_mode = Node.PROCESS_MODE_ALWAYS  # shake also plays during hit-stop
	add_child(camera)

	fx = CombatFx.new()
	fx.room = self
	fx.camera = camera
	fx.base_zoom = camera.zoom
	add_child(fx)

	glut_fx = GlutFx.new()
	glut_fx.room = self
	add_child(glut_fx)
	player.init_style()
	if DuskStage.enabled:
		stage = DuskStage.new()
		stage.room = self
		add_child(stage)
		glut_fx.stage = stage


func _process(delta: float) -> void:
	_clock += delta
	toast_time = maxf(0.0, toast_time - delta)
	camera.global_position = player.global_position + Vector2(player.facing * 30.0, -40.0)
	if Input.is_action_just_pressed("cycle_fx"):
		FxSettings.cycle()
		get_tree().call_group("bloom", "apply_level")
		toast("Effekte: " + FxSettings.level_name())
	if Input.is_action_just_pressed("toggle_infinite_aura"):
		player.infinite_aura = not player.infinite_aura
		toast("Unendlich Legendenleiste: " + ("an" if player.infinite_aura else "aus"))
	if Input.is_action_just_pressed("reset_cooldowns"):
		player.reset_cooldowns()
		toast("Abklingzeiten zurückgesetzt")
	if player.global_position.y > 420.0:  # fell off the world
		player.global_position = Vector2(110, GROUND_Y - 1)
		player.velocity = Vector2.ZERO


# --- terrain -------------------------------------------------------------

func _build_terrain() -> void:
	for g in GROUND:
		_add_block(Rect2(g[0], g[1], g[2], 200.0), Player.LAYER_GROUND, false)
	for p in PLATFORMS:
		_add_block(Rect2(p[0], p[1], p[2], 8.0), Player.LAYER_PLATFORM, true)


func _add_block(r: Rect2, layer: int, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	shape.one_way_collision = one_way
	body.add_child(shape)
	add_child(body)


static func _h(i: int, salt: float) -> float:
	return fposmod(sin(float(i) * 12.9898 + salt * 78.233) * 43758.5453, 1.0)


func _draw() -> void:
	if not draw_terrain:
		return
	var outline := Color("2a1c14")
	for g in GROUND:
		_draw_cliff(Rect2(g[0], g[1], g[2], 200.0), outline)
	for p in PLATFORMS:
		_draw_ledge(Rect2(p[0], p[1], p[2], 8.0), outline)


func _draw_cliff(r: Rect2, outline: Color) -> void:
	var dirt := Color("7a5636")
	draw_rect(r, outline)
	draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 0)), dirt)
	# stone blocks texture
	var row := 0
	var y := r.position.y + 10.0
	while y < r.end.y:
		var x := r.position.x + 2.0 + (8.0 if row % 2 else 0.0)
		var i := 0
		while x < r.end.x - 4:
			var bw := 14.0 + _h(row * 31 + i, 3) * 12.0
			bw = minf(bw, r.end.x - 3 - x)
			var c := dirt.lightened(0.08 + _h(row * 17 + i, 5) * 0.1)
			draw_rect(Rect2(x, y, bw - 2, 8), c)
			draw_rect(Rect2(x, y + 7, bw - 2, 1), dirt.darkened(0.25))
			x += bw
			i += 1
		y += 10.0
		row += 1
	# grass top with tufts
	draw_rect(Rect2(r.position.x, r.position.y - 1, r.size.x, 7), outline)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 5), Color("5cae48"))
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2), Color("8fd968"))
	var k := 0
	var tx := r.position.x + 3.0
	while tx < r.end.x - 3:
		var th := 2.0 + _h(k, 1) * 4.0
		draw_rect(Rect2(tx, r.position.y + 5, 3, th), Color("4a9a3c"))
		if _h(k, 2) > 0.8:
			draw_rect(Rect2(tx, r.position.y - 3, 2, 3), Color("8fd968"))
		tx += 5.0 + _h(k, 4) * 6.0
		k += 1


func _draw_ledge(r: Rect2, outline: Color) -> void:
	var under := Rect2(r.position.x + 6, r.position.y + 4, r.size.x - 12, 12)
	draw_rect(under.grow(1), outline)
	draw_rect(under, Color("7a5636"))
	draw_rect(Rect2(under.position.x + 10, under.end.y, under.size.x - 20, 5).grow(1), outline)
	draw_rect(Rect2(under.position.x + 10, under.end.y, under.size.x - 20, 5), Color("6a4a2e"))
	draw_rect(r.grow(1), outline)
	draw_rect(r, Color("5cae48"))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color("8fd968"))
	var i := 0
	var x := r.position.x + 4
	while x < r.end.x - 4:
		draw_rect(Rect2(x, r.end.y, 3, 2.0 + _h(i, 6) * 5.0), Color("4a9a3c"))
		x += 7.0
		i += 1


# --- combat hub ----------------------------------------------------------

func spawn_attack(d: Dictionary) -> void:
	var a := Attack.new()
	a.world = self
	attacks.add_child(a)
	a.setup(d)


## Afterimage of the player: a glowing copy of the shown drawing (dash,
## heavy strikes); the roster look still uses the simple block ghost.
func spawn_ghost(p: Player) -> void:
	if p.sprite.visible:
		var col := Color(0.45, 0.85, 1.6, 0.5)
		if p.glut != null:
			col = Color(p.glut.trail_color(), 0.5) * Color(1.5, 1.5, 1.5, 1.0)
		var b := FxSettings.boost()
		afterimages.add(p.sprite.snapshot(), col * Color(b, b, b, 1.0))
	else:
		effects.ghost(p)


func spawn_burst(pos: Vector2, color: Color, count: int) -> void:
	effects.burst(pos, color, count)


func spawn_spark(pos: Vector2, color: Color) -> void:
	effects.spark(pos, color)


func cast_chain(p: Player, s: Dictionary) -> void:
	var origin := p.global_position + Vector2(p.facing * 14.0, -26.0)
	var visited: Array = []
	var current_pos := origin
	var points := PackedVector2Array([origin])
	var reach: float = s.range
	for i in s.jumps + 1:
		var best: Node2D = null
		var best_d := INF
		for t in get_tree().get_nodes_in_group("targets"):
			if t in visited:
				continue
			var c: Vector2 = t.get_hurt_rect().get_center()
			if i == 0 and signf(c.x - p.global_position.x) != p.facing and absf(c.x - p.global_position.x) > 10.0:
				continue  # first target must be in front
			var d := current_pos.distance_to(c)
			if d < reach and d < best_d:
				best = t
				best_d = d
		if best == null:
			break
		visited.append(best)
		current_pos = best.get_hurt_rect().get_center()
		points.append(current_pos)
		deal_hit(best, s.damage, s.element, p.global_position.x, 30.0)
		reach = s.jump_range
	if points.size() == 1:
		points.append(origin + Vector2(p.facing * 60.0, randf_range(-10, 10)))
	effects.bolt(points)


func cast_super(p: Player, s: Dictionary) -> void:
	var beam := SuperBeam.new()
	beam.room = self
	beam.player = p
	beam.skill = s
	var b := FxSettings.boost()
	beam.modulate = Color(b, b, b, 1.0)  # glows with the bloom
	add_child(beam)


## `profile` picks the hit feel from FxSettings.HIT; empty = light or heavy
## depending on knockback.
## Returns the damage dealt. Super hits ("super", "super_final") show no
## number of their own; the beam adds them up and shows one big total.
func deal_hit(target: Node2D, base: float, element: String, from_x: float, knockback: float, profile := "", launch := 0.0) -> int:
	var res := Reactions.resolve(target.status, element, base)
	var dmg := int(round(res.damage * randf_range(0.92, 1.08)))
	var col: Color = GameData.ELEMENTS[element].color if element != "" else Color("ff4b3e")
	hit_landed.emit(target.get_hurt_rect().get_center(), col, res.reaction != "")
	target.take_hit(knockback, from_x)
	if launch != 0.0 and target.has_method("launch"):
		target.launch(launch)
	_record(dmg)
	if not profile.begins_with("super"):
		numbers.spawn_number(target.head_position(), dmg, col, target.get_instance_id(), res.reaction != "")
	var center: Vector2 = target.get_hurt_rect().get_center()
	effects.burst(center, col, 6)
	if profile == "":
		profile = "heavy" if knockback >= 120.0 else "light"
	var dir := signf(center.x - from_x)
	if res.reaction == "":
		fx.hit(center, element, profile, dir)
	else:
		fx.hit(center, element, "super_final" if profile == "super_final" else "heavy", dir)
		_trigger_reaction(target, res)
	return dmg


func _trigger_reaction(target: Node2D, res: Dictionary) -> void:
	var info: Dictionary = GameData.REACTIONS[res.reaction]
	last_reaction = res.reaction
	reactions_found[res.reaction] = true
	var center: Vector2 = target.get_hurt_rect().get_center()
	hit_landed.emit(center, info.color, true)
	numbers.spawn_text(target.head_position() + Vector2(0, -10), info.name + "!", info.color)
	effects.burst(center, info.color, 22, 160.0, 60.0)
	fx.blast(center, info.color, res.aoe_radius, "reaction")
	if res.aoe_radius > 0.0:
		for t in get_tree().get_nodes_in_group("targets"):
			if t.get_hurt_rect().get_center().distance_to(center) <= res.aoe_radius:
				var aoe := int(round(res.aoe_damage * randf_range(0.92, 1.08)))
				_record(aoe)
				numbers.spawn_number(t.head_position(), aoe, info.color, t.get_instance_id(), true)
				t.take_hit(80.0, center.x)
				if res.spread_status != "":
					t.status[res.spread_status] = Reactions.STATUS_DURATION


func deal_dot(target: Node2D, amount: float, element: String) -> void:
	var dmg := int(round(amount))
	_record(dmg)
	numbers.spawn_number(target.head_position(), dmg, GameData.ELEMENTS[element].color.darkened(0.1), target.get_instance_id())


func _record(dmg: float) -> void:
	total_damage += dmg
	_hits.append([_clock, dmg])


func dps() -> float:
	_hits = _hits.filter(func(h): return _clock - h[0] <= DPS_WINDOW)
	var sum := 0.0
	for h in _hits:
		sum += h[1]
	return sum / DPS_WINDOW


func toast(text: String) -> void:
	toast_text = text
	toast_time = 2.2
