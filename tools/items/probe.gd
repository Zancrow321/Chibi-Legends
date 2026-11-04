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
		[115, "reforge"], [130, "shot:03_umgeschmiedet"], [140, "quit"]]


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
