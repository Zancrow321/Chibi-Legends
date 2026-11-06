extends SceneTree
## Logiktest GOD-Stufe (läuft in CI):
##   godot --headless -s res://tools/god_items/test_god.gd
## Gibt "GOD-TEST OK" aus, wenn alles stimmt.

var fails := 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("GOD-TEST FEHLER: " + what)


func _initialize() -> void:
	Profile.reset()
	CreatorCatalog.ensure()
	check(Loot.RARITIES[Loot.GOD].id == "gott" and Loot.GOD == Loot.MYTHIC + 1, "GOD über Mythisch")
	for i in 20000:
		check(Loot.roll_rarity(i % 2 == 0) < Loot.GOD, "GOD fällt nie zufällig")
		if fails > 0:
			break
	# Liste wie auf dem Server
	check(GodItems.ORDER.size() == 48 and GodItems.ITEMS.size() == 48, "48 Teile")
	var sql := FileAccess.get_file_as_string("res://supabase/migrations/0004_god_items.sql")
	for id in GodItems.ORDER:
		check(GodItems.ITEMS.has(id), "Teil %s" % id)
		check(sql.contains("'%s'" % id), "Server kennt %s" % id)
	var series := {GodItems.HOLY: 0, GodItems.DEMON: 0}
	var styles := {}
	for id in GodItems.ORDER:
		var d := GodItems.info(id)
		series[d.series] += 1
		check(GodItems.texture(id) != null, "Icon %s" % id)
		var it := GodItems.make(id)
		check(it.rarity == Loot.GOD and it.stats.size() == 6 and it.sockets.size() == 3, "Werte/Sockel %s" % id)
		check(it.stats[Loot.MAIN_STAT[it.slot]] >= 0.07, "starker Hauptwert %s" % id)
		if d.has("part"):
			check(CreatorCatalog.slot_texture(d.part[0], d.part[1]) != null, "Look %s" % id)
			check(CreatorCatalog.data["slots"][d.part[0]]["items"].has(d.part[1]), "Creator-Eintrag %s" % id)
		if d.has("style"):
			styles[d.style] = true
			check(CreatorCatalog.data["styles"].has(d.style), "Stil %s" % d.style)
		if d.has("weapon"):
			check(CreatorCatalog.data["weapons"].has(d.weapon), "Waffe %s" % d.weapon)
	check(series[GodItems.HOLY] == 24 and series[GodItems.DEMON] == 24, "24 + 24")
	check(styles.size() == CreatorCatalog.data["styles"].size(), "eine GOD-Waffe pro Kampfstil")
	for f in ["fluegel_heilig", "fluegel_daemon", "heiligenschein", "feder", "glutfetzen"]:
		check(GodFx.tex(f) != null, "Effekt-Bild %s" % f)
	# Creator: gesperrt, bis man das Teil hat
	check(not CreatorUnlocks.is_unlocked("top", "god_seraph"), "Seraph gesperrt")
	# Tasche voll: GOD kommt trotzdem
	while not Profile.bag_full():
		Profile.add_item(Loot.roll(5, Loot.COMMON, "waffe"))
	var g := GodItems.grant("god_gewand")
	check(not g.is_empty() and Profile.items.size() == Profile.BAG_SIZE + 1, "GOD trotz voller Tasche")
	check(GodItems.grant("god_gewand").is_empty(), "nicht doppelt")
	check(CreatorUnlocks.is_unlocked("top", "god_seraph") and not CreatorUnlocks.is_unlocked("top", "god_abgrund"), "Seraph frei, Abgrund nicht")
	check(Profile.salvage(g.uid) == 0 and Profile.item(g.uid).size() > 0, "nicht zerlegbar")
	Profile.splitter = 99999
	check(Profile.reforge(g.uid, "crit") == "", "nicht umschmiedbar")
	# Werte wachsen mit der Stufe
	var before := float(g.stats.hp)
	Profile.add_exp(5000.0)
	check(float(Profile.item(g.uid).stats.hp) > before, "wächst mit der Stufe")
	# Tragen -> Look + Serie
	Profile.toggle_equip(g.uid)
	check("god_gewand" in GodItems.worn(), "getragen")
	var o := GodItems.look_override(["god_gewand", "god_sonnenkrone", "god_hoellenschlund", "god_engelsruf"], "glutatem")
	check(o.get("top") == "god_seraph" and o.get("hair") == "god_sonnenkrone" and o.get("weapon") == "god_hoellenschlund", "Look-Ersatz")
	check(GodItems.full_series(GodItems.ORDER.slice(0, 5)) == GodItems.HOLY and GodItems.full_series(GodItems.ORDER.slice(0, 4)) == "", "Erhebung erst mit 5")
	# Abgleich mit dem Server: fremde und Test-Teile gehen, eigene kommen
	GodItems.grant_all_test()
	check(GodItems.owned().size() == 48, "Testbesitz alle")
	var gained := GodItems.sync(["god_gewand", "god_mondfresser"])
	check(GodItems.owned().size() == 2 and "god_mondfresser" in GodItems.owned() and gained.size() == 1, "Abgleich (%s)" % str(GodItems.owned()))
	check(not "god_gewand" in GodItems.worn() or Profile.equipped_item("oberteil").has("god"), "Ausrüstung bleibt gültig")
	# Figur: Effekte entstehen
	var body := LayeredBody.new()
	root.add_child(body)
	await process_frame
	body.god_style = "glutatem"
	body.look = {"top": "kampfweste", "weapon": "schwert_kaiser", "style": "glutatem"}
	body.god = GodItems.ORDER.duplicate()
	check(body.god_fx != null and body.god_fx._wings.size() == 2, "zwei Flügelpaare")
	check(body._eff.get("weapon") == "god_hoellenschlund" and body._eff.get("top") in ["god_seraph", "god_abgrund"], "GOD-Look an der Figur")
	check(body.god_fx._blade_glow != null and body.god_fx._halo != null and body.god_fx._horns.size() == 3, "Klinge, Heiligenschein, Hörner")
	body.god = []
	check(body.god_fx == null and str(body._eff.get("weapon")) == "schwert_kaiser", "ablegen räumt auf")
	body.queue_free()
	Profile.reset()
	print("GOD-TEST OK" if fails == 0 else "GOD-TEST FEHLER: %d" % fails)
	quit()
