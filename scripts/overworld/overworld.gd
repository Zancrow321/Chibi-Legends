class_name Overworld
extends Node2D
## The academy courtyard (Akademie-Hof): the calm overworld between the
## combat areas. Walk, jump onto the terrace, talk to NPCs, read the quest
## board and enter the gates. No combat, no HP, its own quiet HUD
## (OverworldHud). The gates lead into the combat areas (GameFlow,
## AreaTransition).
##
## Look: clear late morning. A light day tint, a warm sun from the right,
## posterised 2D light (pixel_lit) with rounded normals on the figures,
## glowing portals, lanterns and the forge, sun shafts, falling blossoms,
## a five-layer parallax backdrop and bloom on everything that glows.
## Props and NPCs are PixelLab drawings (assets/overworld, see
## tools/overworld/), backdrop and ground are drawn in code.

const WIDTH := 2400.0
const GROUND_Y := 300.0
const TERRACE_Y := 272.0
## Solid ground [x, y, w]; the terrace has ramps (drawn as stairs) on both sides.
const GROUND := [[0.0, 300.0, 1060.0], [1060.0, 272.0, 420.0], [1480.0, 300.0, 920.0]]
const RAMPS := [[1024.0, 1060.0, 300.0, 272.0], [1480.0, 1516.0, 272.0, 300.0]]
## One-way platforms [x, y, w]: dorm balcony and two floating rune stones.
const PLATFORMS := [[24.0, 214.0, 84.0], [1790.0, 238.0, 56.0], [1900.0, 206.0, 56.0]]

const DAY := Color(0.86, 0.86, 0.93)
const DIR := "res://assets/overworld/"
## [texture, scroll factor, canvas layer]
const LAYERS := [["sky", 0.0, -6], ["far", 0.05, -5], ["mid", 0.22, -4], ["near", 0.5, -3], ["foreground", 1.35, 3]]

## Props: [name, foot x, z, lit by the scene light]
const PROPS := [
	["dorm", 70.0, -3, true], ["board", 250.0, -1, true], ["fountain", 520.0, -2, true],
	["sakura", 770.0, -4, true], ["forge_stall", 930.0, -2, true], ["shrine", 1270.0, -2, true],
	["gate_wald", 1730.0, -2, true], ["gate_glut", 2060.0, -2, true],
]
const LANTERNS := [180.0, 640.0, 1090.0, 1450.0, 1880.0, 2230.0]

var walker: OverworldWalker
var camera: Camera2D
var hud: OverworldHud  # set by Main
var spots: Array[OverworldSpot] = []
var focus: OverworldSpot  # nearest usable spot, null = none

var _lit_shader: Shader
var _light_tex: GradientTexture2D
var _halo: Texture2D
var _layers: Array = []
var _lanterns: Array[PointLight2D] = []
var _forge_light: PointLight2D
var _portal_light: PointLight2D
var _seal_light: PointLight2D
var _star_light: PointLight2D
var _walker_mat: ShaderMaterial
var _shafts: Sprite2D
var _petals: CPUParticles2D
var _t := 0.0


func _ready() -> void:
	_lit_shader = load("res://shaders/lightlook/pixel_lit.gdshader")
	_halo = load("res://assets/lightlook/halo.png")
	_light_tex = GradientTexture2D.new()
	_light_tex.width = 256
	_light_tex.height = 256
	_light_tex.fill = GradientTexture2D.FILL_RADIAL
	_light_tex.fill_from = Vector2(0.5, 0.5)
	_light_tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	_light_tex.gradient = g

	var tm := ShaderMaterial.new()
	tm.shader = _lit_shader
	material = tm  # ground: posterised light
	_build_terrain()
	_build_props()
	_build_spots()

	walker = OverworldWalker.new()
	walker.position = _entry_position()
	walker.z_index = 2
	add_child(walker)
	_walker_mat = ShaderMaterial.new()
	_walker_mat.shader = _lit_shader
	_walker_mat.set_shader_parameter("auto_normal", true)
	_walker_mat.set_shader_parameter("half_w", 12.0)
	_walker_mat.set_shader_parameter("half_h", 26.0)
	_walker_mat.set_shader_parameter("center_y", -26.0)
	walker.sprite.set_body_material(_walker_mat)

	camera = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.limit_left = 0
	camera.limit_right = int(WIDTH)
	camera.limit_top = -200
	camera.limit_bottom = 360
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	add_child(camera)
	camera.global_position = walker.global_position + Vector2(0, -40)
	camera.reset_smoothing.call_deferred()

	_build_light()
	_build_parallax()
	_build_atmosphere()


