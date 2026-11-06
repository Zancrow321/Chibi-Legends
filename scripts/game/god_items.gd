class_name GodItems
extends RefCounted
## GOD-Stufe (über Mythisch): 18 Teile, jedes gibt es weltweit genau EINMAL.
##  - Serie 1 „Heilig“ (Gold, Weiß, Licht) und Serie 2 „Dämon“ (Schwarz,
##    Purpur, Glut): je Krone, Oberteil, Hose, Schuhe und Flügel (Accessoire),
##    dazu eine GOD-Waffe pro Kampfstil (4 heilige, 4 dämonische).
##  - Vergeben wird nur vom Server (supabase/migrations/0004_god_items.sql):
##    nach einem Raid-Sieg, einem Weltboss oder einer Turm-Bestmarke würfelt
##    cl_god_roll; gewinnt man, gehört einem ein noch freies Teil. Beim
##    Anmelden gleicht sync() die Tasche mit dem Server ab (cl_god_mine):
##    Teile, die einem nicht gehören, verschwinden.
##  - Werte: alle sechs Werte voll, wachsen mit der Spielerstufe mit, 3 Sockel.
##    GOD-Teile lassen sich nicht zerlegen, nicht umschmieden, nie verlieren.
##  - Optik: Kleidung und Krone werden beim Tragen erzwungen (LayeredBody.god),
##    die Effekte macht GodFx (Partikelflügel, Heiligenschein, Spuren ...).
## Offline gibt es keine GOD-Teile; zum Ansehen gibt es in der GOD-Halle die
## Anprobe und (nur offline) F9 = Testbesitz, der beim nächsten Login fällt.

const HOLY := "heilig"
const DEMON := "daemon"
const SERIES := {
	HOLY: {"name": "Heilig", "title": "Serie I · Heilig", "color": Color("ffe9a0"), "glow": Color("fff6d8")},
	DEMON: {"name": "Dämon", "title": "Serie II · Dämon", "color": Color("ff2d4a"), "glow": Color("ff5a2a")},
}

