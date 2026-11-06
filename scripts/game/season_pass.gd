class_name SeasonPass
extends RefCounted
## Herausforderungen (daily / weekly) and the season pass. Static like
## Profile, saved in user://saison.json. Data: assets/pass/saison1.json.
##
## The game reports what happens with SeasonPass.track(event, value):
##   kill, elite, combo (value = combo length, "max" challenges), meisterzug,
##   wave, loot, loot_epic, reaction, gacha (pulls), level (levels gained).
## Every finished challenge gives Pass-EP and Sternkristalle when claimed.
## Pass-EP also come from kills and waves. 30 tiers à 1000 EP; the free track
## can be claimed, the premium track is shown but locked until the shop
## exists (real money needs Stripe and a legal check first).
## Daily challenges change at midnight, weekly ones on Monday.

const DATA_PATH := "res://assets/pass/saison1.json"
const SAVE := "user://saison.json"

static var data: Dictionary = {}
static var ep := 0
static var premium := false  # set only by the shop later (test: F9 in the pass screen)
static var claimed_free: Array = []
static var claimed_premium: Array = []
static var day := ""
static var week := ""
static var daily: Array = []  # [{id, progress, claimed}]
static var weekly: Array = []
static var fight_supers := 0  # Meisterzüge in the current fight (achievement "zwillinge")
static var _loaded := false


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			data = d
	var s := FileAccess.open(SAVE, FileAccess.READ)
	if s:
		var st: Variant = JSON.parse_string(s.get_as_text())
		if st is Dictionary and str(st.get("season", "")) == str(data.get("season", {}).get("id", "")):
			ep = int(st.get("ep", 0))
			premium = bool(st.get("premium", false))
			claimed_free = st.get("claimed_free", []).map(func(v): return int(v))
			claimed_premium = st.get("claimed_premium", []).map(func(v): return int(v))
			day = str(st.get("day", ""))
			week = str(st.get("week", ""))
			daily = st.get("daily", [])
			weekly = st.get("weekly", [])
	_refresh()


static func save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"season": data.get("season", {}).get("id", ""), "ep": ep, "premium": premium,
			"claimed_free": claimed_free, "claimed_premium": claimed_premium,
			"day": day, "week": week, "daily": daily, "weekly": weekly,
		}))


static func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


## Monday of this week as the week key.
static func _this_week() -> String:
	var unix := Time.get_unix_time_from_system()
	var wd := int(Time.get_date_dict_from_system().weekday)  # 0 = Sunday
	var back := (wd + 6) % 7
	var monday := Time.get_date_dict_from_unix_time(int(unix) - back * 86400)
	return "%04d-%02d-%02d" % [monday.year, monday.month, monday.day]


## New daily / weekly challenges when the day or week changed. The pick is
## seeded by the date, so it is the same set all day.
static func _refresh() -> void:
	var changed := false
	var t := _today()
	if day != t or daily.is_empty():
		day = t
		daily = _pick(data.get("daily", []), int(data.get("daily_count", 3)), t)
		changed = true
	var w := _this_week()
	if week != w or weekly.is_empty():
		week = w
		weekly = _pick(data.get("weekly", []), int(data.get("weekly_count", 4)), w)
		changed = true
	if changed:
		save()