func _entry_position() -> Vector2:
	for s in spots:
		if s.id == GameFlow.entry_door and s.id != "":
			return Vector2(s.position.x - 34.0, ground_y(s.position.x - 34.0) - 1.0)
	return Vector2(118.0, GROUND_Y - 1.0)


func ground_y(x: float) -> float:
	for r in RAMPS:
		if x >= r[0] and x <= r[1]:
			return lerpf(r[2], r[3], (x - r[0]) / (r[1] - r[0]))
	for gr in GROUND:
		if x >= gr[0] and x <= gr[0] + gr[2]:
			return gr[1]
	return GROUND_Y


# --- interaction ----------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	camera.global_position = walker.global_position + Vector2(walker.facing * 24.0, -40.0)
	_update_focus()
	if hud != null and hud.can_interact() and not AreaTransition.busy():
		var pressed := Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("light") \
			or (Input.is_action_just_pressed("move_up") and walker.is_on_floor())
		if pressed and focus != null:
			_use(focus)
	walker.frozen = hud != null and hud.dialog_open()
	if walker.global_position.y > 420.0:
		walker.global_position = _entry_position()
		walker.velocity = Vector2.ZERO
	_animate(delta)


func _update_focus() -> void:
	var best: OverworldSpot = null
	var best_d := INF
	for s in spots:
		var d := absf(s.global_position.x - walker.global_position.x)
		if d < s.reach and absf(s.global_position.y - walker.global_position.y) < 40.0 and d < best_d:
			best = s
			best_d = d
	focus = best
	for s in spots:
		if absf(s.global_position.x - walker.global_position.x) < 90.0:
			s.face(walker.global_position.x)


func _use(s: OverworldSpot) -> void:
	if s.id == "questbrett":
		Sfx.play("ui_confirm")
		get_tree().call_group("season_pass", "open", 0)
		return
	if s.id == "sternschrein":
		Sfx.play("ui_confirm")
		get_tree().call_group("gacha", "open")
		return
	match s.kind:
		OverworldSpot.Kind.DOOR:
			var info := GameFlow.area_info(s.target_area)
			if info.get("locked", false):
				Sfx.play("ui_error")
				hud.open_dialog(s.display_name, s.lines, s.accent, null)
			else:
				AreaTransition.go(s.target_area)
		_:
			Sfx.play("ui_click")
			hud.open_dialog(s.display_name, s.lines, s.accent, s.sprite.texture if s.sprite != null and s.kind == OverworldSpot.Kind.NPC else null)
			_gift(s.id)


## First talk with Kiyo / Hino: their outfit ("Bei ... (Akademie-Hof)" in the catalog).
func _gift(npc: String) -> void:
	var gifts := {"hueterin": ["ronin", "Ronin-Kleidung"], "schmiedin": ["schmied", "Schmiede-Kleidung"]}
	if not gifts.has(npc) or CreatorUnlocks.is_unlocked("top", gifts[npc][0]):
		return
	for slot in ["top", "pants", "shoes"]:
		CreatorUnlocks.unlock(slot, gifts[npc][0])
	hud.toast("Geschenk: %s, im Creator (O) wählbar" % gifts[npc][1])
	Sfx.play("rare_drop", -4.0)


# --- building ---------------------------------------------------------------------

func _build_terrain() -> void:
	for gr in GROUND:
		_solid(PackedVector2Array([Vector2(gr[0], gr[1]), Vector2(gr[0] + gr[2], gr[1]), Vector2(gr[0] + gr[2], 520), Vector2(gr[0], 520)]), false)
	for r in RAMPS:
		_solid(PackedVector2Array([Vector2(r[0], r[2]), Vector2(r[1], r[3]), Vector2(r[1], 520), Vector2(r[0], 520)]), false)
	for p in PLATFORMS:
		_solid(PackedVector2Array([Vector2(p[0], p[1]), Vector2(p[0] + p[2], p[1]), Vector2(p[0] + p[2], p[1] + 6), Vector2(p[0], p[1] + 6)]), true)
	# side walls
	_solid(PackedVector2Array([Vector2(-20, -400), Vector2(0, -400), Vector2(0, 520), Vector2(-20, 520)]), false)
	_solid(PackedVector2Array([Vector2(WIDTH, -400), Vector2(WIDTH + 20, -400), Vector2(WIDTH + 20, 520), Vector2(WIDTH, 520)]), false)
	var ground := OverworldGround.new()
	ground.world = self
	ground.use_parent_material = true
	add_child(ground)


