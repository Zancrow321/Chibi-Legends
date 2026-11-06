class_name RaidLoot
extends RefCounted
## Raid loot rules from the endgame doc:
##  - farming is unlimited, but the chance for the bonus loot of a boss sinks
##    with every kill on the same day (back to full at midnight),
##  - every kill pays Raid-Marken anyway (bad-luck protection), traded at
##    Schmiedin Hino for a chosen piece with random stats (MarksShop).
## Offline it lives in user://raid_loot.json; with the online base the
## server keeps the same numbers.

const SAVE := "user://raid_loot.json"
## Bonus chance per kill today: 100 %, 60 %, 36 %, 22 %, then 20 %.
const DECAY := 0.6
const FLOOR := 0.2
## Raid-Marken per kill.
const MARKS := {"essenwaechter": 4, "turmwache": 1}
## Shop prices in Raid-Marken by rarity (Loot.EPIC 3, Loot.LEGENDARY 4).
const PRICE := {3: 20, 4: 60}

static var day := -1
static var kills := {}  # boss id -> kills today
static var _loaded := false


static func today() -> int:
	var t := Time.get_datetime_dict_from_system()
	return int(Time.get_unix_time_from_datetime_dict({"year": t.year, "month": t.month, "day": t.day}) / 86400)


static func _ensure() -> void:
	if not _loaded:
		_loaded = true
		var f := FileAccess.open(SAVE, FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				day = int(d.get("day", -1))
				kills = d.get("kills", {})
	if day != today():
		day = today()
		kills = {}


static func kills_today(boss: String) -> int:
	_ensure()
	return int(kills.get(boss, 0))


## Chance for the bonus loot of the next kill.
static func bonus_chance(boss: String) -> float:
	return maxf(FLOOR, pow(DECAY, float(kills_today(boss))))


## A boss went down: counts the kill, pays the marks and says whether the
## bonus loot drops. Returns {"bonus": bool, "chance": float, "marks": int}.
static func on_kill(boss: String) -> Dictionary:
	var chance := bonus_chance(boss)
	var bonus := randf() < chance
	kills[boss] = kills_today(boss) + 1
	var m := int(MARKS.get(boss, 1))
	Profile.add_marks(m)
	_save()
	return {"bonus": bonus, "chance": chance, "marks": m}


static func price(rarity: int) -> int:
	return int(PRICE.get(rarity, 999))


## Trades marks for a piece of the chosen kind; "" on success, else why not.
static func buy(kind: String, rarity: int, style_hint := "") -> String:
	Profile.ensure()
	if Profile.marks < price(rarity):
		return "Zu wenig Raid-Marken (%d nötig)" % price(rarity)
	if Profile.bag_full():
		return "Die Tasche ist voll"
	var item := Loot.roll(Profile.level, rarity, kind, style_hint)
	Profile.marks -= price(rarity)
	Profile.add_item(item)  # saves
	return ""


static func _save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"day": day, "kills": kills}))
