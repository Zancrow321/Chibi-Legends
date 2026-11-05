class_name CreatorCatalog
extends RefCounted
## Daten des Character Creators: Katalog (assets/creator/catalog.json),
## Ankerpunkte pro Pose (assets/creator/base/anchors.json) und die Texturen.
## Winkel in den Daten: Grad, 0 = nach unten, positiv = nach vorne, 180 = nach oben.

const PATH := "res://assets/creator/catalog.json"
const PARTS := "res://assets/creator/parts/"
const SAVE := "user://figur.json"

static var data := {}
static var frames := {}        # Posenname -> {index, head, hand_front, hand_back, back, feet}
static var frame_order: Array = []
static var hair_meta := {}
static var _tex := {}


static func ensure() -> void:
	if not data.is_empty():
		return
	data = _json(PATH)
	var a: Dictionary = _json(data["anchors"])
	var i := 0
	for f in a["frames"]:
		f["index"] = i
		frames[f["name"]] = f
		frame_order.append(f["name"])
		i += 1
	hair_meta = _json(PARTS + "hair/hair.json")


static func _json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f else {}


static func texture(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


static func slot_texture(slot: String, id: String) -> Texture2D:
	if id == "":
		return null
	return texture(PARTS + slot + "/" + id + ".png")


static func slot_items(slot: String) -> Array:
	ensure()
	return data["slots"][slot]["items"].keys()


static func item_name(slot: String, id: String) -> String:
	ensure()
	if id == "":
		return "keins"
	return data["slots"][slot]["items"].get(id, id)


## Zellen-Rechteck einer Pose im Sheet.
static func region(pose: String) -> Rect2:
	ensure()
	var cols: int = data["cols"]
	var cell: int = data["cell"]
	var idx: int = frames[pose]["index"] if frames.has(pose) else 0
	return Rect2((idx % cols) * cell, (idx / cols) * cell, cell, cell)


## Standard-Figur, wenn noch nichts gespeichert ist.
static func default_look() -> Dictionary:
	return {"hair": "stachel", "top": "kampfweste", "pants": "kampfweste", "shoes": "kampfweste",
		"weapon": "glutklinge", "skin": 1, "style": "glutatem",
		"colors": {"hair": 0, "top": 0, "pants": 0, "shoes": 0}}


static func load_look() -> Dictionary:
	var look := default_look()
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f:
		var saved: Variant = JSON.parse_string(f.get_as_text())
		if saved is Dictionary:
			look.merge(saved, true)
			# Glutatem got its own katana: older saves still carry the
			# Zweihänder; switch once, later choices stay as they are
			if not saved.has("glutklinge") and str(look.get("style", "")) == "glutatem" \
					and str(look.get("weapon", "")) == "schwert_kaiser":
				look["weapon"] = "glutklinge"
	look["glutklinge"] = true
	return look


static func save_look(look: Dictionary) -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(look))
