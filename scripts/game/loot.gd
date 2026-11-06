class_name Loot
extends RefCounted
## Gear drops with randomized stats. Each item has a kind ("slot": Waffe,
## Oberteil, Hose, Schuhe, Accessoire, Talisman), a rarity and 1-5 stat rolls
## (affixes); the rarity sets how many rolls and how strong. The kind always
## rolls its main stat first. Legendary items also carry a short flavour line.
## Umschmieden (reforge, at Schmiedin Hino) rerolls one affix for Splitter.
## Enemies drop gear in the training forest (see Enemy._die / LootDrop).
##
## On top of the affixes:
##  - Sockel: 0-2 by rarity, filled with Edelsteine (Gems), "sockets" holds
##    a gem id per socket ("" = free).
##  - Sets: part of the epic drops are set pieces ("set", see ItemSets).
##  - Legendäre Mods: every legendary changes one Zug of a fighting style
##    ("mod", see ItemMods).

## Six rarities (since the Essenwacht raid armour). Saves before that had
## four (0 Gewöhnlich, 1 Selten, 2 Episch, 3 Legendär); Profile moves them
## up with migrate_rarity(). Always use the named constants below.
const RARITIES := [
	{"id": "gewoehnlich", "name": "Gewöhnlich", "color": Color("c7cfcc"), "rolls": 1, "power": 1.0},
	{"id": "ungewoehnlich", "name": "Ungewöhnlich", "color": Color("1ebc73"), "rolls": 2, "power": 1.1},
	{"id": "selten", "name": "Selten", "color": Color("4d9be6"), "rolls": 2, "power": 1.25},
	{"id": "episch", "name": "Episch", "color": Color("a884f3"), "rolls": 3, "power": 1.55},
	{"id": "legendaer", "name": "Legendär", "color": Color("f9c22b"), "rolls": 4, "power": 2.0},
	{"id": "mythisch", "name": "Mythisch", "color": Color("e83b3b"), "rolls": 5, "power": 2.5},
]
const COMMON := 0
const UNCOMMON := 1
const RARE := 2
const EPIC := 3
const LEGENDARY := 4
const MYTHIC := 5
## Save format of the rarity indices (Profile "rarity_version").
const RARITY_VERSION := 2

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
## Aufwerten (upgrade): every step adds PLUS_STEP of all affixes; the cap
## grows with the rarity. Stored as "plus" on the item (0 = none).
const MAX_PLUS := [3, 4, 5, 6, 8, 10]
const PLUS_STEP := 0.06
## Sammel-Zerlegen breaks everything up to this rarity (not worn, not locked).
const BULK_MAX := RARE

## Sockets per rarity: [min, max].
const SOCKETS := [[0, 0], [0, 0], [0, 1], [1, 1], [1, 2], [2, 2]]

const MYTHIC_LINES := [
	"Ein Stern ist hineingefallen und brennt noch.",
	"Die Esse selbst hat es sich ausgesucht.",
	"Es glüht im Takt deines Herzens.",
]
const LEGEND_LINES := [
	"Summt leise, wenn ein Elite in der Nähe ist.",
	"Wer es trägt, hört den Wald atmen.",
	"Wurde nie geschmiedet, nur gefunden.",
	"Die Glut darin erlischt nicht.",
]


## Rarity index by luck: elites roll much better.
## Normal: 0,1 % Mythisch, 1 % Legendär, 6 % Episch, 18 % Selten, 30 % Ungewöhnlich.
## Elite: 1,5 % Mythisch, 16,5 % Legendär, 42 % Episch, 30 % Selten, 10 % Ungewöhnlich.
static func roll_rarity(elite := false) -> int:
	var table: Array = ELITE_TABLE if elite else DROP_TABLE
	return pick_rarity(table)


const DROP_TABLE := [0.001, 0.01, 0.06, 0.18, 0.30]  # Mythisch .. Ungewöhnlich
const ELITE_TABLE := [0.015, 0.165, 0.42, 0.30, 0.10]
## Raid armour (Essenwacht) from the raid boss: every rarity can drop.
const RAID_TABLE := [0.02, 0.07, 0.16, 0.25, 0.27]


static func pick_rarity(table: Array) -> int:
	var r := randf()
	var acc := 0.0
	for i in table.size():
		acc += float(table[i])
		if r < acc:
			return MYTHIC - i
	return COMMON


