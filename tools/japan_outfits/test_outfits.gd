extends SceneTree
## Logiktest Anime- und japanische Kleidung (läuft in CI):
##   godot --headless -s res://tools/japan_outfits/test_outfits.gd
## Gibt "KLEIDUNG-TEST OK" aus, wenn alles stimmt.

const OUTFITS := ["hanabi", "mondhakama", "kranich", "gakuran", "matrose", "yukata", "shinobi", "miko"]
const HEADS := ["hachimaki", "chonmage", "kitsune", "kasa"]
const CYBER := ["neonlaeufer", "chromsoeldner", "datenhoodie", "synthidol", "konzern", "strassenklinge"]

var fails := 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("KLEIDUNG-TEST FEHLER: " + what)


func _initialize() -> void:
	CreatorCatalog.ensure()
	for o in OUTFITS:
		for slot in ["top", "pants", "shoes"]:
			check(CreatorCatalog.slot_texture(slot, o) != null, "Ebene %s/%s" % [slot, o])
			check(CreatorCatalog.item_name(slot, o) != o, "Name %s/%s" % [slot, o])
			check(CreatorUnlocks.hint(slot, o) != "", "Freischalt-Hinweis %s/%s" % [slot, o])
	for h in HEADS:
		check(CreatorCatalog.slot_texture("hair", h) != null, "Kopfteil %s" % h)
		check(CreatorCatalog.hair_meta.has(h), "Kopfanker %s" % h)
	check(CreatorUnlocks.hint("hair", "chonmage") == "", "Samurai-Knoten ist frei")
	# Gacha: die Banner geben die passenden Teile aus
	var by_title := {}
	for b in Gacha.banners():
		by_title[str(b.title)] = Gacha.banner_parts(b).map(func(p): return "%s/%s" % [p.slot, p.id])
	check("top/mondhakama" in by_title.get("Der schwarze Mond", []) and "hair/kasa" in by_title.get("Der schwarze Mond", []), "Banner Schwarzmond")
	check("shoes/shinobi" in by_title.get("Ein Versprechen wird Stärke", []) and "hair/hachimaki" in by_title.get("Ein Versprechen wird Stärke", []), "Banner Wirbelwille")
	check("pants/miko" in by_title.get("Ein Takt, zwei Seelen", []) and "hair/kitsune" in by_title.get("Ein Takt, zwei Seelen", []), "Banner Gleichklang")
	# Saisonpass: Outfit-Belohnung schaltet alle drei Teile frei
	var found := 0
	for prem in [false, true]:
		for t in range(1, 31):
			var r: Dictionary = SeasonPass.reward(t, prem)
			if str(r.get("kind", "")) == "part" and str(r.get("slot", "")) == "outfit":
				found += 1
				check(str(r.id) in OUTFITS, "Pass-Outfit %s" % r.id)
				check(SeasonPass.label(r).begins_with("Outfit "), "Pass-Beschriftung %s" % r.id)
				var txt := SeasonPass.give(r)
				check(txt.begins_with("Neues Outfit"), "Pass-Text %s" % txt)
				for slot in ["top", "pants", "shoes"]:
					check(CreatorUnlocks.is_unlocked(slot, str(r.id)), "Pass schaltet %s/%s frei" % [slot, r.id])
	check(found == 5, "5 Outfits im Saisonpass (%d)" % found)
	# Cyberpunk: Ebenen, Neon-Leuchten, Freischalten über Turm-Bestmarken
	for o in CYBER:
		for slot in ["top", "pants", "shoes"]:
			check(CreatorCatalog.slot_texture(slot, o) != null, "Cyber-Ebene %s/%s" % [slot, o])
			check(CreatorUnlocks.hint(slot, o).begins_with("Turm der Prüfungen"), "Cyber-Hinweis %s/%s" % [slot, o])
	for h in ["neonvisier", "neonkamm"]:
		check(CreatorCatalog.slot_texture("hair", h) != null and CreatorCatalog.hair_meta.has(h), "Cyber-Kopfteil %s" % h)
	check(CreatorCatalog.data.get("neon", {}).has("neonlaeufer"), "Neon-Farbe Neonläufer")
	var ids := ThemeOutfits.TOWER.values().map(func(p): return str(p[1]))
	for o in CYBER:
		check(o in ids, "Turm gibt %s" % o)
	check(ThemeOutfits.tower_floor(3) == "", "Etage 3 ohne Neon-Belohnung")
	check(ThemeOutfits.tower_floor(5) != "" and CreatorUnlocks.is_unlocked("pants", "datenhoodie"), "Etage 5 schaltet Daten-Hoodie frei")
	check(ThemeOutfits.tower_floor(5) == "", "nur einmal")
	check(ThemeOutfits.tower_floor(15) != "" and CreatorUnlocks.is_unlocked("hair", "neonkamm"), "Etage 15 Neon-Irokese")
	print("KLEIDUNG-TEST OK" if fails == 0 else "KLEIDUNG-TEST FEHLER: %d" % fails)
	quit()
