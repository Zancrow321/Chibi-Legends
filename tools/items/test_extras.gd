extends SceneTree
## Logic test for sockets, gems, sets and legendary mods (runs in CI):
##   godot --headless -s res://tools/items/test_extras.gd
## Prints "ITEM-TEST OK" when every check passes.

var fails := 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("ITEM-TEST FEHLER: " + what)


func _initialize() -> void:
	Profile.reset()
	Gems.reset()
	seed(7)
	# rolls: sockets by rarity, every legendary has a mod, epic set share
	var sets := 0
	for i in 400:
		var r := i % 4
		var it := Loot.roll(10, r, "", "glutatem")
		var n: int = it.get("sockets", []).size()
		check(n >= Loot.SOCKETS[r][0] and n <= Loot.SOCKETS[r][1], "Sockelzahl %d bei Seltenheit %d" % [n, r])
		check((r == 3) == it.has("mod"), "Mod nur bei Legendär")
		if it.has("set"):
			sets += 1
			check(r == 2, "Set-Teile sind episch")
			check(str(it.name) == str(ItemSets.SETS[it.set].pieces[it.slot]), "Set-Name")
	check(sets > 10 and sets < 60, "Set-Anteil %d / 100 epische" % sets)

	# gems: value, fuse, drops
	check(is_equal_approx(Gems.value("rubin_1"), snappedf(0.07 * 0.7, 0.001)), "Rubin-Wert")
	check(Gems.stat_of("onyx_3") == "def" and Gems.tier_of("onyx_3") == 3, "Onyx-Daten")
	check(not Gems.valid("rubin_4") and not Gems.valid("glas_1"), "ungültige Steine")
	Gems.add("rubin_1", 4)
	Profile.splitter = 100
	check(Profile.fuse_gem("rubin_1") == "rubin_2", "Verschmelzen")
	check(Gems.count("rubin_1") == 1 and Gems.count("rubin_2") == 1 and Profile.splitter == 60, "Verschmelzen zählt/kostet")
	check(Profile.fuse_gem("rubin_1") == "", "Verschmelzen braucht 3")

	# sockets change the stats, salvage returns gems
	var w := Loot.roll(10, 3, "waffe", "glutatem")
	w["sockets"] = ["", ""]
	Profile.add_item(w)
	Profile.toggle_equip(w.uid)
	var before := Profile.bonus("atk")
	check(Profile.socket_gem(w.uid, "rubin_2"), "Einsetzen")
	check(is_equal_approx(Profile.bonus("atk") - before, Gems.value("rubin_2")), "Edelstein zählt in bonus()")
	check(Gems.count("rubin_2") == 0, "Stein aus dem Beutel")
	check(Profile.unsocket_gem(w.uid, 0) and Gems.count("rubin_2") == 1, "Lösen")
	Profile.socket_gem(w.uid, "rubin_2")

	# sets: 2/4/6 pieces
	var kinds := ["oberteil", "hose", "schuhe", "accessoire", "talisman", "waffe"]
	var hp0 := Profile.bonus("hp")
	for k in kinds.size() - 1:
		var piece := Loot.roll(10, 2, kinds[k])
		ItemSets.make_piece(piece, "waldwaechter")
		Profile.add_item(piece)
		Profile.toggle_equip(piece.uid)
		if k == 1:
			check(ItemSets.worn_count("waldwaechter") == 2, "2 Set-Teile")
	check(ItemSets.worn_count("waldwaechter") == 5, "5 Set-Teile")
	check(ItemSets.bonus("hp") >= 0.08 - 0.0001 and ItemSets.bonus("def") >= 0.04 - 0.0001, "Set-Boni 2+4")
	check(is_equal_approx(ItemSets.cooldown_factor(), 1.0), "noch kein 6er-Bonus")
	check(Profile.bonus("hp") > hp0, "Set zählt in bonus()")
	var weapon := Loot.roll(10, 2, "waffe")
	ItemSets.make_piece(weapon, "waldwaechter")
	weapon.erase("mod")
	Profile.add_item(weapon)
	Profile.toggle_equip(weapon.uid)  # replaces the legendary weapon
	check(ItemSets.worn_count("waldwaechter") == 6, "6 Set-Teile")
	check(is_equal_approx(ItemSets.cooldown_factor(), 0.85), "6er-Bonus Abklingzeit")

	# legendary mods change the Zug of their style only
	var st := FightingStyle.load_style("glutatem")
	var hits0 := float(st.params("funkenschlag").get("hits", 0))
	var ring := Loot.roll(10, 3, "accessoire")
	ring["mod"] = "esse_atem"
	Profile.add_item(ring)
	Profile.toggle_equip(ring.uid)  # replaces the set accessoire: 5 pieces, no Abklingzeit bonus
	var cd0 := st.cooldown("weissglut")
	var ring2 := Loot.roll(10, 3, "talisman")
	ring2["mod"] = "schmiedeherz"
	Profile.add_item(ring2)
	Profile.toggle_equip(ring2.uid)
	check(ItemMods.worn().has("esse_atem"), "Mod angelegt")
	check(is_equal_approx(float(st.params("funkenschlag").hits), hits0 + 2.0), "Mod: +2 Treffer")
	check(is_equal_approx(st.cooldown("weissglut"), cd0 * 0.75), "Mod: Abklingzeit")
	var other := FightingStyle.load_style("bollwerk")
	check(not other.params("salve").get("pierce", false), "Mod wirkt nicht im falschen Stil")
	check(ItemMods._scale([5.0, 6.0], 1.0, 2.0) == [7.0, 8.0], "Listen-Schaden")
	for m in ItemMods.MODS:
		var info: Dictionary = ItemMods.MODS[m]
		var s2 := FightingStyle.load_style(str(info.style))
		check(s2.zuege.has(str(info.zug)), "Mod %s: Zug %s fehlt" % [m, info.zug])
		check(ItemMods.target_line(m) != "", "Mod-Zeile")

	print("Gear-Wert: ", Profile.gear_score(), "  Edelsteine: ", Gems.total())
	Profile.reset()
	Gems.reset()
	if fails == 0:
		print("ITEM-TEST OK")
	quit(1 if fails > 0 else 0)
