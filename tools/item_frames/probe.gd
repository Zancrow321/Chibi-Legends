extends SceneTree
## Pictures of the rarity frames in the game menu and the Beute-Leiste:
##   xvfb-run godot --path . --fixed-fps 60 -s res://tools/item_frames/probe.gd -- <out_dir>
## CI pushes the PNGs to the branch ci-bilder/rahmen.

var out := "user://rahmen_shots"
var f := 0
var steps: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameFlow.area = "akademie_hof"
	GameFlow.mode = GameFlow.OVERWORLD
	load("res://scripts/main.gd").show_title = false
	change_scene_to_file("res://scenes/main.tscn")
	steps = [[50, "fill"], [60, "open:1"], [70, "sel:0"], [80, "shot:01_inventar_mythisch"],
		[84, "sel:1"], [92, "shot:02_legendaer"], [96, "sel:2"], [104, "shot:03_episch"],
		[108, "sel:3"], [116, "shot:04_selten"], [120, "sel:5"], [128, "shot:05_gewoehnlich"],
		[130, "sel:0"], [131, "up"], [132, "up"], [133, "up"], [134, "lock"], [140, "shot:06_aufgewertet_gesperrt"],
		[145, "open:0"], [160, "shot:07_charakter"], [165, "bulk"], [166, "bulk"], [170, "open:1"], [180, "shot:08_nach_sammeln"],
		[184, "close"], [186, "fight"], [300, "feed"], [312, "shot:09_beute_leiste"], [330, "shot:10_beute_leiste_spaeter"], [340, "quit"]]


func _menu() -> GameMenu:
	return get_nodes_in_group("game_menu")[0]


func _process(_delta: float) -> bool:
	f += 1
	for s in steps:
		if s[0] == f:
			_do(s[1])
	return false


func _do(cmd: String) -> void:
	var parts := cmd.split(":")
	match parts[0]:
		"fill":
			for n in get_nodes_in_group("creator"):
				if n.visible:
					n.close(false)
			Profile.reset()
			Profile.level = 12
			Profile.splitter = 5000
			var kinds := ["waffe", "oberteil", "talisman", "schuhe", "hose", "accessoire"]
			for r in range(Loot.MYTHIC, -1, -1):
				Profile.add_item(Loot.roll(12, r, kinds[Loot.MYTHIC - r], "glutatem"))
			for r in [0, 0, 1, 1, 2, 3, 1, 0]:
				Profile.add_item(Loot.roll(6, r))
			for it in Profile.items.slice(0, 6):
				Profile.toggle_equip(it.uid)
		"open":
			_menu().open(int(parts[1]))
			_menu()._set_tab(int(parts[1]))
		"sel":
			_menu()._sel = int(parts[1])
		"up":
			_menu()._upgrade_selected()
		"lock":
			_menu()._lock_selected()
		"bulk":
			_menu()._salvage_bulk()
		"close":
			_menu().close()
		"fight":
			GameFlow.area = "trainingswald"
			GameFlow.mode = GameFlow.DUNGEON
			load("res://scripts/main.gd").show_title = false
			change_scene_to_file("res://scenes/main.tscn")
		"feed":
			for n in get_nodes_in_group("creator"):
				if n.visible:
					n.close(false)
			_hide_select(root)
			paused = false
			var room := _find_room(root)
			if room == null:
				print("RAHMEN: kein Kampfraum gefunden")
				return
			room._slow_until = 0
			Engine.time_scale = 1.0
			for r in [Loot.RARE, Loot.EPIC, Loot.LEGENDARY, Loot.MYTHIC]:
				room.loot_feed_add(Loot.roll(10, r, "", "glutatem"))
		"shot":
			root.get_texture().get_image().save_png(out.path_join(parts[1] + ".png"))
			print("RAHMEN: Bild ", parts[1])
		"quit":
			print("RAHMEN: fertig, Splitter ", Profile.splitter)
			quit()


func _hide_select(n: Node) -> void:
	if n is CharacterSelect:
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
