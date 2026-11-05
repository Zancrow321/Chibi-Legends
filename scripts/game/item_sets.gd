class_name ItemSets
extends RefCounted
## Item sets: four sets with one piece per item kind (Waffe, Oberteil,
## Hose, Schuhe, Accessoire, Talisman). Wearing 2, 4 and all 6 different
## pieces of a set turns on its bonuses (they stack). Set pieces drop as
## Episch with a fixed main stat and one socket; they only come from
## enemies, never from a shop.
##
## Bonus stats are the gear stats of Loot.STATS plus "cdr" (Abklingzeit:
## all Züge of the fighting style recharge faster, see FightingStyle.cooldown).

const COLOR := Color("1ebc73")
## Abklingzeit never drops by more than this.
const CDR_CAP := 0.3
## Share of epic drops that become a set piece.
const DROP_SHARE := 0.3

const SETS := {
	"waldwaechter": {
		"name": "Waldwächter",
		"color": Color("5ac54f"),
		"pieces": {"waffe": "Wächterast", "oberteil": "Wächtermoos", "hose": "Wächterborke",
			"schuhe": "Wächterwurzeln", "accessoire": "Wächterranke", "talisman": "Wächtereichel"},
		"bonus": {2: {"hp": 0.08}, 4: {"def": 0.04}, 6: {"cdr": 0.15, "hp": 0.1}},
		"text": {2: "+8 % Leben", 4: "+4 % Schadensminderung", 6: "Abklingzeiten −15 %, +10 % Leben"},
	},
	"glutschmied": {
		"name": "Glutschmied",
		"color": Color("fb6b1d"),
		"pieces": {"waffe": "Glutschmiedhammer", "oberteil": "Glutschmiedschurz", "hose": "Glutschmiedbeinlinge",
			"schuhe": "Glutschmiedstiefel", "accessoire": "Glutschmiedgurt", "talisman": "Glutschmiedfunke"},
		"bonus": {2: {"atk": 0.06}, 4: {"crit": 0.04}, 6: {"critdmg": 0.3, "atk": 0.06}},
		"text": {2: "+6 % Schaden", 4: "+4 % Krit-Chance", 6: "+30 % Krit-Schaden, +6 % Schaden"},
	},
	"sturmlaeufer": {
		"name": "Sturmläufer",
		"color": Color("8fd3ff"),
		"pieces": {"waffe": "Sturmläuferklinge", "oberteil": "Sturmläuferjacke", "hose": "Sturmläuferhose",
			"schuhe": "Sturmläufersohlen", "accessoire": "Sturmläuferschal", "talisman": "Sturmläuferfeder"},
		"bonus": {2: {"gauge": 0.1}, 4: {"cdr": 0.1}, 6: {"atk": 0.1, "gauge": 0.15}},
		"text": {2: "+10 % Leistenladung", 4: "Abklingzeiten −10 %", 6: "+10 % Schaden, +15 % Leistenladung"},
	},
	"mondschatten": {
		"name": "Mondschatten",
		"color": Color("a884f3"),
		"pieces": {"waffe": "Mondschattensichel", "oberteil": "Mondschattenmantel", "hose": "Mondschattenhose",
			"schuhe": "Mondschattenschritt", "accessoire": "Mondschattenschleier", "talisman": "Mondschattensplitter"},
		"bonus": {2: {"critdmg": 0.15}, 4: {"crit": 0.05}, 6: {"atk": 0.12, "critdmg": 0.15}},
		"text": {2: "+15 % Krit-Schaden", 4: "+5 % Krit-Chance", 6: "+12 % Schaden, +15 % Krit-Schaden"},
	},
}
const STEPS := [2, 4, 6]

static var _tex := {}


static func info(set_id: String) -> Dictionary:
	return SETS.get(set_id, {})


static func set_name(set_id: String) -> String:
	return str(info(set_id).get("name", set_id))


## Turns a freshly rolled item into a piece of a random set.
static func make_piece(it: Dictionary, set_id := "") -> void:
	if set_id == "":
		set_id = SETS.keys()[randi() % SETS.size()]
	it["set"] = set_id
	it["name"] = str(SETS[set_id].pieces.get(str(it.slot), it.name))


## How many different pieces of a set are worn (two talismans of the same
## set count once, a set has one talisman piece).
static func worn_count(set_id: String) -> int:
	var kinds := {}
	for s in Profile.SLOTS:
		var it := Profile.equipped_item(s)
		if not it.is_empty() and str(it.get("set", "")) == set_id:
			kinds[str(it.slot)] = true
	return kinds.size()


## Sum of all active set bonuses for a stat.
static func bonus(stat: String) -> float:
	var total := 0.0
	for id in SETS:
		var n := worn_count(id)
		for step in STEPS:
			if n >= step:
				total += float(SETS[id].bonus[step].get(stat, 0.0))
	return total


## Sets the player wears at least one piece of: [{id, name, count, steps:[{n, text, on}]}]
static func worn_sets() -> Array:
	var out: Array = []
	for id in SETS:
		var n := worn_count(id)
		if n == 0:
			continue
		var steps: Array = []
		for step in STEPS:
			steps.append({"n": step, "text": SETS[id].text[step], "on": n >= step})
		out.append({"id": id, "name": SETS[id].name, "count": n, "steps": steps})
	return out


## Abklingzeit-Faktor for all Züge (1.0 = normal).
static func cooldown_factor() -> float:
	return 1.0 - minf(CDR_CAP, bonus("cdr"))


## PixelLab icon assets/items/sets/<set>_<kind>.png (tools/items/gen_extra.py).
static func texture(set_id: String, kind: String) -> Texture2D:
	var key := "%s_%s" % [set_id, kind]
	if not _tex.has(key):
		var p := "res://assets/items/sets/%s.png" % key
		_tex[key] = load(p) if ResourceLoader.exists(p) else null
	return _tex[key]
