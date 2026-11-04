class_name DuskStage
extends Node2D
## Dusk light look for the training ground (adapted from the light-look test
## of the "Licht" art direction): the play layer gets a dusk tint and a low
## warm sun, lanterns, crystals, fireflies and a forge glow give real 2D
## light, light is posterised into hard steps (pixel_lit shader) and the
## figures get automatic rounded normals, so fire from the side models them.
## Behind it a parallax diorama, in front a dark blurred foreground.
##
## For the fighting style it offers short light flashes (sparks, impacts) and
## lights for burning hazards. The number of live lights is capped, because
## the browser renderer only blends a limited number of lights per sprite.
## It is the "Licht" view of Main (default); Main sets `enabled` per view.
## N jumps between Licht and the flat view, ?abend=0 in the URL starts flat.

const DUSK := Color(0.3, 0.26, 0.42)
const LANTERNS := [300.0, 760.0, 1180.0]
const CRYSTALS := [[60.0, Color(0.45, 0.85, 1.0)], [650.0, Color(0.62, 0.5, 1.0)], [1370.0, Color(0.45, 0.85, 1.0)]]
const FORGE_X := 1060.0
const FIREFLIES := 6
const MAX_FLASHES := 4
const MAX_HAZARD_LIGHTS := 3
## [texture, scroll factor, canvas layer]
const LAYERS := [["sky", 0.0, -5], ["mountains", 0.06, -4], ["forest_far", 0.16, -3], ["forest_mid", 0.32, -2], ["trees_near", 0.58, -1], ["foreground", 1.3, 3]]

static var enabled := true

var room: TrainingRoom

var _light_tex: GradientTexture2D
var _lit_shader: Shader
var _halo: Texture2D
var _layers: Array = []  # [Sprite2D, factor]
var _lanterns: Array[PointLight2D] = []
var _crystals: Array = []  # [PointLight2D, Sprite2D halo, phase]
var _flies: Array = []
var _flashes: Array = []  # {light, t, life, energy}
var _hazard_lights: Array = []
var _player_light: PointLight2D
var _forge_light: PointLight2D
var _forge_emit := 0.0
var _player_mat: ShaderMaterial
var _t := 0.0


func _ready() -> void:
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
	_lit_shader = load("res://shaders/lightlook/pixel_lit.gdshader")
	_halo = load("res://assets/lightlook/halo.png")
	_hide_old_background()

	var cm := CanvasModulate.new()
	cm.color = DUSK
	room.add_child(cm)
	var sun := DirectionalLight2D.new()
	sun.color = Color(1.0, 0.62, 0.42)
	sun.energy = 0.22
	sun.rotation_degrees = -55.0
	sun.height = 0.3
	room.add_child(sun)

	# terrain: posterised light; figures: rounded normals
	var tm := ShaderMaterial.new()
	tm.shader = _lit_shader
	room.material = tm
	for d in room.get_tree().get_nodes_in_group("targets"):
		var r: Rect2 = d.get_hurt_rect()
		light_figure(d, Rect2(r.position - d.global_position, r.size))
	_player_mat = ShaderMaterial.new()
	_player_mat.shader = _lit_shader
	_player_mat.set_shader_parameter("auto_normal", true)
	_player_mat.set_shader_parameter("half_w", 12.0)
	_player_mat.set_shader_parameter("half_h", 26.0)
	_player_mat.set_shader_parameter("center_y", -26.0)
	room.player.sprite.set_body_material(_player_mat)

	# effects and attacks glow: not darkened by the dusk
	var glow := CanvasItemMaterial.new()
	glow.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	room.effects.material = glow
	room.attacks.material = glow
	for c in room.attacks.get_children():
		_on_attack(c)
	room.attacks.child_entered_tree.connect(_on_attack)
	var fxm := CanvasItemMaterial.new()
	fxm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	room.fx.material = fxm
	for c in room.fx.get_children():
		if c is CanvasItem and (c as CanvasItem).material == null:
			(c as CanvasItem).use_parent_material = true
	var hs := room.fx.sparks.material as CanvasItemMaterial
	if hs != null:
		hs.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	_player_light = _light(Color(0.85, 0.9, 1.0), 0.45, 0.42)
	room.player.add_child(_player_light)
	_player_light.position = Vector2(0, -24)

	for x in LANTERNS:
		_lantern(x)
	for c in CRYSTALS:
		_crystal(c[0], c[1])
	for i in FIREFLIES:
		_firefly(i)
	_forge()
	_build_parallax()


