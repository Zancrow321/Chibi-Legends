class_name Appearance
extends RefCounted
## Sprite parts and colors of the fixed characters: reads the part catalog and
## the curated palettes, merges skins into a look and builds the recolor
## palettes for the shader.
##
## A look is a plain Dictionary (JSON-friendly):
## {
##   "parts": {"body": "koerper_basis", "hair": "haar_stachelig", "top": ...},  # slot -> item
##   "colors": {"skin": "haut_1", "hair": "haar_rot", "eyes": "augen_braun"},
##   "item_colors": {"oberteil_akademie": ["weiss", "rot"]},                     # per item, per channel
## }
## Characters and their skins live in Roster (assets/characters/characters.json).

const CATALOG_PATH := "res://assets/characters/catalog.json"
const PALETTES_PATH := "res://assets/characters/palettes.json"
const SHADER := preload("res://assets/shaders/palette_swap.gdshader")

# Tone ramp from one base color, mirrors tools/sprites/rig.py RAMP.
const RAMP := [["o", 0.0], ["d", 0.55], ["d", 0.30], ["d", 0.15], ["b", 0.0], ["l", 0.25], ["l", 0.50], ["l", 0.75]]

static var _catalog: Dictionary = {}
static var _palettes: Dictionary = {}
static var _color_index: Dictionary = {}
static var _textures: Dictionary = {}
static var _palette_cache: Dictionary = {}


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		_catalog = read_json(CATALOG_PATH)
	return _catalog


static func palettes() -> Dictionary:
	if _palettes.is_empty():
		_palettes = read_json(PALETTES_PATH)
		for group in _palettes:
			if String(group).begins_with("_"):
				continue
			for entry in _palettes[group]:
				_color_index[entry.id] = entry
	return _palettes


static func read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Appearance: %s fehlt" % path)
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		return data
	push_error("Appearance: %s ist kein gültiges JSON" % path)
	return {}


# --- catalog access ---

static func layers() -> Array:
	return catalog().get("layers", [])


static func columns() -> int:
	return int(catalog().get("columns", 8))


static func row_count() -> int:
	return catalog().get("anims", {}).size()


static func origin() -> Vector2:
	var o: Array = catalog().get("origin", [28, 56])
	return Vector2(o[0], o[1])


static func anim(anim_name: String) -> Dictionary:
	var anims: Dictionary = catalog().get("anims", {})
	if anims.has(anim_name):
		return anims[anim_name]
	return anims.get("idle", {"row": 0, "frames": 1, "fps": 1, "loop": true})


static func item(id: String) -> Dictionary:
	return catalog().get("items", {}).get(id, {})


static func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]


# --- colors ---

static func color_entry(id: String) -> Dictionary:
	palettes()
	return _color_index.get(id, {})


static func ramp(base: Color) -> Array:
	var fixed: Array = catalog().get("fixed_colors", ["1a1020"])
	var out: Array = []
	for step in RAMP:
		match step[0]:
			"o":
				out.append(Color(String(fixed[0])))
			"d":
				out.append(base.darkened(step[1]))
			"l":
				out.append(base.lightened(step[1]))
			_:
				out.append(base)
	return out


static func channel_color(it: Dictionary, index: int, look: Dictionary) -> String:
	var ch: Dictionary = it.channels[index]
	if ch.get("appearance", false):
		return String(look.get("colors", {}).get(ch.key, ""))
	var ov: Array = look.get("item_colors", {}).get(it.id, [])
	if index < ov.size() and ov[index] is String and ov[index] != "":
		return ov[index]
	return String(ch.get("default", ""))


static func palette_texture(it: Dictionary, look: Dictionary) -> ImageTexture:
	var ids: PackedStringArray = []
	for i in it.channels.size():
		ids.append(channel_color(it, i, look))
	var key: String = it.id + ":" + ",".join(ids)
	if _palette_cache.has(key):
		return _palette_cache[key]
	var img := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.MAGENTA)  # a missing color shows up loudly
	for i in ids.size():
		var e := color_entry(ids[i])
		var tones := ramp(Color(String(e.get("color", "ff00ff"))))
		for t in 8:
			img.set_pixel(t, i, tones[t])
	var fixed: Array = catalog().get("fixed_colors", [])
	for t in mini(8, fixed.size()):
		img.set_pixel(t, 3, Color(String(fixed[t])))
	var tex := ImageTexture.create_from_image(img)
	_palette_cache[key] = tex
	return tex


# --- looks ---

## Deep copy of `base` with `patch` (a skin) merged on top.
static func merged(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key in ["parts", "colors", "item_colors"]:
		var into: Dictionary = out.get(key, {})
		var add: Dictionary = patch.get(key, {})
		for k in add:
			into[k] = add[k].duplicate() if add[k] is Array else add[k]
		out[key] = into
	return out


## slot -> item id for every part that exists in the catalog.
static func parts(look: Dictionary) -> Dictionary:
	var out := {}
	var p: Dictionary = look.get("parts", {})
	for slot in p:
		var id := String(p[slot])
		if id != "" and not item(id).is_empty():
			out[slot] = id
	return out
