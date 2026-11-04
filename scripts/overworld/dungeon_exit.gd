class_name DungeonExit
extends Node2D
## The way back out of a combat area: the forest gate seen from the inside,
## with its portal swirling. Standing in front of it and pressing E (or up
## while not attacking) returns to the overworld via AreaTransition.
## Main adds it to the training room; it draws its own prompt bubble.

const REACH := 26.0

var room: TrainingRoom
var _gate: Sprite2D
var _light: PointLight2D
var _ui: Control
var _font: Font
var _alpha := 0.0
var _t := 0.0


func _ready() -> void:
	use_parent_material = true  # lit like the ground in the dusk view
	_gate = Sprite2D.new()
	_gate.texture = load("res://assets/overworld/gate_wald.png")
	_gate.centered = false
	_gate.offset = Vector2(-_gate.texture.get_width() * 0.5, -_gate.texture.get_height() + 1.0)
	_gate.use_parent_material = true
	add_child(_gate)
	var fx := PortalFx.new()
	fx.position = Vector2(-1, -56)
	add_child(fx)
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	_light = PointLight2D.new()
	_light.texture = tex
	_light.color = Color(0.35, 1.0, 0.85)
	_light.energy = 0.9
	_light.texture_scale = 0.9
	_light.position = Vector2(0, -56)
	_light.visible = DuskStage.enabled  # only the dusk view works with lights
	add_child(_light)
	_font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")
	var layer := CanvasLayer.new()
	layer.layer = 11  # above the combat HUD (its help panel covers the gate)
	add_child(layer)
	_ui = Control.new()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_prompt)
	layer.add_child(_ui)


func _process(delta: float) -> void:
	_t += delta
	_light.energy = 0.8 + 0.25 * sin(_t * 2.2)
	var p := room.player
	var near := absf(p.global_position.x - global_position.x) < REACH and absf(p.global_position.y - global_position.y) < 30.0
	_alpha = move_toward(_alpha, 1.0 if near else 0.0, delta * 8.0)
	if near and not AreaTransition.busy() and not get_tree().paused:
		var idle: bool = p.move.is_empty() and p.is_on_floor()
		if Input.is_action_just_pressed("interact") or (idle and Input.is_action_just_pressed("move_up") and not Input.is_action_pressed("light") and not Input.is_action_pressed("heavy")):
			AreaTransition.go("akademie_hof")
	_ui.size = _ui.get_viewport_rect().size
	_ui.queue_redraw()


func _draw_prompt() -> void:
	if _alpha <= 0.01:
		return
	var a := _alpha
	var anchor: Vector2 = get_viewport().get_canvas_transform() * (global_position + Vector2(0, -124))
	anchor.y -= (1.0 - a) * 8.0 + (2.0 if fmod(_t, 1.0) < 0.5 else 0.0)
	var verb := "Zur Akademie"
	var tw := _font.get_string_size(verb, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 64.0
	var r := Rect2(anchor.x - tw * 0.5, anchor.y - 40, tw, 32)
	_ui.draw_colored_polygon(PackedVector2Array([Vector2(anchor.x - 7, r.end.y - 2), Vector2(anchor.x + 7, r.end.y - 2), Vector2(anchor.x, r.end.y + 10)]), Color(UiSkin.INK, a))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiSkin.PAPER, a)
	sb.border_color = Color(UiSkin.INK, a)
	sb.set_border_width_all(2)
	_ui.draw_style_box(sb, r)
	_ui.draw_rect(Rect2(r.position.x + 3, r.position.y + 3, 4, r.size.y - 6), Color(Color("0eaf9b"), a))
	var kp := r.position + Vector2(13, 5)
	_ui.draw_rect(Rect2(kp, Vector2(22, 21)), Color(UiSkin.RED, a))
	_ui.draw_rect(Rect2(kp, Vector2(22, 21)), Color(UiSkin.INK, a), false, 2.0)
	_ui.draw_string(_font, kp + Vector2(0, 16), "E", HORIZONTAL_ALIGNMENT_CENTER, 22, 15, Color(UiSkin.PAPER, a))
	_ui.draw_string_outline(_font, r.position + Vector2(44, 22), verb, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 4, Color(UiSkin.PAPER, a))
	_ui.draw_string(_font, r.position + Vector2(44, 22), verb, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(UiSkin.INK, a))