## id -> Teil. part: [Creator-Slot, Teil-id] (Look beim Tragen), style: nur Waffen.
const ITEMS := {
	# Serie 1 · Heilig
	"god_sonnenkrone": {"name": "Sonnenkrone des Seraphen", "series": HOLY, "slot": "accessoire", "part": ["hair", "god_sonnenkrone"], "fx": "halo",
		"line": "Wer sie trägt, wirft keinen Schatten mehr."},
	"god_gewand": {"name": "Gewand des Ersten Lichts", "series": HOLY, "slot": "oberteil", "part": ["top", "god_seraph"], "fx": "radiance",
		"line": "Gewebt aus dem ersten Sonnenaufgang der Welt."},
	"god_beinkleid": {"name": "Beinkleid der Gnade", "series": HOLY, "slot": "hose", "part": ["pants", "god_seraph"], "fx": "motes",
		"line": "Jeder Schritt ein Gebet, jede Ruhe ein Segen."},
	"god_morgenschritte": {"name": "Schritte des Morgens", "series": HOLY, "slot": "schuhe", "part": ["shoes", "god_seraph"], "fx": "steps",
		"line": "Wo sie auftreten, blüht für einen Atemzug das Licht."},
	"god_seraphfluegel": {"name": "Flügel des Seraphen", "series": HOLY, "slot": "talisman", "fx": "wings",
		"line": "Sechs Federn fielen vom Himmel. Eine davon bist du."},
	# Serie 2 · Dämon
	"god_hoernerkrone": {"name": "Hörnerkrone des Abgrunds", "series": DEMON, "slot": "accessoire", "part": ["hair", "god_hoernerkrone"], "fx": "horns",
		"line": "Sie wächst nicht auf dem Kopf. Sie wächst aus ihm."},
	"god_hoellenpanzer": {"name": "Panzer des Höllenfürsten", "series": DEMON, "slot": "oberteil", "part": ["top", "god_abgrund"], "fx": "radiance",
		"line": "Darunter schlägt kein Herz, nur eine Esse."},
	"god_kettenbeinkleid": {"name": "Kettenbeinkleid der Verdammnis", "series": DEMON, "slot": "hose", "part": ["pants", "god_abgrund"], "fx": "motes",
		"line": "Jedes Glied eine gebrochene Seele."},
	"god_aschewandler": {"name": "Aschewandler", "series": DEMON, "slot": "schuhe", "part": ["shoes", "god_abgrund"], "fx": "steps",
		"line": "Der Boden erinnert sich noch Tage an jeden Schritt."},
	"god_verdammnisschwingen": {"name": "Schwingen der Verdammnis", "series": DEMON, "slot": "talisman", "fx": "wings",
		"line": "Sie haben nie gelernt zu fliegen. Nur zu fallen."},
	# Waffen, je eine pro Kampfstil
	"god_glockenschwinge": {"name": "Glockenschwinge", "series": HOLY, "slot": "waffe", "style": "gleichklang", "weapon": "god_glockenschwinge",
		"line": "Ihr Klang ruft die Seelen heim, nicht fort."},
	"god_engelsruf": {"name": "Engelsruf", "series": HOLY, "slot": "waffe", "style": "bollwerk", "weapon": "god_engelsruf",
		"line": "Jeder Schuss ein Chor, jeder Treffer ein Amen."},
	"god_sonnenfaeuste": {"name": "Sonnenfäuste", "series": HOLY, "slot": "waffe", "style": "grenzbrecher", "fx": "fists",
		"line": "Zwei kleine Sonnen, die zuschlagen können."},
	"god_himmelswirbel": {"name": "Himmelswirbel", "series": HOLY, "slot": "waffe", "style": "wirbelwille", "fx": "fists",
		"line": "Der Wind des siebten Himmels um zwei Fäuste gewickelt."},
	"god_hoellenschlund": {"name": "Höllenschlund", "series": DEMON, "slot": "waffe", "style": "glutatem", "weapon": "god_hoellenschlund",
		"line": "Die Klinge atmet. Sie atmet ein."},
	"god_mondfresser": {"name": "Mondfresser", "series": DEMON, "slot": "waffe", "style": "schwarzmond", "weapon": "god_mondfresser",
		"line": "Es gab einmal zwei Monde."},
	"god_hoellenfaust": {"name": "Höllenfaust", "series": DEMON, "slot": "waffe", "style": "lauffeuer", "fx": "fists",
		"line": "Das Feuer darin war vor der Welt da."},
	"god_teufelsfeder": {"name": "Teufelsfeder", "series": DEMON, "slot": "waffe", "style": "spannkraft", "fx": "fists",
		"line": "Je weiter sie ausholt, desto tiefer der Fall."},
}
## Die Reihenfolge der Halle (wie im Server, cl_god_rules().items).
const ORDER := ["god_sonnenkrone", "god_gewand", "god_beinkleid", "god_morgenschritte", "god_seraphfluegel",
	"god_hoernerkrone", "god_hoellenpanzer", "god_kettenbeinkleid", "god_aschewandler", "god_verdammnisschwingen",
	"god_glockenschwinge", "god_engelsruf", "god_sonnenfaeuste", "god_himmelswirbel",
	"god_hoellenschlund", "god_mondfresser", "god_hoellenfaust", "god_teufelsfeder"]
const SOCKETS := 3
## Bonus, wenn alle fünf Kleidungsteile einer Serie getragen werden („Erhebung“).
const FULL_SET := 5

static var _tex := {}
## Anprobe in der GOD-Halle: ids, die nur angesehen werden (nicht gespeichert).
static var try_on: Array = []


