class_name FightingStyle
extends RefCounted
## A fighting style from assets/combat/styles/<id>.json: its J/K moveset,
## the Züge for the special button (each with three alternatives, only one
## active), the slot loadout (neutral, forward, up, down) and the Meisterzug
## (super) with its variants. The player's choices are saved per style.

const DIRS := ["neutral", "forward", "up", "down"]
const DIR_NAMES := {"neutral": "neutral", "forward": "vor", "up": "oben", "down": "unten"}

var id := ""
var data: Dictionary = {}
var zuege: Dictionary = {}
var zug_order: Array = []
## direction -> zug id ("" = empty slot)
var loadout: Dictionary = {}
## zug id -> active alternative id ("" = Grundform)
var active_alt: Dictionary = {}
var super_variant := ""


static func load_style(style_id: String) -> FightingStyle:
	var st := FightingStyle.new()
	st.id = style_id
	var path := "res://assets/combat/styles/%s.json" % style_id
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("FightingStyle: %s fehlt" % path)
		return st
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("FightingStyle: %s ist kein gültiges JSON" % path)
		return st
	st.data = parsed
	st.zuege = parsed.get("zuege", {})
	st.zug_order = st.zuege.keys()
	st.loadout = parsed.get("loadout", {}).duplicate()
	for z in st.zug_order:
		st.active_alt[z] = ""
	st.super_variant = st.variants()[0].id if st.variants().size() > 0 else ""
	st._load_choices()
	return st


func style_name() -> String:
	return data.get("name", id)


func moveset_path() -> String:
	return data.get("moveset", "")


func color(key: String) -> Color:
	return Color(data.get("colors", {}).get(key, "ffffff"))


func zug(zug_id: String) -> Dictionary:
	return zuege.get(zug_id, {})


func zug_in(dir: String) -> String:
	return loadout.get(dir, "")


func variants() -> Array:
	return data.get("meisterzug", {}).get("variants", [])


func variant() -> Dictionary:
	for v in variants():
		if v.id == super_variant:
			return v
	return {}


func super_cost() -> float:
	return float(data.get("meisterzug", {}).get("cost", 300))


func alt(zug_id: String) -> Dictionary:
	var a: String = active_alt.get(zug_id, "")
	for x in zug(zug_id).get("alts", []):
		if x.id == a:
			return x
	return {}


## Frame data [startup, active, recovery] with the active alternative applied.
func frames(zug_id: String) -> Array:
	var a := alt(zug_id)
	if a.has("frames"):
		return a.frames
	return zug(zug_id).get("frames", [10, 6, 20])


## Parameters of a Zug: Grundform, then the active alternative, then
## (when enhanced) the enhanced values: *_add adds, *_mul multiplies.
func params(zug_id: String, enhanced := false) -> Dictionary:
	var z := zug(zug_id)
	var p: Dictionary = z.get("params", {}).duplicate(true)
	p.merge(alt(zug_id).get("params", {}), true)
	if enhanced:
		for k: String in z.get("enhanced", {}):
			var v = z.enhanced[k]
			if k.ends_with("_add"):
				var key := k.trim_suffix("_add")
				p[key] = p.get(key, 0) + v
			elif k.ends_with("_mul"):
				var key := k.trim_suffix("_mul")
				p[key] = p.get(key, 0) * v
			else:
				p[k] = v
	return p


## Puts a Zug into a slot. A Zug sits in at most one slot, so it leaves
## its old one (which then holds whatever was in the new slot: a swap).
func assign(zug_id: String, dir: String) -> void:
	var old_dir := ""
	for d in DIRS:
		if loadout.get(d, "") == zug_id:
			old_dir = d
	var displaced: String = loadout.get(dir, "")
	loadout[dir] = zug_id
	if old_dir != "" and old_dir != dir:
		loadout[old_dir] = displaced
	save_choices()


func slot_of(zug_id: String) -> String:
	for d in DIRS:
		if loadout.get(d, "") == zug_id:
			return d
	return ""


func set_alt(zug_id: String, alt_id: String) -> void:
	active_alt[zug_id] = alt_id
	save_choices()


func set_variant(v: String) -> void:
	super_variant = v
	save_choices()


## Skill points: 1 per Zug, 2 per alternative, Meisterzug 4 incl. its first
## variant and 2 per further variant. In the training room everything is
## unlocked; the total shows what a fully mastered style costs.
func total_sp() -> int:
	var total := 0
	for z in zug_order:
		total += int(zug(z).get("sp", 1))
		for a in zug(z).get("alts", []):
			total += int(a.get("sp", 2))
	var mz: Dictionary = data.get("meisterzug", {})
	total += int(mz.get("sp", 4))
	for v in variants():
		total += int(v.get("sp", 0))
	return total


func _save_path() -> String:
	return "user://style_%s.json" % id


func save_choices() -> void:
	var f := FileAccess.open(_save_path(), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"loadout": loadout, "alts": active_alt, "super": super_variant}))


func _load_choices() -> void:
	if not FileAccess.file_exists(_save_path()):
		return
	var f := FileAccess.open(_save_path(), FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	for dir in d.get("loadout", {}):
		var z: String = d.loadout[dir]
		if dir in DIRS and (z == "" or zuege.has(z)):
			loadout[dir] = z
	for z in d.get("alts", {}):
		if zuege.has(z):
			active_alt[z] = d.alts[z]
	var sv: String = d.get("super", "")
	for v in variants():
		if v.id == sv:
			super_variant = sv
