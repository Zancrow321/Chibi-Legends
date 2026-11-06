extends SceneTree
## Test drive for the first raid (Glutschmiede, boss Essenwächter): wakes
## the boss, drains the Wucht-Leiste to a Bruch, pushes it into both shield
## phases (crystals broken / time ran out), lets it use every attack,
## knocks the player out once and finally beats the boss. Checks the rules
## on the way and prints RAID-TEST OK or RAID-TEST FEHLER.
##   godot --headless -s res://tools/raid/probe.gd                       (rules only)
##   xvfb-run godot --path . --fixed-fps 60 -s res://tools/raid/probe.gd -- <out_dir> [b64]
## With a display it saves screenshots; "b64" also prints them as small JPEGs
## into the log (IMG lines), so they can be read without the artifact.

var out := ""
var b64 := false
var f := 0
var room: TrainingRoom
var p: Player
var boss: Boss
var steps: Array = []
var errors: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	b64 = args.has("b64")
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.set("show_title", false)
	GameFlow.area = "glutschmiede"
	GameFlow.mode = GameFlow.DUNGEON
	change_scene_to_file("res://scenes/main.tscn")
	var t := 40
	steps = [
		[t, "setup"], [t + 20, "check_sleep"], [t + 22, "walk_in"], [t + 60, "shot:01_erwacht"],
		[t + 120, "attack:slam"], [t + 168, "shot:02_hammerschlag"], [t + 200, "shot:03_schockwellen"],
		[t + 260, "drain"], [t + 266, "check_bruch"], [t + 280, "shot:04_bruch"],
		[t + 560, "check_bruch_over"],
		[t + 570, "hp:0.69"], [t + 575, "check_shield"], [t + 640, "shot:05_glutschild_kristalle"],
		[t + 650, "crystals"], [t + 656, "check_shield_broken"], [t + 670, "shot:06_schild_gebrochen"],
		[t + 930, "attack:rain"], [t + 1010, "shot:07_glutregen"],
		[t + 1150, "attack:charge"], [t + 1205, "shot:08_ansturm"],
		[t + 1300, "hp:0.34"], [t + 1305, "timeout"], [t + 1330, "check_flood"], [t + 1425, "shot:09_essensturm"],
		[t + 1560, "attack:swipe"], [t + 1600, "shot:10_glutschwung"],
		[t + 1700, "ko"], [t + 1704, "check_ko"], [t + 1820, "check_respawn"],
		[t + 1830, "walk_in"], [t + 1900, "kill"], [t + 1990, "shot:11_raid_geschafft"], [t + 2000, "check_won"],
		[t + 2010, "quit"],
	]


func _process(_delta: float) -> bool:
	f += 1
	if p != null and is_instance_valid(p):
		p.hp = p.max_hp  # the test player only falls when the KO step wants it
	for s in steps:
		if s[0] == f:
			_do(s[1])
	return false


func _expect(ok: bool, what: String) -> void:
	if ok:
		print("RAID ok: ", what)
	else:
		print("RAID FEHLER: ", what)
		errors.append(what)


func _boss() -> Boss:
	var b: Boss = room.raid.boss
	return b if b != null and is_instance_valid(b) else null


