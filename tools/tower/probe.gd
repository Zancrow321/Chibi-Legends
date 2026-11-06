extends SceneTree
## Test drive for the Turm der Prüfungen: starts a run, clears floors,
## jumps to the Turmwache floors 5 and 15, checks scaling and rewards,
## ends the run with a knock-out and finally looks at the new gates in the
## courtyard. Prints TURM-TEST OK or TURM-TEST FEHLER.
##   godot --headless --fixed-fps 60 -s res://tools/tower/probe.gd                 (rules only)
##   xvfb-run godot --path . --fixed-fps 60 -s res://tools/tower/probe.gd -- <out_dir>

var out := ""
var f := 0
var room: TrainingRoom
var p: Player
var tw: TowerDirector
var steps: Array = []
var errors: Array = []
var _splitter0 := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.set("show_title", false)
	GameFlow.area = "turm"
	GameFlow.mode = GameFlow.DUNGEON
	change_scene_to_file("res://scenes/main.tscn")
	var t := 40
	steps = [
		[t, "setup"], [t + 10, "shot:turm_01_eingang"], [t + 20, "walk_in"], [t + 30, "check_floor1"],
		[t + 90, "shot:turm_02_etage1"], [t + 100, "clear"], [t + 106, "check_cleared"],
		[t + 260, "check_floor2"],
		[t + 270, "goto:5"], [t + 276, "clear"], [t + 420, "check_guard5"], [t + 500, "near_guard"], [t + 520, "shot:turm_03_turmwache"],
		[t + 530, "kill_guard"], [t + 540, "check_guard_loot"], [t + 600, "shot:turm_04_etage_geschafft"],
		[t + 700, "goto:12"], [t + 706, "clear"], [t + 850, "check_floor12"], [t + 920, "shot:turm_05_etage12"],
		[t + 930, "goto:15"], [t + 936, "clear"], [t + 1080, "check_guard15"],
		[t + 1090, "ko"], [t + 1096, "check_over"], [t + 1110, "shot:turm_06_lauf_vorbei"],
		[t + 1300, "check_reset"],
		[t + 1310, "overworld"], [t + 1400, "hide"], [t + 1420, "shot:turm_07_tore_im_hof"],
		[t + 1430, "quit"],
	]


func _process(_delta: float) -> bool:
	f += 1
	if room != null and is_instance_valid(room):
		# kill slow motions run on the wall clock; the test runs faster than real time
		room._slow_until = 0
		Engine.time_scale = 1.0
	if p != null and is_instance_valid(p) and tw != null and tw.state != "over" and not _ko:
		p.hp = p.max_hp
	for s in steps:
		if s[0] == f:
			_do(s[1])
	return false


var _ko := false


func _expect(ok: bool, what: String) -> void:
	if ok:
		print("TURM ok: ", what)
	else:
		print("TURM FEHLER: ", what)
		errors.append(what)


func _living() -> Array:
	return tw.alive.filter(func(e): return is_instance_valid(e) and e.state != "dead")


