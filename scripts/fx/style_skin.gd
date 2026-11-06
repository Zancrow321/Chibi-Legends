class_name StyleSkin
extends RefCounted
## Effekt-Skins der Kampfstile (nur Optik, nie Werte).
##
## Ein Skin färbt alle Effekte eines Stils um: Funken, Flammen, Wellen, die
## PixelLab-Effektstreifen, den Meisterzug, Geschosse und die kurzen
## Lichtblitze. Die Figur bleibt, wie sie ist. Technik: jeder CanvasItem der
## Stil-Effekte bekommt ein ShaderMaterial, das dieselbe Mischart wie vorher
## hat (additiv, unbeleuchtet ...) und die Farbe danach dreht:
##   Farbton drehen (um die Graue Achse, Weiß und Grau bleiben), Sättigung,
##   Helligkeit, optional ein Farbverlauf über die bunten Stellen und eine
##   Tönung (tint), die auch Weiß einfärbt (für helle Stile).
## HDR-Werte über 1 bleiben erhalten, das Bloom leuchtet also weiter.
##
## Daten: assets/combat/skins.json. Gespeichert: user://skins.json
## (besessene Skins und der aktive Skin pro Stil).
##   StyleSkin.attach(player)        nach player.init_style()
##   StyleSkin.set_active(style, id) im Stil-Menü, färbt sofort um
##   StyleSkin.map_color(skin, col)  dieselbe Umfärbung auf der CPU (Lichter, Schwünge)

const DATA_PATH := "res://assets/combat/skins.json"
const SAVE := "user://skins.json"
const DEFAULT := ""  # Standard-Look des Stils
const FX_FIELDS := ["fx", "mfx", "kfx", "bfx", "wfx", "gfx", "ffx"]
const LUMA := Vector3(0.299, 0.587, 0.114)
const CLIP_SCRIPTS := ["res://scripts/schwarzmond/mond_clip.gd", "res://scripts/lauffeuer/feuer_strip.gd"]

static var data: Dictionary = {}
static var owned: Array = []        # "stil/skin"
static var active: Dictionary = {}  # stil -> skin id ("" = Standard)
static var _loaded := false
static var _shaders: Dictionary = {}  # render_mode -> Shader
static var _mats: Dictionary = {}     # skin key + render_mode -> ShaderMaterial
static var _player: Player = null     # the player whose effects are painted


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			data = d
	var s := FileAccess.open(SAVE, FileAccess.READ)
	if s:
		var sd: Variant = JSON.parse_string(s.get_as_text())
		if sd is Dictionary:
			owned = sd.get("owned", [])
			active = sd.get("active", {})


static func save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"owned": owned, "active": active}))


# --- data ------------------------------------------------------------------------

static func skins(style_id: String) -> Array:
	ensure()
	return data.get("styles", {}).get(style_id, [])


static func all_styles() -> Array:
	ensure()
	return data.get("styles", {}).keys()


static func info(style_id: String, skin_id: String) -> Dictionary:
	for s in skins(style_id):
		if str(s.id) == skin_id:
			return s
	return {}


static func skin_name(style_id: String, skin_id: String) -> String:
	if skin_id == DEFAULT:
		return "Standard"
	return str(info(style_id, skin_id).get("name", skin_id))


static func owns(style_id: String, skin_id: String) -> bool:
	ensure()
	return skin_id == DEFAULT or ("%s/%s" % [style_id, skin_id]) in owned


static func unlock(style_id: String, skin_id: String) -> bool:
	ensure()
	if owns(style_id, skin_id) or info(style_id, skin_id).is_empty():
		return false
	owned.append("%s/%s" % [style_id, skin_id])
	save()
	return true


static func unlock_all() -> void:
	for st in all_styles():
		for s in skins(st):
			unlock(st, str(s.id))


## Where a locked skin comes from ("" = owned).
static func hint(style_id: String, skin_id: String) -> String:
	if owns(style_id, skin_id):
		return ""
	var u: Dictionary = info(style_id, skin_id).get("unlock", {})
	if u.get("banner", false):
		for b in Gacha.banners():
			if str(b.get("style", "")) == style_id:
				return "Sternschrein: Banner »%s« (Episch)" % str(b.get("title", ""))
		return "Sternschrein (Episch)"
	if u.has("pass"):
		SeasonPass.ensure()
		var track := str(u.pass)
		for r in SeasonPass.data.get(track, []):
			if str(r.get("kind", "")) == "skin" and str(r.get("id", "")) == skin_id:
				return "Saisonpass %s, Stufe %d" % ["Gratis-Spur" if track == "free" else "Premium-Spur", int(r.tier)]
		return "Saisonpass"
	return "noch nicht erhältlich"


