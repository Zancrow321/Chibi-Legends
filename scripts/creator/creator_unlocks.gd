class_name CreatorUnlocks
extends RefCounted
## Was der Spieler im Character Creator schon freigeschaltet hat.
## Teile ohne "unlock"-Eintrag in catalog.json sind von Anfang an frei, der Rest
## wird im Spiel freigeschaltet: CreatorUnlocks.unlock("top", "ronin") oder
## CreatorUnlocks.unlock_color(6). Hauttöne sind immer alle frei.
## Gespeichert in user://freigeschaltet.json. Für Tests: unlock_all().

const SAVE := "user://freigeschaltet.json"

static var _data := {}
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_data = d


static func _save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_data))


## Hinweis, wie man ein Teil bekommt ("" = frei).
static func hint(slot: String, id: String) -> String:
	CreatorCatalog.ensure()
	if id == "":
		return ""
	var u: Dictionary = CreatorCatalog.data["slots"].get(slot, {}).get("unlock", {})
	return str(u.get(id, ""))


static func is_unlocked(slot: String, id: String) -> bool:
	if hint(slot, id) == "":
		return true
	_load()
	return id in _data.get(slot, [])


static func unlock(slot: String, id: String) -> void:
	_load()
	var list: Array = _data.get(slot, [])
	if not id in list:
		list.append(id)
		_data[slot] = list
		_save()


static func color_hint(index: int) -> String:
	CreatorCatalog.ensure()
	var c: Array = CreatorCatalog.data["colors"]
	return str(c[index].get("unlock", "")) if index < c.size() else ""


static func is_color_unlocked(index: int) -> bool:
	if color_hint(index) == "":
		return true
	_load()
	return index in _data.get("colors", []).map(func(v): return int(v))


static func unlock_color(index: int) -> void:
	_load()
	var list: Array = _data.get("colors", [])
	if not float(index) in list and not index in list:
		list.append(index)
		_data["colors"] = list
		_save()


## Test-Hilfe (Taste F9 im Creator): alles freischalten.
static func unlock_all() -> void:
	CreatorCatalog.ensure()
	for slot in CreatorCatalog.data["slots"]:
		for id in CreatorCatalog.data["slots"][slot].get("unlock", {}):
			unlock(slot, id)
	for i in CreatorCatalog.data["colors"].size():
		unlock_color(i)
