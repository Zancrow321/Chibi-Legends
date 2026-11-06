extends SceneTree
## Test drive for the Weltenriss (world boss Donnerhorn, shared health):
## offline pool, waking, hits on the shared bar, phases, knock-out keeps the
## health, the online view (best list from a server answer), the fall and
## the loot, the pause and the next rift. Finally the rift in the courtyard.
## Prints WELTBOSS-PROBE OK or WELTBOSS-PROBE FEHLER.
##   godot --headless --fixed-fps 60 -s res://tools/worldboss/probe.gd                 (rules only)
##   xvfb-run godot --path . --fixed-fps 60 -s res://tools/worldboss/probe.gd -- <out_dir>

var out := ""
var f := 0
var room: TrainingRoom
var p: Player
var wb: WorldBossDirector
var steps: Array = []
var errors: Array = []
var _marks0 := 0
var _ko := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(WorldBossDirector.SAVE_PATH))
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.set("show_title", false)
	GameFlow.area = "weltenriss"
	GameFlow.mode = GameFlow.DUNGEON
	change_scene_to_file("res://scenes/main.tscn")
	var t := 40
	steps = [
		[t, "setup"], [t + 10, "shot:riss_01_eingang"], [t + 20, "walk_in"], [t + 30, "check_awake"],
		[t + 110, "near"], [t + 130, "shot:riss_02_donnerhorn"],
		[t + 140, "hit"], [t + 146, "check_hit"],
		[t + 150, "phase2"], [t + 156, "check_phase2"],
		[t + 160, "ko"], [t + 166, "check_ko"],
		[t + 200, "online_view"], [t + 230, "near"], [t + 260, "shot:riss_03_bestenliste"], [t + 270, "offline_again"],
		[t + 280, "finish"], [t + 290, "check_fallen"], [t + 380, "shot:riss_04_besiegt"],
		[t + 390, "reopen"], [t + 420, "check_reopen"],
		[t + 430, "overworld"], [t + 520, "hide"], [t + 540, "shot:riss_05_hof"],
		[t + 550, "quit"],
	]


func _process(_delta: float) -> bool:
	f += 1
	if room != null and is_instance_valid(room):
		room._slow_until = 0
		Engine.time_scale = 1.0
	if p != null and is_instance_valid(p) and not _ko:
		p.hp = p.max_hp
	for s in steps:
		if s[0] == f:
			_do(s[1])
	return false


func _expect(ok: bool, what: String) -> void:
	if ok:
		print("WELTBOSS ok: ", what)
	else:
		print("WELTBOSS FEHLER: ", what)
		errors.append(what)


func _boss() -> WorldBoss:
	return wb.boss as WorldBoss if wb.boss != null and is_instance_valid(wb.boss) else null


