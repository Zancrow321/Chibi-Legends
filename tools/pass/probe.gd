extends SceneTree
## Test drive for Herausforderungen + Saison-Pass: fresh save, a few tracked
## events, both tabs, claiming. Screenshots into <out_dir>. Run:
##   xvfb-run godot --path . --fixed-fps 60 -s res://tools/pass/probe.gd -- <out_dir>

var out := "user://pass_shots"
var f := 0
var steps: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SeasonPass.SAVE))
	GameFlow.area = "akademie_hof"
	GameFlow.mode = GameFlow.OVERWORLD
	change_scene_to_file("res://scenes/main.tscn")
	steps = [
		[50, "events"], [60, "open"], [80, "shot:01_herausforderungen"],
		[90, "claim"], [100, "shot:02_abgeholt"],
		[110, "tab"], [130, "shot:03_pass"], [140, "claimall"], [160, "shot:04_pass_abgeholt"],
		[170, "premium"], [200, "shot:05_pass_premium"], [210, "quit"],
	]


func _screen() -> PassScreen:
	return get_nodes_in_group("season_pass")[0]


func _process(_delta: float) -> bool:
	f += 1
	for s in steps:
		if s[0] == f:
			_do(s[1])
	return false


func _do(cmd: String) -> void:
	var parts := cmd.split(":")
	match parts[0]:
		"events":
			for n in get_nodes_in_group("creator"):
				if n.visible:
					n.close(false)
			for i in 40:
				SeasonPass.track("kill")
			for ev in ["elite", "meisterzug", "meisterzug", "wave", "wave", "wave", "loot", "loot", "loot"]:
				SeasonPass.track(ev)
			SeasonPass.track("combo", 17)
			for i in 4:
				SeasonPass.track("reaction")
			SeasonPass.add_ep(3300)
		"open":
			_screen().open(0)
		"claim":
			_screen()._claim_all()
		"tab":
			_screen()._key(KEY_E)
		"claimall":
			_screen()._claim_all()
		"premium":
			_screen()._key(KEY_F9)
		"shot":
			root.get_texture().get_image().save_png(out.path_join(parts[1] + ".png"))
		"quit":
			print("Pass-Probe fertig: Stufe ", SeasonPass.tier(), " EP ", SeasonPass.ep)
			quit()
