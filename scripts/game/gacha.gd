class_name Gacha
extends RefCounted
## Sternschrein: the gacha for fighting styles. Static like Profile, so the
## courtyard and the combat areas share it. Saved in user://sternschrein.json.
##
## Rules (assets/gacha/banners.json, all shown openly in the shrine):
##   - every banner features one fighting style (all styles are Legendär,
##     more choice and spectacle, never higher numbers than Episch gear)
##   - Legendär 3 %, Episch 15 %, Selten 82 %
##   - pity: the 60th pull without a Legendär is always Legendär (the counter
##     is shared by all banners and shown in the shrine)
##   - a Legendär is the banner's style with 50 %; if it was another style,
##     the next Legendär is the banner's style for sure
##   - a 10-pull always holds at least one Episch
##   - duplicates of a style give a star (1-6, cosmetic only) and Splitter
##   - Episch: the banner's outfit / weapon parts (catalog.json unlock hints
##     that name the banner title), a locked dye, or Episch gear
##   - Selten: Splitter, Selten gear or a dye
## Sternkristalle: start gift, a daily gift in the shrine, every level up.
## Not tradeable (see the gameloop doc).

const DATA_PATH := "res://assets/gacha/banners.json"
const SAVE := "user://sternschrein.json"
const RARITY_IDS := ["selten", "episch", "legendaer"]
const RARITY_NAMES := ["Selten", "Episch", "Legendär"]
const RARITY_COLORS := [Color("4d9be6"), Color("a884f3"), Color("f9c22b")]

static var data: Dictionary = {}
static var crystals := 0
static var pity := 0  # pulls since the last Legendär
static var guaranteed := false  # lost the 50/50: next Legendär is the banner's style
static var owned: Dictionary = {}  # style id -> stars (1 = owned)
static var last_daily := ""
static var pulls_total := 0
static var history: Array = []  # newest first, short entries for the shrine log
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
	if s == null:
		_first_start()
		return
	var st: Variant = JSON.parse_string(s.get_as_text())
	if not st is Dictionary:
		_first_start()
		return
	crystals = int(st.get("crystals", 0))
	pity = int(st.get("pity", 0))
	guaranteed = bool(st.get("guaranteed", false))
	last_daily = str(st.get("last_daily", ""))
	pulls_total = int(st.get("pulls_total", 0))
	history = st.get("history", [])
	owned = {}
	var o: Dictionary = st.get("owned", {})
	for k in o:
		owned[str(k)] = int(o[k])
	for sid in data.get("starter_styles", ["glutatem"]):
		if not owned.has(sid):
			owned[sid] = 1


## First start: the starter style, the style you already wear (older saves
## keep what they had) and the start gift for one 10-pull.
static func _first_start() -> void:
	owned = {}
	for sid in data.get("starter_styles", ["glutatem"]):
		owned[str(sid)] = 1
	if FileAccess.file_exists(CreatorCatalog.SAVE):
		var cur := str(CreatorCatalog.load_look().get("style", ""))
		if cur != "":
			owned[cur] = 1
	crystals = int(data.get("start_gift", 1000))
	save()


static func save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"crystals": crystals, "pity": pity, "guaranteed": guaranteed, "owned": owned,
			"last_daily": last_daily, "pulls_total": pulls_total, "history": history.slice(0, 40),
		}))


# --- queries ------------------------------------------------------------------------

static func banners() -> Array:
	ensure()
	return data.get("banners", [])


static func cost(n: int) -> int:
	ensure()
	return int(data.get("cost_ten", 1000)) if n >= 10 else int(data.get("cost_one", 100)) * n


static func pity_max() -> int:
	ensure()
	return int(data.get("pity", 60))


static func rate(rarity: int) -> float:
	ensure()
	return float(data.get("rates", {}).get(RARITY_IDS[rarity], 0.0))


static func owns_style(style_id: String) -> bool:
	ensure()
	return owned.has(style_id)


static func stars(style_id: String) -> int:
	ensure()
	return int(owned.get(style_id, 0))


static func style_info(style_id: String) -> Dictionary:
	CreatorCatalog.ensure()
	return CreatorCatalog.data.get("styles", {}).get(style_id, {})


