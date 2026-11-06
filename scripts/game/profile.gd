class_name Profile
extends RefCounted
## The player's progress that outlives a fight: level and EXP, Splitter
## (currency), the bag with all found gear and what is equipped. Static, so
## the overworld and the combat areas share it across scene reloads.
## Saved in user://profil.json after every change.
##
## Gear is account-wide (see the gameloop doc): one bag, seven places:
## Waffe, Oberteil, Hose, Schuhe, Accessoire and two Talismane. An item's
## "slot" is its kind; both talisman places take a talisman.

const SAVE := "user://profil.json"
## Equipment places (keys of `equipped`).
const SLOTS := ["waffe", "oberteil", "hose", "schuhe", "accessoire", "talisman", "talisman2"]
const SLOT_NAMES := {"waffe": "Waffe", "oberteil": "Oberteil", "hose": "Hose", "schuhe": "Schuhe",
	"accessoire": "Accessoire", "talisman": "Talisman", "talisman2": "Talisman 2", "ruestung": "Oberteil"}
## Item kinds that drop.
const KINDS := ["waffe", "oberteil", "hose", "schuhe", "accessoire", "talisman"]
const BAG_SIZE := 30
## Per level: +3 % HP and +2 % damage, so a level feels like a step.
const LEVEL_HP := 0.03
const LEVEL_ATK := 0.02

static var level := 1
static var xp := 0.0
static var splitter := 0
## Raid-Marken: from raid bosses and tower guards, traded at Hino for a chosen piece.
static var marks := 0
static var items: Array = []  # Dictionaries from Loot.roll()
static var equipped := {}  # place -> item uid, see SLOTS
static var _next_uid := 1
static var _loaded := false


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	for s in SLOTS:
		equipped[s] = ""
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return
	level = int(d.get("level", 1))
	xp = float(d.get("exp", 0.0))
	splitter = int(d.get("splitter", 0))
	marks = int(d.get("marks", 0))
	items = d.get("items", [])
	var eq: Dictionary = d.get("equipped", {})
	if eq.has("ruestung") and not eq.has("oberteil"):
		eq["oberteil"] = eq["ruestung"]  # old saves: the armour becomes the top
	for it in items:
		if str(it.get("slot", "")) == "ruestung":
			it["slot"] = "oberteil"
	if int(d.get("rarity_version", 1)) < Loot.RARITY_VERSION:
		for it in items:  # 4 rarities -> 6 (Ungewöhnlich and Mythisch added)
			it["rarity"] = Loot.migrate_rarity(int(it.get("rarity", 0)))
	for s in SLOTS:
		equipped[s] = str(eq.get(s, ""))
	_next_uid = int(d.get("next_uid", items.size() + 1))


static func save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"level": level, "exp": xp, "splitter": splitter, "marks": marks, "items": items, "equipped": equipped, "next_uid": _next_uid, "rarity_version": Loot.RARITY_VERSION}))


## EXP for the next level: grows a little each level.
static func exp_needed(lv: int = level) -> float:
	return 300.0 + (lv - 1) * 120.0


static func exp_fraction() -> float:
	ensure()
	return clampf(xp / exp_needed(), 0.0, 1.0)


## Adds EXP; returns how many levels were gained.
static func add_exp(amount: float) -> int:
	ensure()
	xp += amount
	var ups := 0
	while xp >= exp_needed():
		xp -= exp_needed()
		level += 1
		ups += 1
	save()
	if ups > 0:
		Gacha.on_level_up(ups)
		SeasonPass.track("level", ups)
	return ups


static func add_splitter(n: int) -> void:
	ensure()
	splitter += n
	save()


static func add_marks(n: int) -> void:
	ensure()
	marks += n
	save()


static func bag_full() -> bool:
	ensure()
	return items.size() >= BAG_SIZE


## Puts an item into the bag; false when the bag is full.
static func add_item(item: Dictionary) -> bool:
	ensure()
	if bag_full():
		return false
	item["uid"] = "i%d" % _next_uid
	_next_uid += 1
	items.append(item)
	save()
	if item.has("raid"):
		RaidArmor.on_obtained(item)  # unlocks the look in the Character Creator
	return true


static func item(uid: String) -> Dictionary:
	ensure()
	for it in items:
		if it.uid == uid:
			return it
	return {}