func _do(cmd: String) -> void:
	var parts := cmd.split(":")
	match parts[0]:
		"setup":
			_hide_select(root)
			paused = false
			room = _find_room(root)
			_expect(room != null and room.is_tower and room.tower != null, "Turm startet mit TowerDirector")
			_expect(room.waves == null and room.post == null and not room.is_raid, "keine Wellen, kein Pfahl, kein Raid")
			p = room.player
			p.infinite_aura = true
			tw = room.tower
			_expect(tw.state == "wait" and tw.floor_no == 0, "Turm wartet am Eingang")
			_splitter0 = Profile.splitter
		"walk_in":
			p.global_position = Vector2(340, 299)
			p.facing = 1
		"check_floor1":
			var es := _living()
			_expect(tw.state == "fight" and tw.floor_no == 1, "Etage 1 beginnt beim Betreten")
			_expect(es.size() == TowerDirector.enemy_count(1), "Etage 1 hat %d Gegner" % es.size())
			var ok := true
			for e in es:
				ok = ok and is_equal_approx(e.max_hp, float(e.data.hp))
			_expect(ok, "Etage 1: Gegner mit normalen HP")
		"clear":
			for e in _living():
				if e is Boss:
					e._next_shield = e.shield_at.size()
				e.apply_damage(e.hp + 10.0)
		"check_cleared":
			_expect(tw.state == "cleared", "alle Gegner weg: Etage geschafft")
			_expect(Profile.splitter - _splitter0 >= 5 * tw.floor_no, "Splitter als Etagen-Lohn (+%d)" % (Profile.splitter - _splitter0))
			_expect(tw.best >= 1, "Rekord gespeichert (Etage %d)" % tw.best)
		"check_floor2":
			_expect(tw.state == "fight" and tw.floor_no == 2, "nach der Pause kommt Etage 2")
		"goto":
			tw.floor_no = int(parts[1]) - 1  # clearing the current floor then leads to floor N
			p.global_position = Vector2(340, 299)
		"check_guard5":
			_expect(tw.floor_no == 5 and tw.boss != null and tw.boss.label == "Turmwache", "Etage 5: Turmwache")
			var b := tw.boss
			var want := 2600.0 * 0.35 * TowerDirector.hp_mult(5) * RaidScaling.hp_factor()
			_expect(is_equal_approx(b.max_hp, want), "Turmwache-HP %d (Etage-Faktor)" % int(b.max_hp))
			_expect(b.shield_at.is_empty(), "vor Etage 15 ohne Schild-Phase")
			_expect(tw.is_fighting(), "Boss-Leiste aktiv")
		"kill_guard":
			_count_drops()
			for e in _living():
				if e is Boss:
					e._next_shield = e.shield_at.size()
				e.apply_damage(e.hp + 10.0)
		"check_guard_loot":
			_expect(tw.state == "cleared" and tw.run_items == 1, "Turmwache besiegt: Ausrüstung als Lohn")
			_expect(_count_drops() >= 1, "Beute liegt bereit")
		"check_floor12":
			var es := _living()
			_expect(tw.floor_no == 12 and es.size() == TowerDirector.enemy_count(12), "Etage 12 mit %d Gegnern" % es.size())
			var ok := es.size() > 0
			for e in es:
				ok = ok and is_equal_approx(e.max_hp, float(e.data.hp) * TowerDirector.hp_mult(12)) and e.dmg_mult > 1.7
			_expect(ok, "Etage 12: Gegner deutlich stärker (x%.2f HP)" % TowerDirector.hp_mult(12))
		"check_guard15":
			_expect(tw.floor_no == 15 and tw.boss != null and tw.boss.shield_at == [0.5], "Etage 15: Turmwache mit Schild-Phase")
		"ko":
			_ko = true
			p.hp = 1.0
			p.hurt_invuln = 0.0
			p.in_super = false
			p.dash_timer = 0.0
			p.blocking = false
			p.receive_hit(50.0, p.global_position.x + 40.0, null)
		"check_over":
			_expect(tw.state == "over" and _living().is_empty(), "K.o. beendet den Lauf")
			_expect(tw.best >= 14 and FileAccess.file_exists(TowerDirector.SAVE_PATH), "Rekord Etage %d gesichert" % tw.best)
		"check_reset":
			_ko = false
			_expect(tw.state == "wait" and tw.floor_no == 0, "Turm beginnt wieder bei Etage 1")
		"overworld":
			GameFlow.area = "akademie_hof"
			GameFlow.mode = GameFlow.OVERWORLD
			GameFlow.entry_door = "tor_glut"
			p = null
			tw = null
			change_scene_to_file("res://scenes/main.tscn")
		"hide":
			_hide_select(root)
			paused = false
		"near_guard":
			if tw.boss != null:
				p.global_position = Vector2(tw.boss.global_position.x - 150.0, 299)
				p.facing = 1
		"shot":
			_hide_select(root)
			_shot(parts[1])
		"quit":
			print("TURM-TEST OK" if errors.is_empty() else "TURM-TEST FEHLER: %s" % ", ".join(errors))
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
