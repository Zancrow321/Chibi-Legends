class_name Roster
extends RefCounted
## The playable characters (fixed looks, obtained through gacha) and the
## player's collection: owned characters with copies and level, skins, and
## the character being played. Saved locally for now, Supabase later.
## Rules: pick 1 of the starters for free, the rest via gacha. Every character
## has its own level 1-50. Duplicates unlock skill-tree branches 4-6 (choice,
## not power; ranked arena only uses the 3 base branches).

const CHARACTERS_PATH := "res://assets/characters/characters.json"
const SAVE_PATH := "user://sammlung.json"
## Training build: every character and skin can be tried out.
## Set to false once gacha and unlocks exist.
const DEV_UNLOCK_ALL := true
const MAX_LEVEL := 50
const BASE_BRANCHES := 3
const MAX_BRANCHES := 6

const RARITY := {
	3: {"name": "Selten", "color": Color("5ca8ff")},
	4: {"name": "Episch", "color": Color("b36bff")},
	5: {"name": "Legendär", "color": Color("ffc23d")},
}
const UNLOCK_NAMES := {
	"start": "Start-Charakter", "gacha": "Gacha", "pass": "Saison-Pass",
	"shop": "Kosmetik-Shop", "challenge": "Herausforderung",
}

static var _data: Dictionary = {}
static var _save: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = Appearance.read_json(CHARACTERS_PATH)
	return _data


static func ids() -> Array:
	var out: Array = data().get("characters", {}).keys()
	out.sort_custom(func(a, b):
		var ra := int(character(a).get("rarity", 3))
		var rb := int(character(b).get("rarity", 3))
		return ra > rb if ra != rb else String(a) < String(b))
	return out


## Characters you can pick for free on the very first start.
static func starters() -> Array:
	return data().get("starters", [])


## Fallback character (shown before anything is picked).
static func starter() -> String:
	var s := starters()
	if not s.is_empty():
		return String(s[0])
	return String(ids()[0]) if not ids().is_empty() else ""


static func character(id: String) -> Dictionary:
	return data().get("characters", {}).get(id, {})


static func world_name(world: String) -> String:
	return String(data().get("worlds", {}).get(world, world))


static func skin(char_id: String, skin_id: String) -> Dictionary:
	for s in character(char_id).get("skins", []):
		if s.id == skin_id:
			return s
	return {}


## Look of a character, with a skin merged in when skin_id is not empty.
static func look(char_id: String, skin_id := "") -> Dictionary:
	var base: Dictionary = character(char_id).get("look", {})
	var s := skin(char_id, skin_id)
	return Appearance.merged(base, s.get("look", {})) if not s.is_empty() else base.duplicate(true)


# --- collection ---

static func _state() -> Dictionary:
	if _save.is_empty():
		_save = {"owned": {}, "owned_skins": [], "selected": "", "skin": ""}
		if FileAccess.file_exists(SAVE_PATH):
			var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
			var d = JSON.parse_string(f.get_as_text()) if f else null
			if d is Dictionary:
				for k in _save:
					if d.has(k) and typeof(d[k]) == typeof(_save[k]):
						_save[k] = d[k]
		if _save.selected != "" and character(_save.selected).is_empty():
			_save.selected = ""
			_save.skin = ""
	return _save


## True until the player has picked their free starter.
static func needs_starter() -> bool:
	return _state().owned.is_empty()


static func choose_starter(char_id: String) -> void:
	if needs_starter() and char_id in starters():
		grant(char_id)
		select(char_id)


static func owns(char_id: String) -> bool:
	return DEV_UNLOCK_ALL or _state().owned.has(char_id)


static func owns_skin(skin_id: String) -> bool:
	return DEV_UNLOCK_ALL or skin_id == "" or skin_id in _state().owned_skins


## Copies, level and xp of an owned character (defaults for others).
static func progress(char_id: String) -> Dictionary:
	var p: Dictionary = _state().owned.get(char_id, {})
	return {"copies": int(p.get("copies", 0)), "level": int(p.get("level", 1)), "xp": int(p.get("xp", 0))}


## Skill-tree branches open for this character: 3 base + 1 per duplicate, up to 6.
static func branches(char_id: String) -> int:
	return BASE_BRANCHES + clampi(progress(char_id).copies - 1, 0, MAX_BRANCHES - BASE_BRANCHES)


static func selected() -> String:
	var s: String = _state().selected
	return s if s != "" else starter()


static func selected_skin() -> String:
	return _state().skin


static func select(char_id: String, skin_id := "") -> void:
	if not owns(char_id) or not owns_skin(skin_id):
		return
	var s := _state()
	s.selected = char_id
	s.skin = skin_id
	_write()


## Gacha / shop reward. A character you already own counts as a duplicate.
static func grant(char_id: String) -> void:
	if character(char_id).is_empty():
		return
	var owned: Dictionary = _state().owned
	if owned.has(char_id):
		owned[char_id].copies = int(owned[char_id].get("copies", 1)) + 1
	else:
		owned[char_id] = {"copies": 1, "level": 1, "xp": 0}
	_write()


static func grant_skin(skin_id: String) -> void:
	var s := _state()
	if not skin_id in s.owned_skins:
		s.owned_skins.append(skin_id)
		_write()


static func _write() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_state(), "\t"))
