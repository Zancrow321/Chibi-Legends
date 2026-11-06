extends SceneTree
## Test drive for the gear: fresh profile with items of every kind and
## rarity, equips them, reforges one in the courtyard, screenshots the
## Charakter and Inventar tabs. Run:
##   xvfb-run godot --path . --fixed-fps 60 -s res://tools/items/probe.gd -- <out_dir>

var out := "user://items_shots"
var f := 0
var steps: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameFlow.area = "akademie_hof"
	GameFlow.mode = GameFlow.OVERWORLD
	change_scene_to_file("res://scenes/main.tscn")
	steps = [[50, "fill"], [60, "open:0"], [80, "shot:01_charakter"], [90, "open:1"], [110, "shot:02_inventar"],
		[115, "reforge"], [130, "shot:03_umgeschmiedet"],
		[135, "extras"], [140, "open:1"], [150, "pick_legend"], [165, "shot:04_legendaer_mod"],
		[170, "pick_set"], [180, "socket"], [195, "shot:05_set_sockel"],
		[200, "open:2"], [215, "shot:06_steine"], [220, "open:0"], [235, "shot:07_charakter_sets"], [240, "quit"]]


func _menu() -> GameMenu:
	return get_nodes_in_group("game_menu")[0]


func _index_of(pred: Callable) -> int:
	for i in Profile.items.size():
		if pred.call(Profile.items[i]):
			return i
	return 0


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
			Profile.level = 8
			Profile.splitter = 900
			var i := 0
			for k in Profile.KINDS:
				Profile.add_item(Loot.roll(8, i % 4, k))
				i += 1
			Profile.add_item(Loot.roll(8, 3, "talisman"))
			for it in Profile.items.duplicate():
				Profile.toggle_equip(it.uid)
			for j in 8:
				Profile.add_item(Loot.roll(8, -1))
			print("Plätze: ", Profile.equipped)
		"extras":
			Gems.reset()
			for g in ["rubin_1", "rubin_1", "rubin_1", "rubin_2", "smaragd_1", "topas_3", "saphir_2", "amethyst_1", "onyx_2", "onyx_1"]:
				Gems.add(g)
			var legend := Loot.roll(8, 3, "waffe", "glutatem")
			legend["mod"] = "esse_atem"
			legend["sockets"] = ["topas_3", ""]
			Profile.add_item(legend)
			Profile.toggle_equip(legend.uid)
			for k in ["oberteil", "hose", "schuhe", "accessoire"]:
				var piece := Loot.roll(8, 2, k)
				ItemSets.make_piece(piece, "glutschmied")
				Profile.add_item(piece)
				Profile.toggle_equip(piece.uid)
			var other := Loot.roll(8, 3, "talisman", "bollwerk")
			other["mod"] = "panzerkammer"
			Profile.add_item(other)
			Profile.toggle_equip(other.uid)
		"pick_legend":
			_menu()._sel = _index_of(func(it): return str(it.get("mod", "")) == "esse_atem")
		"pick_set":
			_menu()._sel = _index_of(func(it): return it.has("set") and Loot.free_socket(it) >= 0)
		"socket":
			_menu()._gsel = 3  # Rubin, Geschliffen
			_menu()._socket_selected()
		"open":
			_menu().open(int(parts[1]))
			_menu()._set_tab(int(parts[1]))
		"reforge":
			_menu()._sel = 3
			_menu()._reforge_selected()
		"shot":
			root.get_texture().get_image().save_png(out.path_join(parts[1] + ".png"))
		"quit":
			print("Gear-Probe fertig: Splitter ", Profile.splitter, " Bonus def ", Profile.bonus("def"), " critdmg ", Profile.bonus("critdmg"))
			quit()
