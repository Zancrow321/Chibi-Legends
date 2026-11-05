class_name LightLook
extends Node2D
## Look test "Licht": modern pixel art with dynamic 2D lighting at dusk,
## in front of a parallax diorama. Everything stays plain 2D (cheap in the
## browser). Pieces:
##  - dusk tint on the play layer (CanvasModulate) + a low warm sun
##  - lanterns on the training ground, glowing crystals and fireflies in the forest
##  - every attack carries a light in its element color, hits flash
##  - characters get an automatic rounded normal, so lights model them
##  - light is posterised into hard steps to stay pixel-art
##  - parallax layers behind (pre-blurred by distance) and a dark, blurred
##    foreground in front of the play layer
## The graphics preset is fixed at Hoch (full shadows and lights).

const DUSK := Color(0.3, 0.26, 0.42)
const LANTERNS := [300.0, 760.0, 1180.0]
const CRYSTALS := [[60.0, Color(0.45, 0.85, 1.0)], [650.0, Color(0.62, 0.5, 1.0)], [960.0, Color(0.45, 0.85, 1.0)], [1340.0, Color(0.62, 0.5, 1.0)]]
const FIREFLIES := 12
## [texture, scroll factor, canvas layer]
const LAYERS := [["sky", 0.0, -5], ["mountains", 0.06, -4], ["forest_far", 0.16, -3], ["forest_mid", 0.32, -2], ["trees_near", 0.58, -1], ["foreground", 1.3, 3]]

var room: TrainingRoom

var _light_tex: GradientTexture2D
var _lit_shader: Shader
var _palette_lit: Shader
var _halo: Texture2D
var _sun: DirectionalLight2D
var _layers: Array = []  # [Sprite2D, factor]
var _lanterns: Array[PointLight2D] = []
var _crystals: Array = []  # [PointLight2D, Sprite2D halo, phase]
var _flies: Array = []  # {sprite, light, base, phase}
var _flashes: Array = []  # [PointLight2D, life]
var _player_light: PointLight2D
var _occluders: Array[LightOccluder2D] = []
var _t := 0.0


func _ready() -> void:
	add_to_group("hd2d_view")  # apply_quality(); quality is fixed at Hoch
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

	var cm := CanvasModulate.new()
	cm.color = DUSK
	room.add_child(cm)
	_sun = DirectionalLight2D.new()
	_sun.color = Color(1.0, 0.62, 0.42)
	_sun.energy = 0.22
	_sun.rotation_degrees = -55.0
	_sun.height = 0.3
	room.add_child(_sun)

	# terrain and characters: posterised light, rounded normals for characters
	var tm := ShaderMaterial.new()
	tm.shader = _lit_shader
	room.material = tm
	_palette_lit = load("res://shaders/lightlook/palette_lit.gdshader")
	_light_player()
	for d in room.get_tree().get_nodes_in_group("targets"):
		var r: Rect2 = d.get_hurt_rect()
		_light_character(d, Rect2(r.position - d.global_position, r.size))

	# effects and attacks glow: unaffected by light and dusk
	var glow := CanvasItemMaterial.new()
	glow.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	room.effects.material = glow
	room.attacks.material = glow
	room.attacks.child_entered_tree.connect(_on_attack)
	room.hit_landed.connect(_on_hit)

	_player_light = _light(Color(0.85, 0.9, 1.0), 0.5, 0.45)
	room.player.add_child(_player_light)
	_player_light.position = Vector2(0, -24)

	for x in LANTERNS:
		_lantern(x)
	for c in CRYSTALS:
		_crystal(c[0], c[1])
	for i in FIREFLIES:
		_firefly(i)
	_build_occluders()
	_build_parallax()
	apply_quality()