func _solid(poly: PackedVector2Array, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Player.LAYER_PLATFORM if one_way else Player.LAYER_GROUND
	body.collision_mask = 0
	var shape := CollisionPolygon2D.new()
	shape.polygon = poly
	shape.one_way_collision = one_way
	body.add_child(shape)
	add_child(body)


func _prop(name: String, x: float, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(DIR + name + ".png")
	s.centered = false
	s.offset = Vector2(-s.texture.get_width() * 0.5, -s.texture.get_height())
	s.position = Vector2(x, ground_y(x) + 1.0)
	s.z_index = z
	s.use_parent_material = true
	add_child(s)
	return s


func _build_props() -> void:
	for p in PROPS:
		_prop(p[0], p[1], p[2])
	var portal := PortalFx.new()
	portal.position = Vector2(1730.0 - 1.0, GROUND_Y - 56.0)
	portal.z_index = -1
	add_child(portal)
	var seal := PortalFx.new()
	seal.sealed = true
	seal.position = Vector2(2060.0 + 4.0, GROUND_Y - 44.0)
	seal.z_index = -1
	add_child(seal)
	var water := FountainFx.new()
	water.position = Vector2(520.0, GROUND_Y)
	water.z_index = -1
	add_child(water)


func _npc(id: String, name: String, x: float, tex: String, accent: Color, lines: Array) -> OverworldSpot:
	var s := OverworldSpot.new()
	s.kind = OverworldSpot.Kind.NPC
	s.id = id
	s.display_name = name
	s.accent = accent
	s.lines = lines
	s.position = Vector2(x, ground_y(x) + 1.0)
	s.set_sprite(load(DIR + tex + ".png"))
	s.sprite.flip_h = true
	s.z_index = 1
	var m := ShaderMaterial.new()
	m.shader = _lit_shader
	m.set_shader_parameter("auto_normal", true)
	m.set_shader_parameter("half_w", 14.0)
	m.set_shader_parameter("half_h", 30.0)
	m.set_shader_parameter("center_y", -30.0)
	s.sprite.material = m
	add_child(s)
	spots.append(s)
	return s


func _spot(kind: int, id: String, name: String, x: float, lines: Array, target := "", reach := 30.0, prompt_y := -70.0) -> OverworldSpot:
	var s := OverworldSpot.new()
	s.kind = kind
	s.id = id
	s.display_name = name
	s.lines = lines
	s.target_area = target
	s.reach = reach
	s.prompt_offset = Vector2(0, prompt_y)
	s.position = Vector2(x, ground_y(x))
	add_child(s)
	spots.append(s)
	return s


func _build_spots() -> void:
	_spot(OverworldSpot.Kind.SIGN, "wohnheim", "Wohnheim", 76.0, [
		"Dein Zimmer im Wohnheim. Hier ziehst du dich um: Taste O öffnet den Character Creator für Frisur, Kleidung und Waffe.",
	], "", 24.0, -100.0)
	var board := _spot(OverworldSpot.Kind.SIGN, "questbrett", "Questbrett", 250.0, [
		"AUSHANG: Erste Lektion. Löse im Trainingswald alle vier Element-Reaktionen aus.",
		"AUSHANG: Freiwillige für den Sparringspfahl gesucht. Achtung, er schlägt zurück und wirft mit Holzscheiten.",
		"AUSHANG: Die Glutschmiede bleibt versiegelt, bis ein Schüler Glutatem beherrscht.",
	], "", 26.0, -76.0)
	board.verb = "Herausforderungen"
	_npc("rektorin", "Rektorin Yuzuki", 590.0, "npc_rektorin", Color("4d65b4"), [
		"Willkommen im Akademie-Hof. Hier ist es ruhig: kein Kampf, nur Wege, Freunde und Tore.",
		"Hinter den Toren auf der rechten Seite liegen die Kampfareale. Das Waldtor führt in den Trainingswald.",
		"In jedem Areal bringt dich das Portal am Eingang wieder hierher zurück. Geh mit Bedacht, aber geh.",
	])
	_npc("schmiedin", "Schmiedin Hino", 985.0, "npc_schmiedin", Color("fb6b1d"), [
		"Na? Schon Glutatem geübt? Je öfter du die Züge wechselst, desto heißer wird deine Klinge. Bis sie weiß glüht!",
		"Sobald das Inventar steht, schmiede ich dir Waffen. Bis dahin: Trainingswald, Puppen, üben.",
	])
	_npc("hueterin", "Schreinhüterin Kiyo", 1190.0, "npc_hueter", Color("4d9be6"), [
		"Das ist der Sternschrein. Der Stern in seiner Mitte ist erwacht!",
		"Mit Sternkristallen rufst du hier Kampfstile, Outfits und Farbstoffe. Die Chancen hängen offen aus, versprochen.",
		"Jeden Tag lege ich dir ein Geschenk an den Schrein. Und spätestens beim 60. Ruf antwortet ein legendärer Stil.",
	])
	var shrine := _spot(OverworldSpot.Kind.SIGN, "sternschrein", "Sternschrein", 1270.0, [], "", 30.0, -112.0)
	shrine.verb = "Beschwören"
	shrine.accent = Color("f9c22b")
	_npc("waechter", "Torwächter Gonta", 1620.0, "npc_waechter", Color("1ebc73"), [
		"Halt! ... Ach, ein Schüler. Das Waldtor ist offen. Drinnen warten Trainingspuppen und der Sparringspfahl.",
		"Das Tor zur Glutschmiede ist versiegelt. Erst wenn du Glutatem meisterst, brennt das Siegel durch.",
	])
	var wald := _spot(OverworldSpot.Kind.DOOR, "tor_wald", "Waldtor", 1730.0, [], "trainingswald", 28.0, -128.0)
	wald.accent = Color("0eaf9b")
	var glut := _spot(OverworldSpot.Kind.DOOR, "tor_glut", "Tor der Glutschmiede", 2060.0, [
		"Ein schweres Siegel glüht auf dem Tor. Dahinter hört man Hämmer und das Fauchen einer Esse.",
		"Das Tor ist noch verschlossen.",
	], "glutschmiede", 30.0, -134.0)
	glut.accent = Color("fb6b1d")


# --- light ------------------------------------------------------------------------------

func _light(color: Color, energy: float, scale: float, parent: Node = null) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.color = color
	l.energy = energy
	l.texture_scale = scale
	l.height = 30.0
	(parent if parent != null else self).add_child(l)
	return l


func _halo_sprite(color: Color, scale: float, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _halo
	s.modulate = color
	s.scale = Vector2(scale, scale)
	s.position = pos
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	s.material = m
	add_child(s)
	return s


func _build_light() -> void:
	var cm := CanvasModulate.new()
	cm.color = DAY
	add_child(cm)
	var sun := DirectionalLight2D.new()
	sun.color = Color(1.0, 0.9, 0.74)
	sun.energy = 0.2
	sun.rotation_degrees = 235.0  # from the upper right, like the sun in the sky
	sun.height = 0.45
	add_child(sun)
	var lantern_tex: Texture2D = load("res://assets/lightlook/lantern.png")
	for x in LANTERNS:
		var y := ground_y(x)
		var s := Sprite2D.new()
		s.texture = lantern_tex
		s.centered = false
		s.position = Vector2(x - 8, y - 44)
		s.z_index = -1
		s.use_parent_material = true
		add_child(s)
		var l := _light(Color(1.0, 0.78, 0.45), 0.6, 0.8)
		l.position = Vector2(x - 2.5, y - 26)
		_lanterns.append(l)
		_halo_sprite(Color(1.4, 1.1, 0.6, 0.4), 0.5, l.position)
	_portal_light = _light(Color(0.35, 1.0, 0.85), 1.1, 1.0)
	_portal_light.position = Vector2(1729, GROUND_Y - 56)
	_seal_light = _light(Color(1.0, 0.5, 0.2), 1.0, 0.9)
	_seal_light.position = Vector2(2064, GROUND_Y - 44)
	_star_light = _light(Color(0.5, 0.85, 1.0), 0.9, 0.8)
	_star_light.position = Vector2(1270, TERRACE_Y - 45)
	_halo_sprite(Color(0.6, 1.2, 1.6, 0.5), 0.55, _star_light.position)
	_forge_light = _light(Color(1.0, 0.55, 0.25), 1.2, 0.8)
	_forge_light.position = Vector2(930, GROUND_Y - 30)
	PostFx.add_heat_source(_forge_light, Vector2(0, -8), 26.0, 0.7)
	_halo_sprite(Color(1.6, 0.8, 0.3, 0.45), 0.5, Vector2(926, GROUND_Y - 32))
	var wl := _light(Color(0.85, 0.9, 1.0), 0.35, 0.42, walker)
	wl.position = Vector2(0, -24)


func _build_parallax() -> void:
	for spec in LAYERS:
		var cl := CanvasLayer.new()
		cl.layer = spec[2]
		add_child(cl)
		var s := Sprite2D.new()
		s.texture = load(DIR + "%s.png" % spec[0])
		s.centered = false
		s.region_enabled = true
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(2, 2)
		if spec[0] == "foreground":
			s.modulate = Color(0.75, 0.7, 0.8, 0.9)
		if spec[0] == "near":
			s.material = DuskStage.sway_material([1.0, 0.35, 0.64])  # wind in the courtyard trees
		cl.add_child(s)
		_layers.append([s, spec[1]])
		if spec[0] == "near":
			var atmo := Atmosphere.new()  # light morning mist over the near trees
			atmo.preset = "day"
			cl.add_child(atmo)


func _build_atmosphere() -> void:
	# sun shafts over the scene, under the foreground
	var cl := CanvasLayer.new()
	cl.layer = 2
	add_child(cl)
	_shafts = Sprite2D.new()
	_shafts.texture = load(DIR + "shafts.png")
	_shafts.centered = false
	_shafts.scale = Vector2(4, 4)
	_shafts.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_shafts.material = m
	_shafts.modulate = Color(1.0, 0.95, 0.8, 0.35)
	cl.add_child(_shafts)
	# cherry blossoms drifting through the courtyard
	_petals = CPUParticles2D.new()
	_petals.texture = load(DIR + "petal.png")
	_petals.amount = 46
	_petals.lifetime = 9.0
	_petals.preprocess = 9.0
	_petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_petals.emission_rect_extents = Vector2(420, 10)
	_petals.direction = Vector2(-1, 0.4)
	_petals.spread = 25.0
	_petals.initial_velocity_min = 14.0
	_petals.initial_velocity_max = 30.0
	_petals.gravity = Vector2(0, 9)
	_petals.angular_velocity_min = -120.0
	_petals.angular_velocity_max = 120.0
	_petals.angle_min = 0.0
	_petals.angle_max = 360.0
	_petals.scale_amount_min = 0.8
	_petals.scale_amount_max = 1.2
	_petals.z_index = 4
	_petals.local_coords = false
	var pm := CanvasItemMaterial.new()
	pm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_petals.material = pm
	add_child(_petals)


func _animate(_delta: float) -> void:
	var vis := get_viewport().get_visible_rect().size
	var c := camera.get_screen_center_position()
	for e in _layers:
		var s: Sprite2D = e[0]
		var f: float = e[1]
		var shift_y := 0.0 if f == 0.0 else -(c.y - 260.0) * f
		s.region_rect = Rect2(c.x * f, 0.0, vis.x / 2.0 + 2.0, 360.0)
		s.position = Vector2(0.0, shift_y * 2.0 + (vis.y - 720.0) * 0.5)
	_shafts.position = Vector2(vis.x - 1180.0 - fposmod(c.x * 0.1, 40.0), -40.0)
	_shafts.modulate.a = 0.28 + 0.07 * sin(_t * 0.6)
	_petals.global_position = c + Vector2(260, -200)
	for i in _lanterns.size():
		_lanterns[i].energy = 0.55 + 0.06 * sin(_t * 9.0 + i * 2.0)
	_forge_light.energy = 1.1 + 0.2 * sin(_t * 13.0) + 0.12 * sin(_t * 29.0)
	_portal_light.energy = 1.0 + 0.25 * sin(_t * 2.2)
	_seal_light.energy = 0.9 + 0.3 * absf(sin(_t * 1.4))
	_star_light.energy = 0.8 + 0.25 * sin(_t * 1.7)
	_walker_mat.set_shader_parameter("flip", float(walker.facing))