func _do(cmd: String) -> void:
	var parts := cmd.split(":")
	match parts[0]:
		"setup":
			_hide_select(root)
			paused = false
			room = _find_room(root)
			_expect(room != null and room.is_worldboss and room.raid is WorldBossDirector, "Weltenriss startet mit WorldBossDirector")
			_expect(room.waves == null and room.post == null, "keine Wellen, kein Pfahl")
			p = room.player
			p.infinite_aura = true
			wb = room.raid as WorldBossDirector
			_expect(not wb.online and wb.status == "aktiv", "offline: eigener Lebens-Pool")
			_expect(_boss() != null and _boss().max_hp == WorldBossDirector.HP_PER_FIGHTER and _boss().state == "sleep", "Donnerhorn schläft, %d LP" % WorldBossDirector.HP_PER_FIGHTER)
			_expect(_boss().shield_at.is_empty(), "Weltboss ohne Schild-Phasen")
			_marks0 = Profile.marks
		"walk_in":
			p.global_position = Vector2(340, 299)
			p.facing = 1
		"check_awake":
			_expect(wb.is_fighting() and _boss().state != "sleep", "Donnerhorn erwacht beim Betreten")
		"near":
			if _boss() != null:
				p.global_position = Vector2(_boss().global_position.x - 170.0, 299)
				p.facing = 1
		"hit":
			_boss().apply_damage(1500.0)
		"check_hit":
			_expect(wb.own_damage() == 1500 and is_equal_approx(_boss().hp, 58500.0), "Treffer ziehen von der gemeinsamen Leiste ab")
			_expect(wb.phase() == 1, "Phase 1")
		"phase2":
			_boss().apply_damage(20000.0)
		"check_phase2":
			_expect(wb.phase() == 2 and _boss().phase == 2, "unter 66 %%: Phase 2 (%d LP)" % int(_boss().hp))
		"ko":
			_ko = true
			p.hp = 1.0
			p.hurt_invuln = 0.0
			p.in_super = false
			p.dash_timer = 0.0
			p.blocking = false
			p.receive_hit(50.0, p.global_position.x + 40.0, null)
		"check_ko":
			_ko = false
			_expect(_boss() != null and is_equal_approx(_boss().hp, 38500.0) and wb.attempts == 2, "K.o.: Boss behält seine Lebenspunkte")
		"online_view":
			# a server answer as cl_world_state sends it (no network: busy blocks reports and polls)
			wb.online = true
			wb._busy = true
			wb._take({"id": wb.boss_id, "boss": "donnerhorn", "hp": 241337, "max_hp": 480000, "state": "aktiv",
				"next_in": 0, "ends_in": 200000, "fighters_now": 5, "fighters": 8, "my_damage": 21500, "my_rank": 3,
				"claimable": false, "claimed": false, "last_hit": null,
				"top": [{"name": "Hotaru", "damage": 64210, "me": false}, {"name": "Raiga", "damage": 40990, "me": false},
					{"name": "Kaiser", "damage": 21500, "me": true}, {"name": "Suzu", "damage": 15800, "me": false},
					{"name": "Oboro", "damage": 9120, "me": false}]})
			_expect(is_equal_approx(_boss().max_hp, 480000.0) and is_equal_approx(_boss().hp, 241337.0), "Server-Stand übernommen (gemeinsame Leiste)")
			_expect(wb.phase() == 2 and wb.top.size() == 5, "Bestenliste vom Server")
			wb.add_damage(1000.0)
			_expect(is_equal_approx(wb.shown_hp(), 240337.0) and wb.own_damage() == 22500, "eigene Treffer bis zur Meldung vorgemerkt")
		"offline_again":
			wb.online = false
			wb._busy = false
			wb.pending = 0.0
			wb._apply_local()
			_boss().sync()
		"finish":
			_count_drops()
			_boss().apply_damage(_boss().hp + 10.0)
		"check_fallen":
			_expect(wb.status == "besiegt" and wb.won, "Leiste leer: Donnerhorn fällt")
			_expect(Profile.marks > _marks0, "Raid-Marken als Lohn (+%d)" % (Profile.marks - _marks0))
			_expect(_count_drops() >= 2, "Beute liegt bereit")
			_expect(wb.notice().contains("öffnet sich"), "Pause bis zum nächsten Riss")
		"reopen":
			wb.next_in = 0.0
			wb._tick = 0.0
		"check_reopen":
			_expect(wb.status == "aktiv" and _boss() != null and _boss().state != "dead" and is_equal_approx(_boss().hp, float(WorldBossDirector.HP_PER_FIGHTER)), "neuer Riss: Donnerhorn ist zurück")
		"overworld":
			GameFlow.area = "akademie_hof"
			GameFlow.mode = GameFlow.OVERWORLD
			GameFlow.entry_door = "tor_riss"
			p = null
			wb = null
			room = null
			change_scene_to_file("res://scenes/main.tscn")
		"hide":
			_hide_select(root)
			paused = false
			var ow := _find_overworld(root)
			var found := false
			if ow != null:
				for s in ow.get("spots"):
					found = found or (s.get("id") == "tor_riss" and s.get("target_area") == "weltenriss")
			_expect(found, "Weltenriss im Hof")
		"shot":
			_hide_select(root)
			_shot(parts[1])
		"quit":
			print("WELTBOSS-PROBE OK" if errors.is_empty() else "WELTBOSS-PROBE FEHLER: %s" % ", ".join(errors))
			quit()


func _count_drops() -> int:
	var n := 0
	for c in room.get_children():
		if c is LootDrop:
			n += 1
	return n


func _shot(name: String) -> void:
	if out == "" or DisplayServer.get_name() == "headless":
		return
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png(out.path_join(name + ".png"))


func _hide_select(n: Node) -> void:
	if n is CharacterSelect or n is CreatorScreen:
		n.visible = false
	for c in n.get_children():
		_hide_select(c)


func _find_room(n: Node) -> TrainingRoom:
	if n is TrainingRoom:
		return n
	for c in n.get_children():
		var r := _find_room(c)
		if r != null:
			return r
	return null


## Untyped: naming the Overworld class here would compile it with the
## autoloads (AreaTransition), which test scripts cannot see.
func _find_overworld(n: Node) -> Node:
	if n.get("spots") is Array and n.has_method("ground_y"):
		return n
	for c in n.get_children():
		var r := _find_overworld(c)
		if r != null:
			return r
	return null