static func info(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func is_god(it: Dictionary) -> bool:
	return it.has("god")


## Baut das Teil für die Tasche; Werte und Stufe folgen der Spielerstufe.
static func make(id: String, test := false) -> Dictionary:
	var d := info(id)
	var it := {"name": str(d.name), "slot": str(d.slot), "rarity": Loot.GOD, "god": id, "series": str(d.series),
		"line": str(d.line), "icon": 0, "stats": {}, "ilvl": 1}
	var sockets: Array = []
	sockets.resize(SOCKETS)
	sockets.fill("")
	it["sockets"] = sockets
	if d.has("style"):
		# die Waffe trägt einen legendären Mod ihres eigenen Stils
		var m := ItemMods.roll(str(d.style))
		if m != "":
			it["mod"] = m
	if test:
		it["test"] = true
	refresh(it)
	return it


## Werte neu: alle sechs Werte am oberen Ende, mal GOD-Stärke, mit der Stufe.
static func refresh(it: Dictionary) -> void:
	var lv := maxi(1, Profile.level)
	it["ilvl"] = lv
	var rar: Dictionary = Loot.RARITIES[Loot.GOD]
	var lv_mult := 1.0 + (lv - 1) * 0.08
	var main: String = Loot.MAIN_STAT[str(it.slot)]
	var stats := {main: 0.0}
	for s in Loot.STATS:
		var v: float = float(Loot.STATS[s].max) * float(rar.power) * lv_mult
		if s == "def":
			v = minf(v, 0.12)
		stats[s] = snappedf(v, 0.001)
	it["stats"] = stats


static func refresh_all() -> void:
	for it in Profile.items:
		if is_god(it):
			refresh(it)


## Alle GOD-ids in der Tasche.
static func owned() -> Array:
	return Profile.items.filter(func(it): return is_god(it)).map(func(it): return str(it.god))


static func owns(id: String) -> bool:
	return id in owned() or id in try_on


## Was gerade getragen wird (plus Anprobe).
static func worn() -> Array:
	var out: Array = []
	for s in Profile.SLOTS:
		var it := Profile.equipped_item(s)
		if is_god(it):
			out.append(str(it.god))
	for id in try_on:
		if not id in out:
			out.append(id)
	return out


## Creator: GOD-Teile sind frei, solange man das Teil besitzt.
static func owns_part(slot: String, part_id: String) -> bool:
	for id in owned() + try_on:
		var p: Array = info(id).get("part", [])
		if p.size() == 2 and p[0] == slot and p[1] == part_id:
			return true
	return false


## Look-Ersatz der getragenen Teile: {creator-slot: part}; dazu Waffe des Stils.
static func look_override(ids: Array, style_id: String) -> Dictionary:
	var out := {}
	for id in ids:
		var d := info(id)
		var p: Array = d.get("part", [])
		if p.size() == 2:
			out[p[0]] = p[1]
		if d.has("weapon") and str(d.get("style", "")) == style_id:
			out["weapon"] = d.weapon
	return out


## Welche Serie komplett (5 Kleidungsteile) getragen wird, "" sonst.
static func full_series(ids: Array) -> String:
	for s in SERIES:
		var n := 0
		for id in ids:
			var d := info(id)
			if str(d.get("series", "")) == s and str(d.slot) != "waffe":
				n += 1
		if n >= FULL_SET:
			return s
	return ""


static func texture(id: String) -> Texture2D:
	if not _tex.has(id):
		var p := "res://assets/god/icons/%s.png" % id
		_tex[id] = load(p) if ResourceLoader.exists(p) else null
	return _tex[id]


## Gewonnen (Server) oder Testbesitz: ins Gepäck, egal ob die Tasche voll ist.
static func grant(id: String, test := false) -> Dictionary:
	if not ITEMS.has(id) or id in owned():
		return {}
	var it := make(id, test)
	Profile.add_item(it)
	return it


## Abgleich mit dem Server (Liste der eigenen GOD-ids). Fehlende kommen dazu,
## fremde (oder Testbesitz) gehen; getragene werden dabei abgelegt.
static func sync(server_ids: Array) -> Array:
	Profile.ensure()
	var gained: Array = []
	for it in Profile.items.duplicate():
		if is_god(it) and (bool(it.get("test", false)) or not str(it.god) in server_ids):
			for s in Profile.SLOTS:
				if Profile.equipped[s] == str(it.uid):
					Profile.equipped[s] = ""
			Profile.items.erase(it)
	for id in server_ids:
		if ITEMS.has(str(id)) and not str(id) in owned():
			grant(str(id))
			gained.append(str(id))
	refresh_all()
	Profile.save()
	return gained


## Nach einem Sieg: der Server würfelt. Gibt die gewonnene id zurück ("" sonst).
## source: raid | world | tower, ref: Tag / Weltboss-id / Etage.
static func try_roll(source: String, ref: String) -> String:
	if not Net.is_online():
		return ""
	var r: Dictionary = await Net.call_fn("cl_god_roll", {"source": source, "ref": ref})
	if not r.ok or not (r.data is Dictionary) or not bool(r.data.get("won", false)):
		return ""
	var id := str(r.data.get("item", ""))
	if grant(id).is_empty():
		return ""
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.call_group("god_reveal", "reveal", id)
	return id


## Offline-Test (F9 in der GOD-Halle): alle Teile als Testbesitz.
static func grant_all_test() -> void:
	for id in ORDER:
		grant(id, true)
