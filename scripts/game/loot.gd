class_name Loot
extends RefCounted
## Gear drops with randomized stats. Each item has a kind ("slot": Waffe,
## Oberteil, Hose, Schuhe, Accessoire, Talisman), a rarity and 1-4 stat rolls
## (affixes); the rarity sets how many rolls and how strong. The kind always
## rolls its main stat first. Legendary items also carry a short flavour line.
## Umschmieden (reforge, at Schmiedin Hino) rerolls one affix for Splitter.
## Enemies drop gear in the training forest (see Enemy._die / LootDrop).

const RARITIES := [
	{"id": "gewoehnlich", "name": "Gewöhnlich", "color": Color("c7cfcc"), "rolls": 1, "power": 1.0},
	{"id": "selten", "name": "Selten", "color": Color("4d9be6"), "rolls": 2, "power": 1.25},
	{"id": "episch", "name": "Episch", "color": Color("a884f3"), "rolls": 3, "power": 1.55},
	{"id": "legendaer", "name": "Legendär", "color": Color("f9c22b"), "rolls": 4, "power": 2.0},
]

## Stats: what a roll adds (fraction), base range at item level 1.
const STATS := {
	"atk": {"name": "Schaden", "min": 0.03, "max": 0.07},
	"hp": {"name": "Leben", "min": 0.04, "max": 0.09},
	"crit": {"name": "Krit-Chance", "min": 0.02, "max": 0.05},
	"gauge": {"name": "Leistenladung", "min": 0.04, "max": 0.10},
	"critdmg": {"name": "Krit-Schaden", "min": 0.05, "max": 0.12},
	"def": {"name": "Schadensminderung", "min": 0.01, "max": 0.025},
}
## Defence never goes above this, however much gear stacks.
const DEF_CAP := 0.5

## Which stat each kind always rolls first.
const MAIN_STAT := {"waffe": "atk", "oberteil": "hp", "hose": "def", "schuhe": "gauge", "accessoire": "crit", "talisman": "critdmg"}

const NAMES := {
	"waffe": ["Übungsklinge", "Rindenschwert", "Moosbrecher", "Glutzahn", "Dornensäbel", "Zweihänder der Lichtung"],
	"oberteil": ["Schülerjacke", "Borkenweste", "Moospanzer", "Glutmantel", "Wurzelharnisch", "Laubrüstung"],
	"hose": ["Trainingshose", "Rindenbeinlinge", "Moosgamaschen", "Glutschienen", "Wurzelhose", "Laufhose der Lichtung"],
	"schuhe": ["Sandalen", "Borkenstiefel", "Moosläufer", "Glutsohlen", "Dornenschritt", "Windtreter"],
	"accessoire": ["Stirnband", "Rindenreif", "Moosschal", "Glutgürtel", "Dornenkette", "Laubbrosche"],
	"talisman": ["Holzamulett", "Glutperle", "Mooskristall", "Sumpfauge", "Tigerzahn", "Igelfeder"],
}
const LEGEND_LINES := [
	"Summt leise, wenn ein Elite in der Nähe ist.",
	"Wer es trägt, hört den Wald atmen.",
	"Wurde nie geschmiedet, nur gefunden.",
	"Die Glut darin erlischt nicht.",
]


## Rarity index by luck: elites roll much better.
static func roll_rarity(elite := false) -> int:
	var r := randf()
	if elite:
		return 3 if r < 0.18 else (2 if r < 0.6 else 1)
	return 3 if r < 0.01 else (2 if r < 0.07 else (1 if r < 0.3 else 0))


static func roll(item_level: int, rarity: int = -1, slot := "") -> Dictionary:
	if rarity < 0:
		rarity = roll_rarity()
	if slot == "":
		slot = Profile.KINDS[randi() % Profile.KINDS.size()]
	var rar: Dictionary = RARITIES[rarity]
	var stats := {}
	var pool: Array = STATS.keys()
	pool.erase(MAIN_STAT[slot])
	pool.shuffle()
	var order: Array = [MAIN_STAT[slot]] + pool
	for i in mini(int(rar.rolls), order.size()):
		var s: String = order[i]
		stats[s] = roll_value(s, rarity, item_level)
	var names: Array = NAMES[slot]
	var it := {
		"name": names[randi() % names.size()],
		"slot": slot,
		"rarity": rarity,
		"ilvl": item_level,
		"stats": stats,
		"icon": randi() % 3,  # small variation of the drawn icon
	}
	if rarity == 3:
		it["line"] = LEGEND_LINES[randi() % LEGEND_LINES.size()]
	return it


static func roll_value(stat: String, rarity: int, item_level: int) -> float:
	var lv_mult := 1.0 + (item_level - 1) * 0.08
	var v: float = randf_range(STATS[stat].min, STATS[stat].max) * float(RARITIES[rarity].power) * lv_mult
	return snappedf(v, 0.001)


## Umschmieden: Splitter cost for the next reforge of this item.
static func reforge_cost(it: Dictionary) -> int:
	return int(20.0 * pow(2.0, float(it.get("rarity", 0))) * (1 + int(it.get("reforged", 0))) + float(it.get("ilvl", 1)))


## Rerolls one affix (never the main stat): it may become another stat the
## item doesn't have yet. Returns the new stat id, "" when nothing to reroll.
static func reforge(it: Dictionary, stat: String) -> String:
	var main: String = MAIN_STAT.get(str(it.slot), "")
	var stats: Dictionary = it.get("stats", {})
	if stat == main or not stats.has(stat):
		return ""
	var pool: Array = STATS.keys().filter(func(s): return s == stat or not stats.has(s))
	pool.erase(main)
	var new_stat: String = pool[randi() % pool.size()]
	var kept := {}
	for s in stats:  # keep the order, swap in place
		if s == stat:
			kept[new_stat] = roll_value(new_stat, int(it.get("rarity", 0)), int(it.get("ilvl", 1)))
		else:
			kept[s] = stats[s]
	it["stats"] = kept
	it["reforged"] = int(it.get("reforged", 0)) + 1
	return new_stat


static func rarity_info(it: Dictionary) -> Dictionary:
	return RARITIES[clampi(int(it.get("rarity", 0)), 0, RARITIES.size() - 1)]


static func color(it: Dictionary) -> Color:
	return rarity_info(it).color


static func score(it: Dictionary) -> float:
	var total := 0.0
	for s in it.get("stats", {}):
		total += float(it.stats[s]) * 1000.0
	return total


static func salvage_value(it: Dictionary) -> float:
	return 5.0 * pow(3.0, float(it.get("rarity", 0))) + float(it.get("ilvl", 1))


## "+5,2 % Schaden"
static func stat_line(stat: String, v: float) -> String:
	return ("+%.1f %% " % (v * 100.0)).replace(".", ",") + str(STATS[stat].name)
