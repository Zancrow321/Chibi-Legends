class_name LayeredBody
extends Node2D
## Spielerfigur aus dem Character Creator: Haut-Körper + Kleidungsebenen
## (Oberteil, Hose, Schuhe) mit einer Zeichnung pro Pose, dazu Teile am Anker:
## Frisur am Kopf, Waffe an der vorderen Hand, Waffen-Band per Seil-Physik.
##
## Benutzung:  body.look = CreatorCatalog.load_look();  body.play("run");  body.facing = -1
## Oder einzelne Posen: body.set_pose("slash_hit").  Signal pose_changed(name).
## Der Ursprung liegt zwischen den Füßen (Zelle 64x64, Fußpunkt 32/58).

signal pose_changed(pose: String)

const SHADER := preload("res://assets/shaders/creator_tint.gdshader")
const ORIGIN := Vector2(32, 58)
const CLOTH_ORDER := ["pants", "shoes", "top"]
const HEAD_DEADZONE := 12.0   # kleine Kopfneigungen ignorieren, damit die Frisur nicht zittert
const HEAD_LIMIT := 40.0

var look: Dictionary = {}:
	set(v):
		look = v
		if is_inside_tree():
			_apply_look()
var facing := 1:
	set(v):
		facing = 1 if v >= 0 else -1
		if _rig:
			_rig.scale.x = facing

var pose := "idle_0"
var anim := ""

var _rig: Node2D
var _body: Sprite2D
var _cloth := {}
var _hair: Sprite2D
var _weapon: Sprite2D
var _ribbon: Line2D
var _ribbon_shade: Line2D
var _ribbon_line: Line2D
var _wdata := {}
var _clock := 0.0
var _rope: PackedVector2Array = []
var _rope_old: PackedVector2Array = []


func _ready() -> void:
	CreatorCatalog.ensure()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rig = Node2D.new()
	_rig.scale.x = facing
	add_child(_rig)
	# Band hinter dem Körper
	_ribbon_line = _make_line(4.0, 0)
	_ribbon_shade = _make_line(2.0, 1)
	_ribbon = _make_line(2.0, 2)
	_body = _make_sprite(CreatorCatalog.texture(CreatorCatalog.data["body"]), true)
	for slot in CLOTH_ORDER:
		_cloth[slot] = _make_sprite(null, false)
	_hair = Sprite2D.new()
	_hair.centered = false
	_hair.material = _tint_material(false)
	_rig.add_child(_hair)
	_weapon = Sprite2D.new()
	_weapon.centered = false
	_rig.add_child(_weapon)
	if look.is_empty():
		look = CreatorCatalog.default_look()
	_apply_look()
	set_pose(pose)