static func _pick(pool: Array, n: int, seed_text: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	var ids: Array = pool.map(func(c): return str(c.id))
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	return ids.slice(0, n).map(func(id): return {"id": id, "progress": 0, "claimed": false})


static func def(id: String) -> Dictionary:
	for c in data.get("daily", []) + data.get("weekly", []):
		if str(c.id) == id:
			return c
	return {}


static func text(c: Dictionary) -> String:
	var d := def(str(c.id))
	return str(d.get("text", "%d")) % int(d.get("target", 1))


static func done(c: Dictionary) -> bool:
	return int(c.progress) >= int(def(str(c.id)).get("target", 1))


# --- events -----------------------------------------------------------------------

static func track(event: String, value := 1) -> void:
	ensure()
	_refresh()
	var any := false
	for list in [daily, weekly]:
		for c in list:
			var d := def(str(c.id))
			if str(d.get("event", "")) != event or c.claimed:
				continue
			var before := done(c)
			if str(d.get("mode", "count")) == "max":
				if value <= int(c.progress):
					continue
				c.progress = mini(value, int(d.get("target", 1)))
			else:
				c.progress = mini(int(c.progress) + value, int(d.get("target", 1)))
			any = true
			if done(c) and not before:
				_announce("Herausforderung geschafft: " + text(c))
	match event:
		"kill":
			add_ep(int(data.get("ep_per_kill", 10)) * value, false)
			any = true
		"wave":
			add_ep(int(data.get("ep_per_wave", 40)) * value, false)
			any = true
		"meisterzug":
			fight_supers += 1
			if fight_supers >= 3 and not CreatorUnlocks.is_unlocked("hair", "zwillinge"):
				CreatorUnlocks.unlock("hair", "zwillinge")
				_announce("Erfolg: 3 Meisterzüge in einem Kampf! Frisur „Zwillingszöpfe“ frei")
	if any:
		save()


## A new fight starts (training room built).
static func new_fight() -> void:
	fight_supers = 0


static func _announce(s: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.call_group("toaster", "toast", s)


static func claimable() -> int:
	ensure()
	var n := 0
	for list in [daily, weekly]:
		for c in list:
			if done(c) and not c.claimed:
				n += 1
	for t in range(1, tier() + 1):
		if not reward(t, false).is_empty() and not t in claimed_free:
			n += 1
	return n


## Claims one challenge: EP, crystals and its extra prize. Returns a short text.
static func claim(c: Dictionary) -> String:
	if not done(c) or c.claimed:
		return ""
	var d := def(str(c.id))
	c.claimed = true
	Gacha.add_crystals(int(d.get("crystals", 0)))
	var out := "+%d Pass-EP · +%d Sternkristalle" % [int(d.get("ep", 0)), int(d.get("crystals", 0))]
	if d.has("part"):
		var p: Array = d.part
		CreatorUnlocks.unlock(p[0], p[1])
		out += " · " + CreatorCatalog.item_name(p[0], p[1])
	add_ep(int(d.get("ep", 0)), false)
	save()
	return out


# --- pass ---------------------------------------------------------------------------

static func tiers() -> int:
	ensure()
	return int(data.get("season", {}).get("tiers", 30))


static func ep_per_tier() -> int:
	ensure()
	return int(data.get("season", {}).get("ep_per_tier", 1000))


static func tier() -> int:
	return mini(tiers(), ep / ep_per_tier())


static func tier_fraction() -> float:
	if tier() >= tiers():
		return 1.0
	return float(ep % ep_per_tier()) / float(ep_per_tier())


static func add_ep(n: int, write := true) -> void:
	ensure()
	var before := tier()
	ep = mini(ep + n, tiers() * ep_per_tier())
	if tier() > before:
		_announce("Saison-Pass Stufe %d erreicht!" % tier())
		Sfx.play("level_up", -4.0)
	if write:
		save()


static func reward(t: int, prem: bool) -> Dictionary:
	ensure()
	for r in data.get("premium" if prem else "free", []):
		if int(r.tier) == t:
			return r
	return {}


static func is_claimed(t: int, prem: bool) -> bool:
	return t in (claimed_premium if prem else claimed_free)


static func can_claim(t: int, prem: bool) -> bool:
	return t <= tier() and not reward(t, prem).is_empty() and not is_claimed(t, prem) and (premium or not prem)


## Gives a pass reward; returns the text for the toast ("" = nothing).
static func claim_tier(t: int, prem: bool) -> String:
	if not can_claim(t, prem):
		return ""
	var r := reward(t, prem)
	(claimed_premium if prem else claimed_free).append(t)
	var s := give(r)
	save()
	return s


static func give(r: Dictionary) -> String:
	match str(r.get("kind", "")):
		"crystals":
			Gacha.add_crystals(int(r.amount))
			return "+%d Sternkristalle" % int(r.amount)
		"splitter":
			Profile.add_splitter(int(r.amount))
			return "+%d Splitter" % int(r.amount)
		"gear":
			Profile.ensure()
			var it := Loot.roll(Profile.level, int(r.get("rarity", Loot.RARE)))
			if Profile.add_item(it):
				return "%s (%s)" % [it.name, Loot.rarity_info(it).name]
			var sp := int(round(Loot.salvage_value(it)))
			Profile.add_splitter(sp)
			return "Tasche voll: +%d Splitter" % sp
		"part":
			if str(r.slot) == "outfit":  # ganzes Outfit: Oberteil, Hose und Schuhe
				for slot in ["top", "pants", "shoes"]:
					CreatorUnlocks.unlock(slot, str(r.id))
				return "Neues Outfit im Creator: " + CreatorCatalog.item_name("top", str(r.id))
			CreatorUnlocks.unlock(str(r.slot), str(r.id))
			return "Neu im Creator: " + CreatorCatalog.item_name(str(r.slot), str(r.id))
		"skin":
			StyleSkin.unlock(str(r.style), str(r.id))
			return "Effekt-Skin %s für %s (Tab)" % [StyleSkin.skin_name(str(r.style), str(r.id)), Gacha.style_name(str(r.style))]
		"color":
			CreatorCatalog.ensure()
			for i in CreatorCatalog.data.get("colors", []).size():
				if not CreatorUnlocks.is_color_unlocked(i):
					CreatorUnlocks.unlock_color(i)
					return "Farbstoff " + str(CreatorCatalog.data["colors"][i]["name"])
			Profile.add_splitter(80)
			return "Alle Farben schon frei: +80 Splitter"
	return ""


## Short label for a reward cell.
static func label(r: Dictionary) -> String:
	match str(r.get("kind", "")):
		"crystals":
			return "%d Kristalle" % int(r.amount)
		"splitter":
			return "%d Splitter" % int(r.amount)
		"gear":
			return "%s Ausrüstung" % Loot.RARITIES[int(r.get("rarity", Loot.RARE))].name
		"part":
			if str(r.slot) == "outfit":
				return "Outfit " + CreatorCatalog.item_name("top", str(r.id))
			return CreatorCatalog.item_name(str(r.slot), str(r.id))
		"color":
			return "Farbstoff"
		"skin":
			return "Skin " + StyleSkin.skin_name(str(r.style), str(r.id))
	return ""