static func style_name(style_id: String) -> String:
	return str(style_info(style_id).get("name", style_id.capitalize()))


## "Sternschrein: Banner „Die letzte Linie“" for a locked style.
static func style_hint(style_id: String) -> String:
	for b in banners():
		if str(b.style) == style_id:
			return "Sternschrein im Akademie-Hof, Banner „%s“" % b.title
	return "Sternschrein im Akademie-Hof"


static func style_colors(style_id: String) -> Dictionary:
	var f := FileAccess.open("res://assets/combat/styles/%s.json" % style_id, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d.get("colors", {}) if d is Dictionary else {}


static func daily_ready() -> bool:
	ensure()
	return last_daily != _today()


static func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


## Average pulls per Legendär with pity, for the open rates panel.
static func average_legendary() -> float:
	var p := rate(2)
	var n := pity_max()
	var expect := 0.0
	var miss := 1.0
	for i in range(1, n + 1):
		var hit := 1.0 if i == n else p
		expect += i * miss * hit
		miss *= 1.0 - hit
	return expect


## Banner prizes for Episch: catalog parts whose unlock hint names the title.
static func banner_parts(banner: Dictionary) -> Array:
	CreatorCatalog.ensure()
	var out: Array = []
	var title := str(banner.get("title", ""))
	for slot in CreatorCatalog.data.get("slots", {}):
		var u: Dictionary = CreatorCatalog.data["slots"][slot].get("unlock", {})
		for id in u:
			if title != "" and title in str(u[id]):
				out.append({"slot": slot, "id": id})
	return out


# --- currency -----------------------------------------------------------------------

static func add_crystals(n: int) -> void:
	ensure()
	crystals += n
	save()


static func claim_daily() -> int:
	ensure()
	if not daily_ready():
		return 0
	last_daily = _today()
	var n := int(data.get("daily", 100))
	crystals += n
	save()
	return n


## Called by Profile when the player levels up.
static func on_level_up(ups: int) -> void:
	ensure()
	add_crystals(int(data.get("level_up", 50)) * ups)


# --- pulling ------------------------------------------------------------------------

static func can_pull(n: int) -> bool:
	ensure()
	return crystals >= cost(n)


## Pulls n times on the banner; returns the results (empty when too poor).
## Every result is applied at once (style owned, part unlocked, item in bag).
static func pull(banner: Dictionary, n: int) -> Array:
	ensure()
	if not can_pull(n):
		return []
	crystals -= cost(n)
	var out: Array = []
	for i in n:
		var r := _roll_rarity()
		if n >= 10 and i == n - 1 and r == 0 and out.all(func(x): return int(x.rarity) == 0):
			r = 1  # the 10-pull guarantee
		out.append(_prize(banner, r))
	pulls_total += n
	SeasonPass.track("gacha", n)
	for res in out:
		history.push_front({"r": res.rarity, "name": res.name, "banner": banner.get("title", "")})
	history = history.slice(0, 40)
	save()
	Profile.save()
	return out


static func _roll_rarity() -> int:
	pity += 1
	if pity >= pity_max():
		pity = 0
		return 2
	var x := randf()
	if x < rate(2):
		pity = 0
		return 2
	if x < rate(2) + rate(1):
		return 1
	return 0


static func _prize(banner: Dictionary, r: int) -> Dictionary:
	match r:
		2:
			return _legendary(banner)
		1:
			return _epic(banner)
	return _rare()


static func _legendary(banner: Dictionary) -> Dictionary:
	var sid := str(banner.get("style", "glutatem"))
	if not guaranteed and randf() >= float(data.get("featured_share", 0.5)):
		var others: Array = banners().map(func(b): return str(b.style)).filter(func(s): return s != sid)
		if not others.is_empty():
			sid = others[randi() % others.size()]
			guaranteed = true
	else:
		guaranteed = false
	var res := {"rarity": 2, "kind": "style", "id": sid, "name": style_name(sid), "new": not owned.has(sid)}
	if owned.has(sid):
		var cap := int(data.get("max_stars", 6))
		if int(owned[sid]) < cap:
			owned[sid] = int(owned[sid]) + 1
		var sp := int(data.get("duplicate_splitter", 300))
		Profile.splitter += sp
		res["splitter"] = sp
		res["stars"] = int(owned[sid])
		res["text"] = "Duplikat: Stern %d · +%d Splitter" % [int(owned[sid]), sp]
	else:
		owned[sid] = 1
		# the style brings its own weapon (e.g. Bollwerk: the rifle Wachhund)
		var w := str(style_info(sid).get("weapon", ""))
		if w != "" and w != "none":
			CreatorUnlocks.unlock("weapon", w)
		res["stars"] = 1
		res["text"] = "Neuer Kampfstil! Im Creator (O) wählbar"
	return res


static func _epic(banner: Dictionary) -> Dictionary:
	var parts: Array = banner_parts(banner).filter(func(p): return not CreatorUnlocks.is_unlocked(p.slot, p.id))
	# effect skins of the banner's style are Episch prizes too (only looks)
	var sid := str(banner.get("style", ""))
	for sk in StyleSkin.banner_skins(sid):
		parts.append({"slot": "skin", "id": str(sk.id)})
	if not parts.is_empty() and randf() < 0.7:
		var p: Dictionary = parts[randi() % parts.size()]
		if p.slot == "skin":
			StyleSkin.unlock(sid, p.id)
			return {"rarity": 1, "kind": "skin", "style": sid, "id": p.id, "new": true,
				"name": StyleSkin.skin_name(sid, p.id), "text": "Effekt-Skin für %s (Tab)" % style_name(sid)}
		CreatorUnlocks.unlock(p.slot, p.id)
		return {"rarity": 1, "kind": "part", "slot": p.slot, "id": p.id, "new": true,
			"name": CreatorCatalog.item_name(p.slot, p.id), "text": "Neues Teil für den Creator"}
	if randf() < 0.3:
		var c := _color_prize(1)
		if not c.is_empty():
			return c
	return _gear(1, 2)


static func _rare() -> Dictionary:
	var pool: Array = data.get("selten_rewards", [])
	var total := 0.0
	for p in pool:
		total += float(p.get("weight", 1))
	var x := randf() * total
	for p in pool:
		x -= float(p.get("weight", 1))
		if x <= 0.0:
			match str(p.kind):
				"gear":
					return _gear(0, int(p.get("rarity", Loot.RARE)))
				"color":
					var c := _color_prize(0)
					if not c.is_empty():
						return c
			break
	var n := int(pool[0].get("amount", 40)) if not pool.is_empty() else 40
	Profile.splitter += n
	return {"rarity": 0, "kind": "splitter", "name": "%d Splitter" % n, "splitter": n, "text": "Für Umschmieden und mehr"}


static func _color_prize(r: int) -> Dictionary:
	CreatorCatalog.ensure()
	var locked: Array = []
	for i in CreatorCatalog.data.get("colors", []).size():
		if not CreatorUnlocks.is_color_unlocked(i):
			locked.append(i)
	if locked.is_empty():
		return {}
	var i: int = locked[randi() % locked.size()]
	CreatorUnlocks.unlock_color(i)
	return {"rarity": r, "kind": "color", "id": i, "new": true,
		"name": "Farbstoff %s" % CreatorCatalog.data["colors"][i]["name"],
		"color": str(CreatorCatalog.data["colors"][i].get("color", "ffffff")), "text": "Neue Farbe im Creator"}


static func _gear(r: int, loot_rarity: int) -> Dictionary:
	Profile.ensure()
	var it := Loot.roll(Profile.level, loot_rarity)
	if Profile.add_item(it):
		return {"rarity": r, "kind": "gear", "item": it, "name": str(it.name), "text": Loot.rarity_info(it).name + " · in der Tasche"}
	var sp := int(round(Loot.salvage_value(it)))
	Profile.splitter += sp
	return {"rarity": r, "kind": "splitter", "name": "%d Splitter" % sp, "splitter": sp, "text": "Tasche voll: %s zerlegt" % it.name}


## Test hook (F9 in the shrine): own every style and effect skin, plenty of crystals.
static func unlock_all() -> void:
	ensure()
	StyleSkin.unlock_all()
	for b in banners():
		if not owned.has(str(b.style)):
			owned[str(b.style)] = 1
	crystals += 10000
	save()