static func equipped_item(slot: String) -> Dictionary:
	ensure()
	return item(equipped.get(slot, "")) if equipped.get(slot, "") != "" else {}


## The place an item goes to: talismans fill the first free talisman place
## (or replace the first one).
static func place_for(it: Dictionary) -> String:
	var kind := str(it.get("slot", "waffe"))
	if kind == "talisman":
		if equipped.get("talisman", "") != "" and equipped.get("talisman2", "") == "":
			return "talisman2"
	return kind


## Where a worn item sits ("" = not worn).
static func place_of(uid: String) -> String:
	for s in SLOTS:
		if equipped.get(s, "") == uid:
			return s
	return ""


static func is_equipped(uid: String) -> bool:
	ensure()
	return uid in equipped.values()


## Equips an item in its slot (the old one goes back to the bag); equipping
## the item that is already worn takes it off.
static func toggle_equip(uid: String) -> void:
	var it := item(uid)
	if it.is_empty():
		return
	var worn := place_of(uid)
	if worn != "":
		equipped[worn] = ""
	else:
		equipped[place_for(it)] = uid
	save()


## Umschmieden one affix of an item for Splitter. Returns the new stat id
## ("" = not enough Splitter or nothing to reroll).
static func reforge(uid: String, stat: String) -> String:
	var it := item(uid)
	if it.is_empty():
		return ""
	var cost := Loot.reforge_cost(it)
	if splitter < cost:
		return ""
	var s := Loot.reforge(it, stat)
	if s != "":
		splitter -= cost
		save()
	return s


## Breaks an item into Splitter (never one that is worn).
static func salvage(uid: String) -> int:
	var it := item(uid)
	if it.is_empty() or is_equipped(uid):
		return 0
	var gain := int(Loot.salvage_value(it))
	for g in it.get("sockets", []):  # gems go back into the pouch
		if str(g) != "":
			Gems.add(str(g))
	items.erase(it)
	splitter += gain
	save()
	return gain


## Sets a gem from the pouch into the item's first free socket.
## Returns false when there is no free socket or no such gem.
static func socket_gem(uid: String, gem: String) -> bool:
	var it := item(uid)
	var i := Loot.free_socket(it)
	if it.is_empty() or i < 0 or not Gems.take(gem):
		return false
	it.sockets[i] = gem
	save()
	return true


## Takes the gem of a socket back into the pouch for Splitter (Hino).
static func unsocket_gem(uid: String, i: int) -> bool:
	var it := item(uid)
	var sockets: Array = it.get("sockets", [])
	if i < 0 or i >= sockets.size() or str(sockets[i]) == "":
		return false
	var cost := Gems.unsocket_cost(str(sockets[i]))
	if splitter < cost:
		return false
	splitter -= cost
	Gems.add(str(sockets[i]))
	sockets[i] = ""
	save()
	return true


## Fuses 3 gems into one of the next tier for Splitter (Hino).
static func fuse_gem(gem: String) -> String:
	var cost := Gems.fuse_cost(gem)
	if splitter < cost or not Gems.can_fuse(gem):
		return ""
	var up := Gems.fuse(gem)
	splitter -= cost
	save()
	return up


## Sum of a stat over level, worn gear, socketed gems and set bonuses, as a
## fraction (0.12 = +12 %). Stats: atk, hp, crit, gauge, critdmg, def, cdr.
static func bonus(stat: String) -> float:
	ensure()
	var total := 0.0
	match stat:
		"hp":
			total += (level - 1) * LEVEL_HP
		"atk":
			total += (level - 1) * LEVEL_ATK
	for s in SLOTS:
		var it := equipped_item(s)
		if not it.is_empty():
			total += float(it.stats.get(stat, 0.0)) + Loot.gem_bonus(it, stat)
	return total + ItemSets.bonus(stat)


## Gear score: one number for the strength of what you wear.
static func gear_score() -> int:
	ensure()
	var total := 0.0
	for s in SLOTS:
		var it := equipped_item(s)
		if not it.is_empty():
			total += Loot.score(it)
	return int(total)


## Test hook / fresh start.
static func reset() -> void:
	level = 1
	xp = 0.0
	splitter = 0
	marks = 0
	items = []
	equipped = {}
	for s in SLOTS:
		equipped[s] = ""
	_next_uid = 1
	_loaded = true
	save()
