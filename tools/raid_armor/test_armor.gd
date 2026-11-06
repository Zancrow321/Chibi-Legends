extends SceneTree
## Logiktest Raid-Rüstung Essenwacht und sechs Seltenheiten (läuft in CI):
##   godot --headless -s res://tools/raid_armor/test_armor.gd
## Gibt "RUESTUNG-TEST OK" aus, wenn alles stimmt.

var fails := 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("RUESTUNG-TEST FEHLER: " + what)


func _initialize() -> void:
	Profile.reset()
	seed(11)
	check(Loot.RARITIES.size() == 7 and Loot.RARITIES[Loot.GOD].id == "gott" and Loot.RARITIES[Loot.MYTHIC].id == "mythisch" and Loot.RARITIES[Loot.UNCOMMON].id == "ungewoehnlich", "sechs Seltenheiten")
	check(Loot.SOCKETS.size() == Loot.RARITIES.size(), "Sockel für jede Seltenheit")
	# alte Spielstände: 0 bleibt, 1..3 rücken eins hoch
	check(Loot.migrate_rarity(0) == 0 and Loot.migrate_rarity(1) == Loot.RARE and Loot.migrate_rarity(2) == Loot.EPIC and Loot.migrate_rarity(3) == Loot.LEGENDARY, "Umrechnung alter Seltenheiten")
	# Tabellen: alle Stufen kommen vor, Mythisch ist selten
	var counts := [0, 0, 0, 0, 0, 0]
	for i in 20000:
		counts[Loot.roll_rarity()] += 1
	print("RUESTUNG normale Drops: ", counts)
	check(counts[0] > counts[1] and counts[1] > counts[2] and counts[2] > counts[3] and counts[4] > counts[5], "Drop-Tabelle fällt ab")
	var raid := [0, 0, 0, 0, 0, 0]
	for i in 5000:
		raid[Loot.pick_rarity(Loot.RAID_TABLE)] += 1
	print("RUESTUNG Raid-Rüstung: ", raid)
	check(raid.all(func(n): return n > 0), "jede Seltenheit der Raid-Rüstung kann fallen")
	# Teile: Name, Slot, kein Set, Mythisch mit 5 Werten, 2 Sockeln und Mod
	for r in Loot.MYTHIC + 1:  # GOD-Teile sind keine Raid-Rüstung
		for s in RaidArmor.PIECES:
			var it := RaidArmor.roll(10, "glutatem", r, s)
			check(it.raid == RaidArmor.ID and it.slot == s and not it.has("set"), "Raid-Teil %s/%d" % [s, r])
			check(it.stats.size() == int(Loot.RARITIES[r].rolls), "Werte %s/%d" % [s, r])
			check(RaidArmor.texture(s, r) != null, "Icon %s/%d" % [s, r])
			check(CreatorCatalog.slot_texture(RaidArmor.PART_SLOT[s], RaidArmor.part_id(r)) != null, "Outfit-Ebene %s/%d" % [s, r])
		check(CreatorCatalog.slot_texture("hair", RaidArmor.part_id(r)) != null, "Helm %d" % r)
	var m := RaidArmor.roll(10, "glutatem", Loot.MYTHIC, "oberteil")
	check(m.has("mod") and m.has("line") and m.sockets.size() == 2, "Mythisch: Mod, Spruch, 2 Sockel")
	print("RUESTUNG Beispiel: ", m.name, " ", m.stats)
	# Beute schaltet den Look im Creator frei
	check(not CreatorUnlocks.is_unlocked("top", "raid_episch"), "Episch-Harnisch erst gesperrt")
	Profile.add_item(RaidArmor.roll(10, "", Loot.EPIC, "oberteil"))
	check(CreatorUnlocks.is_unlocked("top", "raid_episch") and CreatorUnlocks.is_unlocked("hair", "raid_episch"), "Harnisch + Helm freigeschaltet")
	check(not CreatorUnlocks.is_unlocked("pants", "raid_episch"), "Hose bleibt gesperrt")
	# Glühen
	check(RaidArmor.glow_level({"top": "raid_selten"}) < Loot.EPIC, "Selten glüht nicht")
	check(RaidArmor.glow_level({"top": "kampfweste", "shoes": "raid_mythisch"}) == Loot.MYTHIC, "Mythisch erkannt")
	Profile.reset()
	print("RUESTUNG-TEST OK" if fails == 0 else "RUESTUNG-TEST FEHLER: %d" % fails)
	quit()
