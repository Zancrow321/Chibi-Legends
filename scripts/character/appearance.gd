class_name Appearance
extends RefCounted
## Character looks: reads the part catalog and curated palettes, resolves which
## part is shown in each slot (equipment or cosmetic override = switchable
## transmog), builds the recolor palettes and saves the player's look.
##
## A look is a plain Dictionary so it saves as JSON and syncs easily later:
## {
##   "body": "koerper_basis", "face": "gesicht_standard", "hair": "haar_stachelig",
##   "colors": {"skin": "haut_1", "hair": "haar_rot", "eyes": "augen_braun"},
##   "cosmetics": {"top": "", ...},   # "" = show equipment, "none" = hide, else item id
##   "item_colors": {"oberteil_akademie": ["weiss", "rot"]},  # per item, per channel
## }

const CATALOG_PATH := "res://assets/characters/catalog.json"
const PALETTES_PATH := "res://assets/characters/palettes.json"
const SAVE_PATH := "user://charakter.json"
const SHADER := preload("res://assets/shaders/palette_swap.gdshader")

## Slots that come from equipment and can be overridden by a cosmetic.
const GEAR_SLOTS := ["top", "pants", "shoes", "accessory", "headgear", "weapon"]
## Slots that may be left empty ("Nichts").
const HIDEABLE := ["accessory", "headgear"]
const SLOT_NAMES := {
	"body": "Körper", "face": "Gesicht", "hair": "Haare", "top": "Oberteil", "pants": "Hose",
	"shoes": "Schuhe", "accessory": "Accessoire", "headgear": "Kopf", "weapon": "Waffe",
}
const UNLOCK_NAMES := {"pass": "Saison-Pass", "challenge": "Herausforderung", "shop": "Kosmetik-Shop", "gacha": "Gacha"}
const APPEARANCE_COLORS := {"skin": "haut", "hair": "haar", "eyes": "augen"}

# Tone ramp from one base color, mirrors tools/sprites/rig.py RAMP.
const RAMP := [["o", 0.0], ["d", 0.55], ["d", 0.30], ["d", 0.15], ["b", 0.0], ["l", 0.25], ["l", 0.50], ["l", 0.75]]

static var _catalog: Dictionary = {}
static var _palettes: Dictionary = {}
static var _color_index: Dictionary = {}
static var _textures: Dictionary = {}
static var _palette_cache: Dictionary = {}
## Unlocked rare colors (id -> true). Filled from progress / Supabase later.
static var unlocked_colors: Dictionary = {}


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		_catalog = _read_json(CATALOG_PATH)
	return _catalog


static func palettes() -> Dictionary:
	if _palettes.is_empty():
		_palettes = _read_json(PALETTES_PATH)
		for group in _palettes:
			if String(group).begins_with("_"):
				continue
			for entry in _palettes[group]:
				_color_index[entry.id] = entry
	return _palettes


static func _read_json(path: String) -> Dictionary:
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


static func items_for_slot(slot: String) -> Array:
	var out: Array = []
	var items: Dictionary = catalog().get("items", {})
	for id in items:
		if items[id].slot == slot:
			out.append(id)
	out.sort()
	return out


static func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]


# --- colors ---

static func palette_group(group: String) -> Array:
	return palettes().get(group, [])


static func color_entry(id: String) -> Dictionary:
	palettes()
	return _color_index.get(id, {})


static func is_locked(id: String) -> bool:
	var e := color_entry(id)
	return String(e.get("unlock", "")) != "" and not unlocked_colors.has(id)


static func lock_text(id: String) -> String:
	var e := color_entry(id)
	var how: String = UNLOCK_NAMES.get(e.get("unlock", ""), "")
	var hint: String = e.get("hint", "")
	return "Freischaltbar: %s" % (hint if hint != "" else how)


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
		var group: String = ch.group
		var picked: String = look.get("colors", {}).get(ch.key, "")
		if picked != "":
			return picked
		var lst := palette_group(group)
		return lst[0].id if not lst.is_empty() else ""
	var ov: Array = look.get("item_colors", {}).get(it.id, [])
	if index < ov.size() and ov[index] is String and ov[index] != "":
		return ov[index]
	return ch.get("default", "")


static func palette_texture(it: Dictionary, look: Dictionary) -> ImageTexture:
	var ids: PackedStringArray = []
	for i in it.channels.size():
		ids.append(channel_color(it, i, look))
	var key: String = it.id + ":" + ",".join(ids)
	if _palette_cache.has(key):
		return _palette_cache[key]
	var img := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.MAGENTA)
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

static func default_look() -> Dictionary:
	return {
		"body": "koerper_basis", "face": "gesicht_standard", "hair": "haar_stachelig",
		"colors": {"skin": "haut_1", "hair": "haar_rot", "eyes": "augen_braun"},
		"cosmetics": {}, "item_colors": {},
	}


## Returns a deep copy with all keys present and unknown parts replaced.
static func normalized(look: Dictionary) -> Dictionary:
	var out := default_look()
	for k in ["body", "face", "hair"]:
		var id: String = look.get(k, out[k])
		if not item(id).is_empty() and item(id).slot == k:
			out[k] = id
	var colors: Dictionary = look.get("colors", {})
	for k in APPEARANCE_COLORS:
		var cid: String = colors.get(k, out.colors[k])
		if not color_entry(cid).is_empty():
			out.colors[k] = cid
	var cos: Dictionary = look.get("cosmetics", {})
	for slot in GEAR_SLOTS:
		var c: String = cos.get(slot, "")
		if c == "none" or (not item(c).is_empty() and item(c).slot == slot):
			out.cosmetics[slot] = c
	var ic: Dictionary = look.get("item_colors", {})
	for id in ic:
		if not item(id).is_empty() and ic[id] is Array:
			out.item_colors[id] = (ic[id] as Array).duplicate()
	return out


## slot -> item id that is drawn. Cosmetic override wins, "none" hides,
## otherwise the equipped item's look is shown.
static func resolve(look: Dictionary, equipment: Dictionary) -> Dictionary:
	var out := {"body": look.get("body", "koerper_basis"), "face": look.get("face", "gesicht_standard"), "hair": look.get("hair", "haar_stachelig")}
	var cos: Dictionary = look.get("cosmetics", {})
	for slot in GEAR_SLOTS:
		var c: String = cos.get(slot, "")
		if c == "none":
			continue
		var id: String = c if c != "" else String(equipment.get(slot, ""))
		if id != "" and not item(id).is_empty():
			out[slot] = id
	return out


static func random_look() -> Dictionary:
	var look := default_look()
	for k in ["face", "hair"]:
		look[k] = items_for_slot(k).pick_random()
	for k in APPEARANCE_COLORS:
		look.colors[k] = _random_free(APPEARANCE_COLORS[k])
	for slot in GEAR_SLOTS:
		var opts: Array = [""] + items_for_slot(slot)
		if slot in HIDEABLE:
			opts.append("none")
		look.cosmetics[slot] = opts.pick_random()
	for id in catalog().get("items", {}):
		var it := item(id)
		var cols: Array = []
		for ch in it.channels:
			cols.append("" if ch.get("appearance", false) else _random_free(ch.group))
		look.item_colors[id] = cols
	return look


static func _random_free(group: String) -> String:
	var free: Array = palette_group(group).filter(func(e): return not is_locked(e.id))
	return free.pick_random().id if not free.is_empty() else ""


static func save_look(look: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(look, "\t"))


## Saved look, or an empty Dictionary when the player has none yet.
static func load_look() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text()) if f else null
	return normalized(data) if data is Dictionary else {}