## Old saves (4 rarities) -> 6 rarities: Selten 1->2, Episch 2->3, Legendär 3->4.
static func migrate_rarity(old: int) -> int:
	return old + 1 if old >= 1 else old


## style_hint: the fighting style in use; legendary mods favour it.
static func roll(item_level: int, rarity: int = -1, slot := "", style_hint := "") -> Dictionary:
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
	var sk: Array = SOCKETS[rarity]
	var n := randi_range(int(sk[0]), int(sk[1]))
	if rarity == EPIC and randf() < ItemSets.DROP_SHARE:
		ItemSets.make_piece(it)
	if n > 0:
		var sockets: Array = []
		sockets.resize(n)
		sockets.fill("")
		it["sockets"] = sockets
	if rarity >= LEGENDARY:
		var lines: Array = MYTHIC_LINES if rarity == MYTHIC else LEGEND_LINES
		it["line"] = lines[randi() % lines.size()]
		it["mod"] = ItemMods.roll(style_hint if style_hint != "" else ItemMods.current_style())
	return it


## What the gems in an item's sockets add to a stat.
static func gem_bonus(it: Dictionary, stat: String) -> float:
	var total := 0.0
	for g in it.get("sockets", []):
		if str(g) != "" and Gems.stat_of(str(g)) == stat:
			total += Gems.value(str(g))
	return total


static func free_socket(it: Dictionary) -> int:
	var sockets: Array = it.get("sockets", [])
	for i in sockets.size():
		if str(sockets[i]) == "":
			return i
	return -1


static func roll_value(stat: String, rarity: int, item_level: int) -> float:
	var lv_mult := 1.0 + (item_level - 1) * 0.08
	var v: float = randf_range(STATS[stat].min, STATS[stat].max) * float(RARITIES[rarity].power) * lv_mult
	return snappedf(v, 0.001)


## Umschmieden: Splitter cost for the next reforge of this item.
static func reforge_cost(it: Dictionary) -> int:
	return int(20.0 * pow(1.75, float(it.get("rarity", 0))) * (1 + int(it.get("reforged", 0))) + float(it.get("ilvl", 1)))


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


## An affix with the upgrade steps applied (what really counts).
static func affix(it: Dictionary, s: String) -> float:
	return float(it.get("stats", {}).get(s, 0.0)) * plus_mult(it)


static func plus_mult(it: Dictionary) -> float:
	return 1.0 + PLUS_STEP * int(it.get("plus", 0))


static func max_plus(it: Dictionary) -> int:
	return int(MAX_PLUS[clampi(int(it.get("rarity", 0)), 0, MYTHIC)])


static func can_upgrade(it: Dictionary) -> bool:
	return int(it.get("plus", 0)) < max_plus(it)


## Splitter for the next upgrade step; grows with rarity and step.
static func upgrade_cost(it: Dictionary) -> int:
	var p := int(it.get("plus", 0))
	return int(12.0 * pow(1.6, float(it.get("rarity", 0))) * (1.0 + p * 0.75) + float(it.get("ilvl", 1)) * 0.5)


## "Glutzahn +3"
static func display_name(it: Dictionary) -> String:
	var p := int(it.get("plus", 0))
	return str(it.get("name", "")) + (" +%d" % p if p > 0 else "")


static func score(it: Dictionary) -> float:
	var total := 0.0
	for s in it.get("stats", {}):
		total += affix(it, s) * 1000.0
	for g in it.get("sockets", []):
		if str(g) != "":
			total += Gems.value(str(g)) * 1000.0
	if it.has("mod"):
		total += 40.0
	return total


## Upgrades give back half of what they cost.
static func salvage_value(it: Dictionary) -> float:
	var back := 0.0
	var probe := {"rarity": it.get("rarity", 0), "ilvl": it.get("ilvl", 1)}
	for p in int(it.get("plus", 0)):
		probe["plus"] = p
		back += upgrade_cost(probe) * 0.5
	return 5.0 * pow(2.4, float(it.get("rarity", 0))) + float(it.get("ilvl", 1)) + back


## "+5,2 % Schaden"
static func stat_line(stat: String, v: float) -> String:
	return ("+%.1f %% " % (v * 100.0)).replace(".", ",") + str(STATS[stat].name)