func _make_sprite(tex: Texture2D, warm: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.offset = -ORIGIN
	s.material = _tint_material(warm)
	_rig.add_child(s)
	return s


func _make_line(width: float, z: int) -> Line2D:
	var l := Line2D.new()
	l.width = width
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.antialiased = false
	l.set_meta("layer", z)  # Reihenfolge über die Kind-Reihenfolge (liegt hinter dem Körper)
	_rig.add_child(l)
	return l


func _tint_material(warm: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("warm_only", warm)
	return m


func _apply_tint(node: CanvasItem, c: Dictionary) -> void:
	var m := node.material as ShaderMaterial
	if c.has("hue"):  # Hautton
		for k in ["hue", "sat", "val"]:
			m.set_shader_parameter(k, float(c[k]))
	else:
		var hex := str(c.get("color", ""))
		m.set_shader_parameter("amount", float(c.get("amount", 0.0)) if hex != "" else 0.0)
		if hex != "":
			m.set_shader_parameter("target", Color(hex))


func _apply_look() -> void:
	if _body == null:
		return
	var d: Dictionary = CreatorCatalog.data
	var colors: Dictionary = look.get("colors", {})
	_apply_tint(_body, d["skins"][clampi(int(look.get("skin", 1)), 0, d["skins"].size() - 1)])
	for slot in CLOTH_ORDER:
		var s: Sprite2D = _cloth[slot]
		s.texture = CreatorCatalog.slot_texture(slot, str(look.get(slot, "")))
		_apply_tint(s, d["colors"][clampi(int(colors.get(slot, 0)), 0, d["colors"].size() - 1)])
	var hid := str(look.get("hair", ""))
	_hair.texture = CreatorCatalog.slot_texture("hair", hid)
	if CreatorCatalog.hair_meta.has(hid):
		var n: Array = CreatorCatalog.hair_meta[hid]["neck"]
		_hair.offset = -Vector2(n[0], n[1])
	_apply_tint(_hair, d["colors"][clampi(int(colors.get("hair", 0)), 0, d["colors"].size() - 1)])
	var wid := str(look.get("weapon", ""))
	_wdata = d["weapons"].get(wid, {})
	_weapon.texture = CreatorCatalog.texture(_wdata["texture"]) if not _wdata.is_empty() else null
	if not _wdata.is_empty():
		var g: Array = _wdata["grip"]
		_weapon.scale = Vector2.ONE * float(_wdata.get("scale", 1))
		_weapon.offset = -Vector2(g[0], g[1])
		var r: Dictionary = _wdata.get("ribbon", {})
		_ribbon.default_color = Color(str(r.get("color", "e0e0e0")))
		_ribbon_shade.default_color = Color(str(r.get("shade", "c4c4c4")))
		_ribbon_line.default_color = Color(str(r.get("outline", "3d3d3d")))
	for l in [_ribbon, _ribbon_shade, _ribbon_line]:
		l.visible = not _wdata.is_empty() and _wdata.has("ribbon")
	_rope = PackedVector2Array()
	set_pose(pose)


## Eine Animation aus catalog.json abspielen (idle, walk, run, slash, twohand ...).
func play(name: String, restart := false) -> void:
	if name == anim and not restart:
		return
	anim = name
	_clock = 0.0
	_step_anim(0.0)


func set_pose(name: String) -> void:
	if _body == null or not CreatorCatalog.frames.has(name):
		pose = name
		return
	var changed := name != pose
	pose = name
	var r := CreatorCatalog.region(name)
	_body.region_rect = r
	for slot in CLOTH_ORDER:
		(_cloth[slot] as Sprite2D).region_rect = r
	var f: Dictionary = CreatorCatalog.frames[name]
	# Frisur: am Hals-Anker, gedreht um die Kopfneigung gegenüber idle_0
	var hid := str(look.get("hair", ""))
	if CreatorCatalog.hair_meta.has(hid):
		var ref_angle: float = CreatorCatalog.hair_meta[hid]["angle"]
		var da: float = clampf(float(f["head"]["angle"]) - ref_angle, -HEAD_LIMIT, HEAD_LIMIT)
		if absf(da) < HEAD_DEADZONE:
			da = 0.0
		_hair.position = _cell(f["head"]["pos"])
		_hair.rotation = -deg_to_rad(da)
	# Waffe: Griff auf die Faust, Klinge entlang des Unterarms
	if not _wdata.is_empty():
		var fa := float(f["hand_front"]["angle"])
		var a := deg_to_rad(fa)
		var dir := Vector2(sin(a), cos(a))
		_weapon.position = _cell(f["hand_front"]["pos"]) + dir * 2.0
		# Klingenrichtung: pro Pose aus catalog.json, sonst quer zum Unterarm (Faustgriff)
		var hold: Dictionary = CreatorCatalog.data.get("weapon_hold", {})
		var ba: float = float(hold.get("blade", {}).get(name, fa + float(hold.get("default_offset", 80))))
		var br := deg_to_rad(ba)
		dir = Vector2(sin(br), cos(br))
		var g: Array = _wdata["grip"]
		var t: Array = _wdata["tip"]
		var blade := Vector2(t[0] - g[0], t[1] - g[1])
		_weapon.rotation = dir.angle() - blade.angle()
	if changed:
		pose_changed.emit(name)


func _cell(p: Array) -> Vector2:
	return Vector2(p[0], p[1]) - ORIGIN


func _process(delta: float) -> void:
	_step_anim(delta)
	_step_ribbon(delta)


func _step_anim(delta: float) -> void:
	if anim == "":
		return
	var a: Dictionary = CreatorCatalog.data["animations"].get(anim, {})
	if a.is_empty():
		return
	_clock += delta
	var frames_list: Array = a["frames"]
	var idx := int(_clock * float(a["fps"]))
	idx = idx % frames_list.size() if a["loop"] else mini(idx, frames_list.size() - 1)
	set_pose(frames_list[idx])


## Band: Verlet-Seil am Knauf, schwingt der Handbewegung nach (60 Hz-Schritte).
func _step_ribbon(delta: float) -> void:
	if _wdata.is_empty() or not _wdata.has("ribbon"):
		return
	var r: Dictionary = _wdata["ribbon"]
	var n := int(r.get("length", 11))
	var seg := float(r.get("segment", 2.4))
	var g: Array = _wdata["grip"]
	var t: Array = _wdata["tip"]
	var blade := Vector2(t[0] - g[0], t[1] - g[1]).normalized().rotated(_weapon.rotation)
	var anchor := _weapon.position - blade * 4.0
	# im eigenen Raum rechnen (Spiegelung inklusive), unabhängig von der Vorschau-Skalierung
	var world_anchor := _rig.transform * anchor
	if _rope.size() != n:
		_rope.resize(n)
		_rope_old.resize(n)
		for i in n:
			_rope[i] = world_anchor + Vector2(0, seg * i)
			_rope_old[i] = _rope[i]
	var steps := maxi(1, int(round(delta * 60.0)))
	for s in steps:
		var tm := Time.get_ticks_msec() / 1000.0
		for i in range(1, n):
			var p := _rope[i]
			var v := (p - _rope_old[i]) * 0.92
			_rope_old[i] = p
			_rope[i] = p + v + Vector2(-0.015 * sin(tm * 4.2 + i * 0.6), 0.16)
		for _k in 6:
			_rope[0] = world_anchor
			for i in range(1, n):
				var d := _rope[i] - _rope[i - 1]
				var len := maxf(d.length(), 0.001)
				var diff := (len - seg) / len
				if i == 1:
					_rope[i] -= d * diff
				else:
					_rope[i - 1] += d * diff * 0.5
					_rope[i] -= d * diff * 0.5
	var local := PackedVector2Array()
	for p in _rope:
		local.append((_rig.transform.affine_inverse() * p).round())
	_ribbon.points = local
	var shade := PackedVector2Array()
	for p in local:
		shade.append(p + Vector2(0, 1))
	_ribbon_shade.points = shade
	_ribbon_line.points = local
