class_name RaidArmor
extends RefCounted
## Raid-Rüstung "Essenwacht" (Glutschmiede, Boss Essenwächter): Oberteil,
## Hose und Schuhe in allen sechs Seltenheiten. Stats würfelt Loot.roll wie
## bei jedem Teil; die Rüstung bringt dazu ihren eigenen Look:
##  - Icon: assets/items/raid/essenwacht_<slot>_<seltenheit>.png (PixelLab),
##  - Character Creator: das erste Teil einer Seltenheit schaltet das passende
##    Outfit-Teil frei (top/pants/shoes "raid_<seltenheit>"), das Oberteil
##    zusätzlich den Helm (Frisur-Slot "raid_<seltenheit>"),
##  - im Spiel: ab Episch glüht die Rüstung (Bloom), Mythisch ist animiert
##    (LayeredBody, siehe glow_level()).
## Bauplan und Bilder: docs/raid-ruestung.md, tools/raid_armor/.

const ID := "essenwacht"
const PIECES := ["oberteil", "hose", "schuhe"]
## Loot-Slot -> Creator-Slot
const PART_SLOT := {"oberteil": "top", "hose": "pants", "schuhe": "shoes"}
const PIECE_NAMES := {"oberteil": "Harnisch", "hose": "Beinschienen", "schuhe": "Stiefel"}
## Titel je Seltenheit (Loot.RARITIES-Reihenfolge)
const TITLES := ["Rekruten", "Postens", "Hüters", "Glutritters", "Schmiedekönigs", "Sternenglut"]
const SET_NAMES := ["Essenwacht-Rekrut", "Essenwacht-Posten", "Essenwacht-Hüter",
	"Essenwacht-Glutritter", "Essenwacht-Schmiedekönig", "Essenwacht-Sternenglut"]
## Leuchtfarbe der Glut-Adern ab Episch (für Glow und Funken).
const GLOW := ["", "", "", "b45cff", "ffa214", "ff3b6b"]

static var _tex := {}


## A raid armour piece from the raid boss; rarity from Loot.RAID_TABLE.
static func roll(item_level: int, style_hint := "", rarity := -1, slot := "") -> Dictionary:
	if rarity < 0:
		rarity = Loot.pick_rarity(Loot.RAID_TABLE)
	if slot == "":
		slot = PIECES[randi() % PIECES.size()]
	var it := Loot.roll(item_level, rarity, slot, style_hint)
	make_piece(it)
	return it


static func make_piece(it: Dictionary) -> void:
	it.erase("set")  # its own line, not one of the item sets
	it["raid"] = ID
	var r := clampi(int(it.get("rarity", 0)), 0, TITLES.size() - 1)
	var title: String = TITLES[r]
	if r == Loot.MYTHIC:
		it["name"] = "%s der Sternenglut" % PIECE_NAMES[it.slot]
	else:
		it["name"] = "%s des %s" % [PIECE_NAMES[it.slot], title]


static func rarity_id(r: int) -> String:
	return str(Loot.RARITIES[clampi(r, 0, Loot.RARITIES.size() - 1)].id)


## Creator part id of a rarity ("raid_episch").
static func part_id(r: int) -> String:
	return "raid_" + rarity_id(r)


static func texture(slot: String, r: int) -> Texture2D:
	var key := "%s_%d" % [slot, r]
	if not _tex.has(key):
		var p := "res://assets/items/raid/%s_%s_%s.png" % [ID, slot, rarity_id(r)]
		_tex[key] = load(p) if ResourceLoader.exists(p) else null
	return _tex[key]


## A piece reached the bag: unlock its look in the Character Creator.
static func on_obtained(it: Dictionary) -> void:
	var slot := str(it.get("slot", ""))
	if not PART_SLOT.has(slot):
		return
	var pid := part_id(int(it.get("rarity", 0)))
	CreatorUnlocks.unlock(PART_SLOT[slot], pid)
	if slot == "oberteil":
		CreatorUnlocks.unlock("hair", pid)


## Rarity of a creator part id, -1 when it is no raid armour part.
static func part_rarity(id: String) -> int:
	if not id.begins_with("raid_"):
		return -1
	var rid := id.substr(5)
	for i in Loot.RARITIES.size():
		if Loot.RARITIES[i].id == rid:
			return i
	return -1


## How much a look shines: the best raid part worn (top/pants/shoes/hair).
## < Loot.EPIC: no glow; EPIC/LEGENDARY: pulsing glow; MYTHIC: animated.
static func glow_level(look: Dictionary) -> int:
	var best := -1
	for s in ["top", "pants", "shoes", "hair"]:
		best = maxi(best, part_rarity(str(look.get(s, ""))))
	return best


static func glow_color(r: int) -> Color:
	return Color(GLOW[r]) if r >= Loot.EPIC else Color.WHITE