## Skins a banner can give as an Episch prize (not yet owned).
static func banner_skins(style_id: String) -> Array:
	var out: Array = []
	for s in skins(style_id):
		if s.get("unlock", {}).get("banner", false) and not owns(style_id, str(s.id)):
			out.append(s)
	return out


static func active_id(style_id: String) -> String:
	ensure()
	var id := str(active.get(style_id, DEFAULT))
	return id if owns(style_id, id) and (id == DEFAULT or not info(style_id, id).is_empty()) else DEFAULT


static func current(style_id: String) -> Dictionary:
	var id := active_id(style_id)
	return {} if id == DEFAULT else info(style_id, id)


static func set_active(style_id: String, skin_id: String) -> void:
	ensure()
	if not owns(style_id, skin_id):
		return
	active[style_id] = skin_id
	save()
	if is_instance_valid(_player) and _player.style != null and _player.style.id == style_id:
		attach(_player)


# --- colour maths (same as the shader) --------------------------------------------

static func map_color(skin: Dictionary, c: Color) -> Color:
	if skin.is_empty():
		return c
	var v := _map_rgb(skin, Vector3(c.r, c.g, c.b))
	return Color(v.x, v.y, v.z, c.a)


static func _map_rgb(skin: Dictionary, c: Vector3) -> Vector3:
	var a := deg_to_rad(float(skin.get("hue", 0.0)))
	var m := _hue_matrix(a)
	var r := Vector3(m[0].dot(c), m[1].dot(c), m[2].dot(c))
	var gray := r.dot(LUMA)
	r = Vector3(gray, gray, gray).lerp(r, float(skin.get("sat", 1.0))) * float(skin.get("val", 1.0))
	var ramp: Array = skin.get("ramp", [])
	if ramp.size() == 3:
		var mx := maxf(c.x, maxf(c.y, c.z))
		var mn := minf(c.x, minf(c.y, c.z))
		var w := clampf((mx - mn) / maxf(mx, 0.001) * 1.6, 0.0, 1.0) * float(skin.get("ramp_mix", 1.0))
		var l := c.dot(LUMA)
		var lc := clampf(l, 0.0, 1.0)
		var c0 := Color(str(ramp[0]))
		var c1 := Color(str(ramp[1]))
		var c2 := Color(str(ramp[2]))
		var rc: Color = c0.lerp(c1, lc * 2.0) if lc < 0.5 else c1.lerp(c2, lc * 2.0 - 1.0)
		var rv := Vector3(rc.r, rc.g, rc.b) * maxf(1.0, mx)
		r = r.lerp(rv, w)
	var tm := float(skin.get("tint_mix", 0.0))
	if tm > 0.0:
		var tc := Color(str(skin.get("tint", "ffffff")))
		r = r.lerp(Vector3(tc.r, tc.g, tc.b) * maxf(r.x, maxf(r.y, r.z)), tm)
	return Vector3(maxf(r.x, 0.0), maxf(r.y, 0.0), maxf(r.z, 0.0))


static func _hue_matrix(a: float) -> Array:
	var cs := cos(a)
	var sn := sin(a)
	var k := (1.0 - cs) / 3.0
	var q := sqrt(1.0 / 3.0) * sn
	return [Vector3(cs + k, k - q, k + q), Vector3(k + q, cs + k, k - q), Vector3(k - q, k + q, cs + k)]


# --- shader materials ----------------------------------------------------------------

static func _shader(mode: String) -> Shader:
	if not _shaders.has(mode):
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
render_mode %s;
// Effekt-Skin (scripts/fx/style_skin.gd): Farbton um die Grauachse drehen,
// Sättigung, Helligkeit, optional ein Farbverlauf über die bunten Stellen.
uniform vec3 m0 = vec3(1.0, 0.0, 0.0);
uniform vec3 m1 = vec3(0.0, 1.0, 0.0);
uniform vec3 m2 = vec3(0.0, 0.0, 1.0);
uniform float sat = 1.0;
uniform float val = 1.0;
uniform float ramp_mix = 0.0;
uniform vec3 ramp0 = vec3(0.0);
uniform vec3 ramp1 = vec3(0.5);
uniform vec3 ramp2 = vec3(1.0);
uniform float tint_mix = 0.0;
uniform vec3 tint = vec3(1.0);

