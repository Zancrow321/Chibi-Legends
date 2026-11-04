class_name ChibiVisual
extends Node2D
## Paper-doll chibi (about 32 x 48 px): one Sprite2D per layer, all playing
## the same frame of the shared sheet layout (tools/sprites/rig.py).
## Origin = between the feet. Faces right; the owner flips it via scale.x.
## Colors come from a palette-swap shader, so every part works in every color.

## The player's look (see Appearance). Assigning it rebuilds the layers.
var look: Dictionary = {}:
	set = set_look
## Equipped items per gear slot; shown unless the look overrides the slot.
var equipment: Dictionary = GameData.START_EQUIPMENT.duplicate():
	set = set_equipment
var state := "idle"  # idle, run, jump, fall, attack, dash, cast, hit, ko
var anim_time := 0.0
var attack_phase := 0  # 0..2 combo step, picks attack_1..3
## Hit flash 0..1 (white), for later damage feedback.
var flash := 0.0:
	set = set_flash

var _sprites: Dictionary = {}  # layer -> Sprite2D
var _anim := ""


func _init() -> void:
	var cols := Appearance.columns()
	var rows := maxi(1, Appearance.row_count())
	for layer in Appearance.layers():
		var s := Sprite2D.new()
		s.name = String(layer)
		s.centered = false
		s.offset = -Appearance.origin()
		s.hframes = cols
		s.vframes = rows
		s.visible = false
		add_child(s)
		_sprites[layer] = s
	look = GameData.LOOK_PRESETS[0]


func _process(delta: float) -> void:
	anim_time += delta
	_apply_frame()


func set_state(new_state: String) -> void:
	if new_state != state:
		state = new_state
		anim_time = 0.0


func set_look(value: Dictionary) -> void:
	look = Appearance.normalized(value)
	_rebuild()


func set_equipment(value: Dictionary) -> void:
	equipment = value.duplicate()
	_rebuild()


func set_flash(value: float) -> void:
	flash = value
	for s in _sprites.values():
		var mat := (s as Sprite2D).material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("flash", flash)


func _rebuild() -> void:
	if _sprites.is_empty():
		return
	for s in _sprites.values():
		s.visible = false
	var slots := Appearance.resolve(look, equipment)
	for slot in slots:
		var it := Appearance.item(slots[slot])
		if it.is_empty():
			continue
		var mat := ShaderMaterial.new()
		mat.shader = Appearance.SHADER
		mat.set_shader_parameter("palette", Appearance.palette_texture(it, look))
		mat.set_shader_parameter("flash", flash)
		var item_layers: Dictionary = it.layers
		for layer in item_layers:
			var s: Sprite2D = _sprites.get(layer)
			if s == null:
				continue
			s.texture = Appearance.texture(item_layers[layer])
			s.material = mat
			s.visible = true
	_apply_frame()


func _anim_name() -> String:
	if state == "attack":
		return "attack_%d" % (clampi(attack_phase, 0, 2) + 1)
	return state


func _apply_frame() -> void:
	var anim_name := _anim_name()
	if anim_name != _anim:
		_anim = anim_name
		anim_time = 0.0
	var a := Appearance.anim(anim_name)
	var count := maxi(1, int(a.frames))
	var idx := int(anim_time * float(a.fps))
	idx = idx % count if a.loop else mini(idx, count - 1)
	var f := int(a.row) * Appearance.columns() + idx
	for s in _sprites.values():
		if s.visible:
			s.frame = f