func _hide_old_background() -> void:
	var main := room.get_parent()
	if main == null:
		return
	for c in main.get_children():
		if c is CanvasLayer:
			for k in c.get_children():
				if k is ForestBackground:
					(c as CanvasLayer).visible = false


func _light(color: Color, energy: float, scale: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.color = color
	l.energy = energy
	l.texture_scale = scale
	l.height = 30.0
	return l


func _halo_sprite(color: Color, scale: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _halo
	s.modulate = color
	s.scale = Vector2(scale, scale)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	s.material = m
	return s


## Rounded-normal lighting for a figure drawn around its foot point.
func light_figure(node: CanvasItem, r: Rect2) -> void:
	var m := ShaderMaterial.new()
	m.shader = _lit_shader
	m.set_shader_parameter("auto_normal", true)
	m.set_shader_parameter("half_w", r.size.x * 0.5)
	m.set_shader_parameter("half_h", r.size.y * 0.5)
	m.set_shader_parameter("center_y", r.position.y + r.size.y * 0.5)
	node.material = m


func _ground_y(x: float) -> float:
	for gr in TrainingRoom.GROUND:
		if x >= gr[0] and x <= gr[0] + gr[2]:
			return gr[1]
	return TrainingRoom.GROUND_Y


func _lantern(x: float) -> void:
	var y := _ground_y(x)
	var s := Sprite2D.new()
	s.texture = load("res://assets/lightlook/lantern.png")
	s.centered = false
	s.position = Vector2(x - 8, y - 44)
	s.z_index = -1
	room.add_child(s)
	var glass := Vector2(x - 2.5, y - 26)
	var l := _light(Color(1.0, 0.72, 0.38), 1.5, 1.2)
	l.position = glass
	room.add_child(l)
	_lanterns.append(l)
	var h := _halo_sprite(Color(1.0, 0.75, 0.4, 0.6), 0.8)
	h.position = glass
	room.add_child(h)


func _crystal(x: float, color: Color) -> void:
	var y := _ground_y(x)
	var s := Sprite2D.new()
	s.texture = load("res://assets/lightlook/crystal.png")
	s.centered = false
	s.position = Vector2(x - 11, y - 25)
	s.z_index = -1
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	s.material = m
	room.add_child(s)
	var l := _light(color, 1.0, 0.7)
	l.position = Vector2(x, y - 12)
	room.add_child(l)
	var h := _halo_sprite(Color(color, 0.5), 0.75)
	h.position = l.position
	room.add_child(h)
	_crystals.append([l, h, randf() * TAU])


func _firefly(i: int) -> void:
	var base := Vector2(fposmod(i * 233.0 + 140.0, TrainingRoom.WIDTH), 200.0 + fposmod(i * 37.0, 70.0))
	var s := _halo_sprite(Color(0.85, 1.0, 0.5, 0.9), 0.09)
	room.add_child(s)
	var l := _light(Color(0.75, 1.0, 0.45), 0.6, 0.16)
	room.add_child(l)
	_flies.append({"sprite": s, "light": l, "base": base, "phase": i * 1.7})


## Forge (Esse) on the raised ground: a stone hearth with glowing coals that
## lights the sparring corner. Drawn by ForgeHearth, fire by GlutFx.
func _forge() -> void:
	var y := _ground_y(FORGE_X)
	var hearth := ForgeHearth.new()
	hearth.position = Vector2(FORGE_X, y)
	hearth.z_index = -1
	room.add_child(hearth)
	var hm := ShaderMaterial.new()
	hm.shader = _lit_shader
	hearth.material = hm
	_forge_light = _light(Color(1.0, 0.5, 0.22), 1.6, 1.0)
	_forge_light.position = Vector2(FORGE_X, y - 18)
	room.add_child(_forge_light)
	var h := _halo_sprite(Color(1.0, 0.45, 0.2, 0.55), 0.9)
	h.position = Vector2(FORGE_X, y - 14)
	room.add_child(h)


func _build_parallax() -> void:
	for spec in LAYERS:
		var cl := CanvasLayer.new()
		cl.layer = spec[2]
		add_child(cl)
		var s := Sprite2D.new()
		s.texture = load("res://assets/lightlook/%s.png" % spec[0])
		s.centered = false
		s.region_enabled = true
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(2, 2)
		cl.add_child(s)
		_layers.append([s, spec[1]])


# --- lights for the fighting style ---------------------------------------------

## A short flash of light. Close flashes merge, at most MAX_FLASHES live.
func flash_light(pos: Vector2, col: Color, energy: float, size: float, life: float) -> void:
	for f in _flashes:
		if (f.light as PointLight2D).position.distance_to(pos) < 24.0:
			f.t = 0.0
			f.life = maxf(f.life - f.t, life)
			f.energy = maxf(f.energy, energy)
			f.light.texture_scale = maxf(f.light.texture_scale, size)
			f.light.color = col
			return
	var l: PointLight2D
	if _flashes.size() >= MAX_FLASHES:
		var oldest: Dictionary = _flashes.pop_front()
		l = oldest.light
	else:
		l = _light(col, energy, size)
		room.add_child(l)
	l.position = pos
	l.color = col
	l.texture_scale = size
	l.energy = energy
	_flashes.append({"light": l, "t": 0.0, "life": life, "energy": energy})


## A light for a burning hazard (the caller adds it as a child and animates
## its energy). Returns null when too many are live.
func make_light(col: Color, energy: float, size: float) -> PointLight2D:
	_hazard_lights = _hazard_lights.filter(func(l): return is_instance_valid(l))
	if _hazard_lights.size() >= MAX_HAZARD_LIGHTS:
		return null
	var l := _light(col, energy, size)
	_hazard_lights.append(l)
	return l


func _on_attack(node: Node) -> void:
	if node is CanvasItem and (node as CanvasItem).material == null:
		(node as CanvasItem).use_parent_material = true


func _process(delta: float) -> void:
	_t += delta
	var vis := get_viewport().get_visible_rect().size
	var c: Vector2 = room.camera.get_screen_center_position()
	for e in _layers:
		var s: Sprite2D = e[0]
		var f: float = e[1]
		var shift_y := 0.0 if f == 0.0 else -(c.y - 260.0) * f
		s.region_rect = Rect2(c.x * f, 0.0, vis.x / 2.0 + 2.0, 360.0)
		s.position = Vector2(0.0, shift_y * 2.0 + (vis.y - 720.0) * 0.5)
	for i in _lanterns.size():
		_lanterns[i].energy = 1.45 + 0.1 * sin(_t * 11.0 + i * 2.0) + 0.06 * sin(_t * 23.0 + i)
	for c2 in _crystals:
		var k := 0.5 + 0.5 * sin(_t * 1.6 + c2[2])
		c2[0].energy = 0.7 + 0.4 * k
		c2[1].modulate.a = 0.3 + 0.35 * k
	for f2 in _flies:
		var p: Vector2 = f2.base + Vector2(sin(_t * 0.7 + f2.phase) * 40.0, sin(_t * 1.3 + f2.phase * 2.0) * 18.0)
		f2.sprite.position = p
		f2.light.position = p
		f2.sprite.modulate.a = 0.55 + 0.45 * sin(_t * 3.0 + f2.phase)
	# forge: flickering light, flames and embers rising from the coals
	_forge_light.energy = 1.5 + 0.25 * sin(_t * 13.0) + 0.15 * sin(_t * 29.0 + 1.0)
	_forge_emit -= delta
	if _forge_emit <= 0.0 and room.glut_fx != null:
		_forge_emit = 0.07
		var fy := _ground_y(FORGE_X) - 15.0
		room.glut_fx.flame(Vector2(FORGE_X + randf_range(-7, 7), fy), randf_range(3.0, 5.5), Vector2(randf_range(-6, 6), randf_range(-45, -25)), 0.45, 0.8)
		if randf() < 0.35:
			room.glut_fx.embers(Vector2(FORGE_X, fy - 4), 1, 6.0, 45.0, 1.3)
		if randf() < 0.12:
			room.glut_fx.smoke(Vector2(FORGE_X + randf_range(-4, 4), fy - 14), 7.0, Vector2(randf_range(-4, 4), -16), 1.8)
	# flashes fade (they run during hit-stop too)
	for fl in _flashes:
		fl.t += delta
		fl.light.energy = fl.energy * maxf(0.0, 1.0 - fl.t / fl.life)
	for fl in _flashes.filter(func(x): return x.t >= x.life):
		fl.light.queue_free()
	_flashes = _flashes.filter(func(x): return x.t < x.life)
	# the player's rounded normal follows the facing
	_player_mat.set_shader_parameter("flip", float(room.player.facing))
	# the heated blade lights the figure and the ground
	var heat: float = room.player.glut.blade_heat() if room.player.glut != null else 0.0
	_player_light.color = Color(0.85, 0.9, 1.0).lerp(GlutFx.heat(0.6 + heat * 0.3), clampf(heat * 1.4, 0.0, 1.0))
	_player_light.energy = 0.45 + heat * (0.9 + 0.12 * sin(_t * 21.0))
	_player_light.texture_scale = 0.42 + heat * 0.2
	_player_light.position = Vector2(room.player.facing * heat * 10.0, -24)