func _do(cmd: String) -> void:
	var parts := cmd.split(":")
	match parts[0]:
		"setup":
			_hide_select(root)
			paused = false
			room = _find_room(root)
			_expect(room != null and room.is_raid and room.raid != null, "Glutschmiede startet als Raid")
			_expect(room.waves == null and room.post == null, "keine Wellen und kein Sparringspfahl im Raid")
			p = room.player
			p.infinite_aura = true
			boss = _boss()
			_expect(boss != null and boss.label == "Essenwächter", "Boss Essenwächter steht in der Arena")
			_expect(is_equal_approx(boss.max_hp, 2600.0 * RaidScaling.hp_factor()), "Boss-HP skaliert (%d)" % int(boss.max_hp))
		"check_sleep":
			_expect(boss.state == "sleep" and not room.raid.is_fighting(), "Boss schläft bis der Spieler eintritt")
		"walk_in":
			boss = _boss()
			p.global_position = Vector2(420, 299)
			p.facing = 1
		"attack":
			boss = _boss()
			p.global_position = Vector2(boss.global_position.x - (90.0 if parts[1] != "charge" and parts[1] != "rain" else 300.0), 299)
			p.facing = 1
			p.hp = p.max_hp
			boss.facing = -1
			boss._begin(parts[1])
		"drain":
			boss = _boss()
			boss._enter("idle")
			boss.attack = ""
			boss.wucht_locked = false
			var hits := 0
			while boss.bruch <= 0.0 and hits < 200:
				room.deal_hit(boss, 20.0, "", boss.global_position.x - 40.0, 140.0, "heavy")
				hits += 1
			print("RAID info: Bruch nach ", hits, " schweren Treffern")
			_expect(hits > 6 and hits < 60, "Wucht-Leiste hält ein paar Treffer aus (%d)" % hits)
		"check_bruch":
			room.combo = 0
			room.combo_time = 99.0
			_expect(boss.is_broken() and boss.damage_factor() == 1.5, "Bruch: Boss taumelt, +50 % Schaden")
			var hp0 := boss.hp
			room.deal_hit(boss, 100.0, "", boss.global_position.x - 40.0, 60.0, "light")
			_expect(hp0 - boss.hp > 120.0, "Treffer im Bruch machen mehr Schaden (%d)" % int(hp0 - boss.hp))
		"check_bruch_over":
			_expect(not boss.is_broken() and boss.wucht >= boss.wucht_max * 0.99, "Bruch endet, Wucht ist wieder voll")
		"hp":
			boss = _boss()
			boss.apply_damage(boss.hp - boss.max_hp * float(parts[1]))
		"check_shield":
			_expect(boss.shielded and boss.crystals.size() == RaidScaling.crystals(), "Glutschild mit %d Kristallen" % boss.crystals.size())
			var hp0 := boss.hp
			room.deal_hit(boss, 200.0, "", boss.global_position.x - 40.0, 60.0, "light")
			_expect(boss.hp == hp0, "Schild blockt jeden Schaden")
		"crystals":
			var n := 0
			for c in boss.crystals.duplicate():
				room.deal_hit(c, 400.0, "", c.global_position.x - 20.0, 60.0, "heavy")
				n += 1
			print("RAID info: ", n, " Kristalle zerschlagen")
		"check_shield_broken":
			_expect(not boss.shielded and boss.is_broken() and boss.phase == 2, "alle Kristalle weg: Schild bricht, Bruch, Phase 2")
		"timeout":
			_expect(boss.shielded, "zweiter Schild bei 35 %")
			boss.shield_left = 0.01
			p.global_position = Vector2(405, 190)  # on the platform
		"check_flood":
			_expect(not boss.shielded and boss.attack == "essensturm" and boss.phase == 3, "Zeit um: Essensturm, Phase 3")
		"ko":
			boss = _boss()
			p.global_position = Vector2(boss.global_position.x - 60.0, 299)
			p.hp = 1.0
			p.hurt_invuln = 0.0
			p.in_super = false
			p.dash_timer = 0.0
			p.blocking = false
			p.receive_hit(50.0, boss.global_position.x, boss)
		"check_ko":
			_expect(room.raid.attempts == 2 and room.raid.boss == null and p.hp == p.max_hp, "K.o.: neuer Versuch, volle HP")
		"check_respawn":
			boss = _boss()
			_expect(boss != null and boss.hp == boss.max_hp and boss.phase == 1, "Boss steht neu und voll da")
		"kill":
			boss = _boss()
			boss._next_shield = Boss.SHIELD_AT.size()
			boss.apply_damage(boss.hp + 10.0)
		"check_won":
			_expect(room.raid.won, "Boss besiegt, Raid geschafft")
			var drops := 0
			for c in room.get_children():
				if c is LootDrop:
					drops += 1
			_expect(drops >= 3, "Beute liegt bereit (%d Teile)" % drops)
		"shot":
			_shot(parts[1])
		"quit":
			print("RAID-TEST OK" if errors.is_empty() else "RAID-TEST FEHLER: %s" % ", ".join(errors))
			quit()


func _shot(name: String) -> void:
	if out == "" or DisplayServer.get_name() == "headless":
		return
	var img := root.get_texture().get_image()
	if img == null:
		return
	img.save_png(out.path_join(name + ".png"))
	if b64:
		var small := img.duplicate() as Image
		small.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_NEAREST)
		var data := Marshalls.raw_to_base64(small.save_jpg_to_buffer(0.8))
		var i := 0
		while i < data.length():
			print("IMG %s %s" % [name, data.substr(i, 4000)])
			i += 4000


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
