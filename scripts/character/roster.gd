class_name Roster
extends RefCounted
## The playable characters (fixed looks, obtained through gacha) and the
## player's collection: which characters and skins they own and which one
## they play. Saved locally for now, Supabase later.

const CHARACTERS_PATH := "res://assets/characters/characters.json"
const SAVE_PATH := "user://sammlung.json"
## Training build: every character and skin can be tried out.
## Set to false once gacha and unlocks exist.
const DEV_UNLOCK_ALL := true

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


static func starter() -> String:
	return String(data().get("starter", ids()[0] if not ids().is_empty() else ""))


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
		_save = {"owned": [starter()], "owned_skins": [], "selected": starter(), "skin": ""}
		if FileAccess.file_exists(SAVE_PATH):
			var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
			var d = JSON.parse_string(f.get_as_text()) if f else null
			if d is Dictionary:
				for k in _save:
					if d.has(k) and typeof(d[k]) == typeof(_save[k]):
						_save[k] = d[k]
		if character(_save.selected).is_empty():
			_save.selected = starter()
			_save.skin = ""
	return _save


static func owns(char_id: String) -> bool:
	return DEV_UNLOCK_ALL or char_id in _state().owned or character(char_id).get("unlock", "") == "start"


static func owns_skin(skin_id: String) -> bool:
	return DEV_UNLOCK_ALL or skin_id == "" or skin_id in _state().owned_skins


static func selected() -> String:
	return _state().selected


static func selected_skin() -> String:
	return _state().skin


static func select(char_id: String, skin_id := "") -> void:
	if not owns(char_id) or not owns_skin(skin_id):
		return
	var s := _state()
	s.selected = char_id
	s.skin = skin_id
	_write()


## For gacha / shop / pass rewards later.
static func grant(char_id: String) -> void:
	var s := _state()
	if not char_id in s.owned:
		s.owned.append(char_id)
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
