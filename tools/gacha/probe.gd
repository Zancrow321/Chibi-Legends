extends SceneTree
## Test drive for the Sternschrein: opens it in the courtyard, shows the rates,
## a 10-pull and a forced Legendär (pity) and saves screenshots. Run:
##   xvfb-run godot --path . --fixed-fps 60 -s res://tools/gacha/probe.gd -- <out_dir>

var out := "user://gacha_shots"
var f := 0
var steps: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Gacha.SAVE))
	GameFlow.area = "akademie_hof"
	GameFlow.mode = GameFlow.OVERWORLD
	change_scene_to_file("res://scenes/main.tscn")
	steps = [
		[60, "open"], [90, "shot:01_schrein"], [95, "banner:2"], [110, "shot:02_banner_bollwerk"],
		[115, "rates"], [125, "shot:03_chancen"], [130, "rates"],
		[140, "pull10"], [160, "shot:04_stern"], [222, "shot:05_ausbruch"], [300, "shot:06_karten"], [520, "shot:07_zehn"],
		[540, "next"], [550, "pity"], [552, "pull1"], [590, "shot:08_stern_gold"], [636, "shot:09_ausbruch_gold"],
		[660, "shot:10_cutin"], [800, "shot:11_cutin_spaet"], [900, "next"], [960, "shot:12_ergebnis"],
		[1000, "quit"],
	]


func _gacha() -> GachaScreen:
	return get_nodes_in_group("gacha")[0]


func _process(_delta: float) -> bool:
	f += 1
	for s in steps:
		if s[0] == f:
			_do(s[1])
	return false


func _do(cmd: String) -> void:
	var parts := cmd.split(":")
	match parts[0]:
		"open":
			for n in get_nodes_in_group("creator"):
				if n.visible:
					n.close(false)
			_gacha().open()
		"banner":
			_gacha()._pick(int(parts[1]))
		"rates":
			_gacha()._key(KEY_R)
		"pull10":
			_gacha()._pull(10)
		"pull1":
			_gacha()._pull(1)
		"next":
			_gacha()._advance()
			_gacha()._advance()
		"pity":
			Gacha.pity = Gacha.pity_max() - 1
			Gacha.guaranteed = true
			Gacha.crystals += 500
		"shot":
			root.get_texture().get_image().save_png(out.path_join(parts[1] + ".png"))
		"quit":
			print("Gacha-Probe fertig: ", Gacha.crystals, " Kristalle, besitzt ", Gacha.owned)
			quit()
