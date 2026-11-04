class_name Loot
extends RefCounted
## Gear drops with randomized stats. Each item has a slot (Waffe, Rüstung,
## Talisman), a rarity and 1-4 stat rolls; the rarity sets how many rolls and
## how strong. Legendary items also carry a short flavour line. Enemies drop
## them in the training forest (see Enemy._die / LootDrop).

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
}

## Which stat each slot always rolls first.
const MAIN_STAT := {"waffe": "atk", "ruestung": "hp", "talisman": "gauge"}

const NAMES := {
	"waffe": ["Übungsklinge", "Rindenschwert", "Moosbrecher", "Glutzahn", "Dornensäbel", "Zweihänder der Lichtung"],
	"ruestung": ["Schülerjacke", "Borkenweste", "Moospanzer", "Glutmantel", "Wurzelharnisch", "Laubrüstung"],
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
		slot = Profile.SLOTS[randi() % Profile.SLOTS.size()]
	var rar: Dictionary = RARITIES[rarity]
	var lv_mult := 1.0 + (item_level - 1) * 0.08
	var stats := {}
	var pool: Array = STATS.keys()
	pool.erase(MAIN_STAT[slot])
	pool.shuffle()
	var order: Array = [MAIN_STAT[slot]] + pool
	for i in mini(int(rar.rolls), order.size()):
		var s: String = order[i]
		var v: float = randf_range(STATS[s].min, STATS[s].max) * float(rar.power) * lv_mult
		stats[s] = snappedf(v, 0.001)
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