func _light(color: Color, energy: float, scale: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.color = color
	l.energy = energy
	l.texture_scale = scale
	l.height = 30.0
	l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	l.shadow_color = Color(0, 0, 0, 0.55)
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


func _light_character(node: CanvasItem, r: Rect2) -> void:
	var m := ShaderMaterial.new()
	m.shader = _lit_shader
	m.set_shader_parameter("auto_normal", true)
	m.set_shader_parameter("half_w", r.size.x * 0.5)
	m.set_shader_parameter("half_h", r.size.y * 0.5)
	m.set_shader_parameter("center_y", r.position.y + r.size.y * 0.5)
	node.material = m


## The player is a paper doll: each layer sprite has its own palette material,
## rebuilt whenever the look changes. Switch those to the lit palette shader.
func _light_player() -> void:
	var v := room.player.visual
	for s in v.get_children():
		var m := (s as CanvasItem).material as ShaderMaterial
		if m == null:
			continue
		if m.shader != _palette_lit:
			m.shader = _palette_lit
			m.set_shader_parameter("half_w", 10.0)
			m.set_shader_parameter("half_h", 24.0)
			m.set_shader_parameter("center_y", -24.0)
		m.set_shader_parameter("flip", v.scale.x)


func _lantern(x: float) -> void:
	var y := _ground_y(x)
	var s := Sprite2D.new()
	s.texture = load("res://assets/lightlook/lantern.png")
	s.centered = false
	s.position = Vector2(x - 8, y - 44)
	s.z_index = -1
	room.add_child(s)
	var glass := Vector2(x - 2.5, y - 26)
	var l := _light(Color(1.0, 0.72, 0.38), 1.6, 1.3)
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
	var l := _light(color, 1.0, 0.8)
	l.position = Vector2(x, y - 12)
	room.add_child(l)
	var h := _halo_sprite(Color(color, 0.5), 0.75)
	h.position = l.position
	room.add_child(h)
	_crystals.append([l, h, randf() * TAU])


func _firefly(i: int) -> void:
	var base := Vector2(fposmod(i * 131.0 + 40.0, TrainingRoom.WIDTH), 200.0 + fposmod(i * 37.0, 80.0))
	var s := _halo_sprite(Color(0.85, 1.0, 0.5, 0.9), 0.09)
	room.add_child(s)
	var l := _light(Color(0.75, 1.0, 0.45), 0.7, 0.18)
	room.add_child(l)
	_flies.append({"sprite": s, "light": l, "base": base, "phase": i * 1.7})


func _ground_y(x: float) -> float:
	for g in TrainingRoom.GROUND:
		if x >= g[0] and x <= g[0] + g[2]:
			return g[1]
	return TrainingRoom.GROUND_Y


func _build_occluders() -> void:
	# floating ledges and dummies throw shadows away from the lanterns
	for p in TrainingRoom.PLATFORMS:
		_occluder(Rect2(p[0] + 6, p[1], p[2] - 12, 14))
	for d in room.get_tree().get_nodes_in_group("targets"):
		var r: Rect2 = d.get_hurt_rect()
		var o := _occluder(Rect2(r.position - d.global_position + Vector2(4, 4), r.size - Vector2(8, 8)), d)
		o.position = Vector2.ZERO


func _occluder(r: Rect2, parent: Node = null) -> LightOccluder2D:
	var o := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	o.occluder = poly
	(parent if parent else room).add_child(o)
	_occluders.append(o)
	return o


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


func apply_quality() -> void:
	var q := Hd2dSettings.quality
	var shadows := q >= 2
	for l in _lanterns:
		l.shadow_enabled = shadows
	for c in _crystals:
		c[0].shadow_enabled = shadows
	for o in _occluders:
		o.visible = shadows
	var live: int = [0, 4, FIREFLIES][q]
	for i in _flies.size():
		_flies[i].light.visible = i < live
	_sun.visible = q >= 1
	if _layers.size() > 0:
		_layers[-1][0].get_parent().visible = q >= 1  # blurred foreground


func _on_attack(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).use_parent_material = true
	_attach_attack_light.call_deferred(node)


func _attach_attack_light(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var el: String = node.get("element") if node.get("element") != null else ""
	var col: Color = GameData.ELEMENTS.get(el, GameData.ELEMENTS[""]).color
	var energy := 0.6 if el == "" else 1.3
	var l := _light(col, energy, 0.4 if el == "" else 0.65)
	l.shadow_enabled = false
	node.add_child(l)


func _on_hit(pos: Vector2, color: Color, strong: bool) -> void:
	var l := _light(color, 2.0 if strong else 1.2, 1.1 if strong else 0.5)
	l.position = pos
	room.add_child(l)
	_flashes.append([l, 0.0, 0.35 if strong else 0.16, l.energy])


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
		var l := _lanterns[i]
		l.energy = 1.55 + 0.1 * sin(_t * 11.0 + i * 2.0) + 0.06 * sin(_t * 23.0 + i)
	for c2 in _crystals:
		var k := 0.5 + 0.5 * sin(_t * 1.6 + c2[2])
		c2[0].energy = 0.75 + 0.45 * k
		c2[1].modulate.a = 0.3 + 0.35 * k
	for f2 in _flies:
		var p: Vector2 = f2.base + Vector2(sin(_t * 0.7 + f2.phase) * 40.0, sin(_t * 1.3 + f2.phase * 2.0) * 18.0)
		f2.sprite.position = p
		f2.light.position = p
		f2.sprite.modulate.a = 0.55 + 0.45 * sin(_t * 3.0 + f2.phase)
	for fl in _flashes:
		fl[1] += delta
		fl[0].energy = fl[3] * maxf(0.0, 1.0 - fl[1] / fl[2])
	for fl in _flashes.filter(func(x): return x[1] >= x[2]):
		fl[0].queue_free()
	_flashes = _flashes.filter(func(x): return x[1] < x[2])
	_light_player()
