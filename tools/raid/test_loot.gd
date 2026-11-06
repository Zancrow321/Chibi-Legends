extends SceneTree
## Rules of the raid loot (RaidLoot): sinking bonus chance per kill today,
## Raid-Marken per kill, trading marks for a chosen piece.
##   godot --headless -s res://tools/raid/test_loot.gd   → LOOT-TEST OK / FEHLER

var errors: Array = []


func _expect(ok: bool, what: String) -> void:
	print("LOOT ok: " if ok else "LOOT FEHLER: ", what)
	if not ok:
		errors.append(what)


func _initialize() -> void:
	Profile.ensure()
	Profile.reset()
	RaidLoot._loaded = true
	RaidLoot.day = RaidLoot.today()
	RaidLoot.kills = {}
	var chances: Array = []
	for i in 6:
		var r := RaidLoot.on_kill("essenwaechter")
		chances.append(r.chance)
	print("LOOT info: Chancen ", chances)
	_expect(is_equal_approx(chances[0], 1.0) and is_equal_approx(chances[1], 0.6) and is_equal_approx(chances[2], 0.36), "Bonus-Chance sinkt: 100 %, 60 %, 36 %")
	_expect(is_equal_approx(chances[5], RaidLoot.FLOOR), "nie unter %d %%" % int(RaidLoot.FLOOR * 100))
	_expect(Profile.marks == 6 * RaidLoot.MARKS.essenwaechter, "Raid-Marken bei jedem Sieg (%d)" % Profile.marks)
	RaidLoot.on_kill("turmwache")
	_expect(Profile.marks == 6 * RaidLoot.MARKS.essenwaechter + 1 and RaidLoot.kills_today("essenwaechter") == 6, "Turmwache zählt extra, eigener Zähler")
	RaidLoot.day = RaidLoot.today() - 1
	_expect(is_equal_approx(RaidLoot.bonus_chance("essenwaechter"), 1.0), "neuer Tag: volle Chance")
	var bag := Profile.items.size()
	var before := Profile.marks
	_expect(RaidLoot.buy("schuhe", Loot.EPIC) == "", "Tausch: epische Schuhe")
	var it: Dictionary = Profile.items.back()
	_expect(Profile.items.size() == bag + 1 and it.slot == "schuhe" and int(it.rarity) == Loot.EPIC and it.stats.has("gauge"), "Wunschteil liegt in der Tasche (%s)" % it.name)
	_expect(Profile.marks == before - RaidLoot.price(Loot.EPIC), "Marken abgezogen")
	_expect(RaidLoot.buy("waffe", Loot.LEGENDARY) != "", "zu wenig Marken für Legendär: abgelehnt")
	Profile.marks = 100
	_expect(RaidLoot.buy("waffe", Loot.LEGENDARY) == "" and Profile.items.back().has("mod"), "Legendäre Waffe mit Veränderung")
	Profile.reset()
	print("LOOT-TEST OK" if errors.is_empty() else "LOOT-TEST FEHLER: %s" % ", ".join(errors))
	quit()