void fragment() {
	vec3 c = COLOR.rgb;
	vec3 r = vec3(dot(m0, c), dot(m1, c), dot(m2, c));
	float gray = dot(r, vec3(0.299, 0.587, 0.114));
	r = mix(vec3(gray), r, sat) * val;
	if (ramp_mix > 0.0) {
		float mx = max(c.r, max(c.g, c.b));
		float mn = min(c.r, min(c.g, c.b));
		float w = clamp((mx - mn) / max(mx, 0.001) * 1.6, 0.0, 1.0) * ramp_mix;
		float l = clamp(dot(c, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);
		vec3 rc = l < 0.5 ? mix(ramp0, ramp1, l * 2.0) : mix(ramp1, ramp2, l * 2.0 - 1.0);
		r = mix(r, rc * max(1.0, mx), w);
	}
	if (tint_mix > 0.0) {
		r = mix(r, tint * max(r.r, max(r.g, r.b)), tint_mix);
	}
	COLOR.rgb = max(r, vec3(0.0));
}
""" % mode
		_shaders[mode] = sh
	return _shaders[mode]


static func _mode_of(base: Material) -> String:
	var blend := "blend_mix"
	var light := ""
	var cm := base as CanvasItemMaterial
	if cm != null:
		match cm.blend_mode:
			CanvasItemMaterial.BLEND_MODE_ADD:
				blend = "blend_add"
			CanvasItemMaterial.BLEND_MODE_SUB:
				blend = "blend_sub"
			CanvasItemMaterial.BLEND_MODE_MUL:
				blend = "blend_mul"
			CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA:
				blend = "blend_premul_alpha"
		match cm.light_mode:
			CanvasItemMaterial.LIGHT_MODE_UNSHADED:
				light = ", unshaded"
			CanvasItemMaterial.LIGHT_MODE_LIGHT_ONLY:
				light = ", light_only"
	return blend + light


static func material_for(skin: Dictionary, base: Material) -> ShaderMaterial:
	var mode := _mode_of(base)
	var key := "%s|%s" % [str(skin.get("id", "")), mode]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = _shader(mode)
	var hm := _hue_matrix(deg_to_rad(float(skin.get("hue", 0.0))))
	m.set_shader_parameter("m0", hm[0])
	m.set_shader_parameter("m1", hm[1])
	m.set_shader_parameter("m2", hm[2])
	m.set_shader_parameter("sat", float(skin.get("sat", 1.0)))
	m.set_shader_parameter("val", float(skin.get("val", 1.0)))
	var ramp: Array = skin.get("ramp", [])
	if ramp.size() == 3:
		m.set_shader_parameter("ramp_mix", float(skin.get("ramp_mix", 1.0)))
		for i in 3:
			var c := Color(str(ramp[i]))
			m.set_shader_parameter("ramp%d" % i, Vector3(c.r, c.g, c.b))
	if float(skin.get("tint_mix", 0.0)) > 0.0:
		var tc := Color(str(skin.get("tint", "ffffff")))
		m.set_shader_parameter("tint_mix", float(skin.tint_mix))
		m.set_shader_parameter("tint", Vector3(tc.r, tc.g, tc.b))
	_mats[key] = m
	return m


## Paints a node and everything below it with the skin ({} = original look).
## Nodes added later are painted too (one frame later, after their _ready).
static func paint(node: Node, skin: Dictionary) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.set_meta("style_skin", skin)
	_paint_one(node, skin)
	for c in node.get_children():
		paint(c, skin)
	if not node.has_meta("skin_hooked"):
		node.set_meta("skin_hooked", true)
		node.child_entered_tree.connect(_on_child)


static func _on_child(child: Node) -> void:
	_paint_deferred.call_deferred(child)


static func _paint_deferred(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var parent := node.get_parent()
	if parent != null and parent.has_meta("style_skin"):
		paint(node, parent.get_meta("style_skin"))


static func _paint_one(node: Node, skin: Dictionary) -> void:
	var ci := node as CanvasItem
	if ci == null or ci.use_parent_material or ci is Light2D:
		return
	var cur := ci.material
	var base: Material = ci.get_meta("skin_base") if ci.has_meta("skin_base") else cur
	if cur != null and not ci.has_meta("skin_base"):
		# custom shaders (heat haze ...) and animated particle sheets stay as they are
		if cur is ShaderMaterial or (cur is CanvasItemMaterial and (cur as CanvasItemMaterial).particles_animation):
			return
	if cur != null and ci.has_meta("skin_base") and cur != base and not _mats.values().has(cur):
		base = cur  # the script swapped the material itself in the meantime
	ci.set_meta("skin_base", base)
	ci.material = base if skin.is_empty() else material_for(skin, base)


# --- the player -----------------------------------------------------------------------

## Paints every effect of the player's fighting style with its active skin:
## the caster (blade heat, fists ...), the caster's effect layers, and every
## super, wave, projectile or clone the caster spawns later.
static func attach(player: Player) -> void:
	_player = player
	var caster: GlutCaster = player.glut
	if caster == null or player.style == null:
		return
	var skin := current(player.style.id)
	var world := player.world as TrainingRoom
	paint(caster, skin)
	for f in FX_FIELDS:
		if f in caster:
			var n: Variant = caster.get(f)
			if n is Node and (world == null or n != world.glut_fx):
				paint(n, skin)
	if caster.fx != null:
		caster.fx.skin = skin
	if world == null:
		return
	for holder in [world, world.attacks]:
		if holder == null:
			continue
		for c in holder.get_children():
			if c.get("caster") == caster or _is_style_clip(c):
				_claim(c)
				paint(c, skin)
		if not holder.is_connected("child_entered_tree", _on_world_child):
			holder.child_entered_tree.connect(_on_world_child)


static func _on_world_child(child: Node) -> void:
	_check_spawn.call_deferred(child)


static func _check_spawn(child: Node) -> void:
	if not is_instance_valid(child) or not is_instance_valid(_player) or _player.glut == null:
		return
	if child.get("caster") == _player.glut or _is_style_clip(child):
		_claim(child)
		paint(child, current(_player.style.id))


## Effect strips the styles spawn without a caster reference (PixelLab clips
## of Schwarzmond, flame strips of Lauffeuer). Only the player's style uses them.
static func _is_style_clip(n: Node) -> bool:
	var sc: Script = n.get_script()
	return sc != null and sc.resource_path in CLIP_SCRIPTS


## A spawned effect that borrows its parent's material (the dusk look does that
## for plain attack nodes) gets its own copy, so the skin can colour it.
static func _claim(n: Node) -> void:
	var ci := n as CanvasItem
	if ci != null and ci.use_parent_material and ci.get_parent() is CanvasItem:
		ci.use_parent_material = false
		ci.material = (ci.get_parent() as CanvasItem).material


## Skin colour of the player's style for CPU-drawn things (swing trails).
static func player_color(player: Player, c: Color) -> Color:
	if player == null or player.style == null:
		return c
	return map_color(current(player.style.id), c)


# --- icons --------------------------------------------------------------------------

static var _icons: Dictionary = {}


## A skill icon of the style (PixelLab art) recoloured with the skin, for
## menus, the shrine and the pass. Cached; null when the icon is missing.
static func icon(style_id: String, skin_id: String, zug := "meisterzug") -> Texture2D:
	var key := "%s/%s/%s" % [style_id, skin_id, zug]
	if _icons.has(key):
		return _icons[key]
	var p := "res://assets/combat/icons/%s/%s.png" % [style_id, zug]
	var tex: Texture2D = null
	if ResourceLoader.exists(p):
		var src: Texture2D = load(p)
		var skin := info(style_id, skin_id) if skin_id != DEFAULT else {}
		if skin.is_empty():
			tex = src
		else:
			var img := src.get_image()
			if img != null:
				img = img.duplicate()
				img.decompress()
				img.convert(Image.FORMAT_RGBA8)
				for y in img.get_height():
					for x in img.get_width():
						var c := img.get_pixel(x, y)
						if c.a > 0.0:
							var m := map_color(skin, c)
							img.set_pixel(x, y, Color(minf(m.r, 1.0), minf(m.g, 1.0), minf(m.b, 1.0), c.a))
				tex = ImageTexture.create_from_image(img)
	_icons[key] = tex
	return tex
