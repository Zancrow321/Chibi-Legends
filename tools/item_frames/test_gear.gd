extends SceneTree
## Logic test for Aufwerten, Sperren, Sammel-Zerlegen and the rarity frames
## (runs in CI):  godot --headless -s res://tools/item_frames/test_gear.gd
## Prints "AUSRUESTUNG-TEST OK" when every check passes.

var fails := 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("AUSRUESTUNG-TEST FEHLER: " + what)


func _initialize() -> void:
	Profile.reset()
	Gems.reset()
	seed(11)
	# frames: one slot and one rim texture per rarity
	for r in Loot.RARITIES.size():
		check(ItemFrame.slot_texture(r) != null, "Rahmen %s fehlt" % Loot.RARITIES[r].id)
		check(ItemFrame.rim_texture(r) != null, "Kartenrand %s fehlt" % Loot.RARITIES[r].id)
	check(Loot.MAX_PLUS.size() == Loot.RARITIES.size(), "MAX_PLUS je Seltenheit")

	# upgrade: costs, multiplies affixes, capped by rarity
	var w := Loot.roll(10, Loot.EPIC, "waffe")
	Profile.add_item(w)
	Profile.toggle_equip(w.uid)
	var atk0 := Profile.bonus("atk")
	var base := float(w.stats.atk)
	Profile.splitter = 0
	check(Profile.upgrade(w.uid) == 0, "Aufwerten ohne Splitter")
	Profile.splitter = 100000
	var c1 := Loot.upgrade_cost(w)
	check(Profile.upgrade(w.uid) == 1 and Profile.splitter == 100000 - c1, "Aufwerten +1 kostet")
	check(is_equal_approx(Loot.affix(w, "atk"), base * (1.0 + Loot.PLUS_STEP)), "Wert +6 %")
	check(Profile.bonus("atk") > atk0, "Aufwerten zählt in bonus()")
	check(Loot.upgrade_cost(w) > c1, "nächste Stufe teurer")
	check(Loot.display_name(w).ends_with(" +1"), "Name zeigt +1")
	while Loot.can_upgrade(w):
		Profile.upgrade(w.uid)
	check(int(w.plus) == Loot.MAX_PLUS[Loot.EPIC], "Episch endet bei +%d" % Loot.MAX_PLUS[Loot.EPIC])
	check(Profile.upgrade(w.uid) == 0, "kein Aufwerten über Höchststufe")
	var plain := w.duplicate(true)
	plain.erase("plus")
	check(Loot.salvage_value(w) > Loot.salvage_value(plain), "Zerlegen gibt Aufwertung teilweise zurück")

	# lock + bulk salvage: only up to Selten, never worn or locked
	Profile.toggle_equip(w.uid)
	for r in [Loot.COMMON, Loot.UNCOMMON, Loot.RARE, Loot.RARE, Loot.EPIC, Loot.LEGENDARY]:
		Profile.add_item(Loot.roll(5, r, "hose"))
	var keep: Dictionary = Profile.items[2]  # Ungewöhnlich
	var worn: Dictionary = Profile.items[3]  # Selten
	check(Profile.toggle_lock(keep.uid), "Sperren")
	Profile.toggle_equip(worn.uid)
	check(Profile.salvage(keep.uid) == 0, "Gesperrtes nicht zerlegbar")
	var n := Profile.bulk_candidates().size()
	check(n == 2, "Sammel-Kandidaten %d (erwartet 2)" % n)
	var sp := Profile.splitter
	var res := Profile.salvage_bulk()
	check(res[0] == 2 and Profile.splitter == sp + int(res[1]) and int(res[1]) > 0, "Sammel-Zerlegen")
	check(not Profile.item(keep.uid).is_empty() and not Profile.item(worn.uid).is_empty(), "gesperrt + angelegt bleiben")
	check(Profile.items.size() == 5, "Tasche nach Sammel-Zerlegen: %d" % Profile.items.size())
	check(not Profile.toggle_lock(keep.uid) and Profile.salvage(keep.uid) > 0, "Entsperren")

	# new stats: they roll, count in bonus() and keep their names
	Profile.reset()
	var seen := {}
	for i in 600:
		var it := Loot.roll(10, Loot.MYTHIC)
		for st in it.stats:
			seen[st] = true
	for st in ["speed", "lifesteal", "elem"]:
		check(seen.has(st), "Wert %s wird gewürfelt" % st)
	var boots := Loot.roll(10, Loot.COMMON, "schuhe")
	boots.stats["speed"] = 0.04
	Profile.add_item(boots)
	Profile.toggle_equip(boots.uid)
	check(is_equal_approx(Profile.bonus("speed"), 0.04), "Lauftempo zählt")
	check(Loot.stat_line("lifesteal", 0.01) == "+1,0 % Lebensraub", "Name Lebensraub")

	Profile.reset()
	print("AUSRUESTUNG-TEST OK" if fails == 0 else "AUSRUESTUNG-TEST: %d Fehler" % fails)
	quit()
