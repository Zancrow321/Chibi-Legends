extends SceneTree
## Test drive for the fighting style Lauffeuer: starts the training forest
## with the style and the Feuerwacht outfit, casts every Zug, a Brandherd
## chain and all three Meisterzüge and saves screenshots. Run (needs a
## display, e.g. xvfb-run):
##   godot --path . --fixed-fps 60 -s res://tools/lauffeuer/probe.gd -- <out_dir>

var out := "user://lauffeuer_shots"
var f := 0
var room: TrainingRoom
var p: Player
var g: FeuerCaster
var steps: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var look := CreatorCatalog.load_look()
	look["style"] = "lauffeuer"
	for s in ["top", "pants", "shoes"]:
		look[s] = "feuerwacht"
	CreatorCatalog.save_look(look)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://style_lauffeuer.json"))
	GameFlow.area = "trainingswald"
	GameFlow.mode = GameFlow.DUNGEON
	GameFlow.combat_help_seen = true
	change_scene_to_file("res://scenes/main.tscn")
	var t := 40
	steps = [
		[t, "setup"],
		[t + 10, "cast:neutral"], [t + 30, "shot:01_flammenknoechel"],
		[t + 80, "herde"], [t + 90, "shot:02_brandherde"],
		[t + 100, "cast:forward"], [t + 118, "shot:03_flammenfaust"], [t + 128, "shot:04_kettenzuendung"], [t + 140, "shot:05_kette_2"],
		[t + 200, "cast:up"], [t + 214, "shot:06_steigflamme"],
		[t + 280, "cast:down"], [t + 296, "shot:07_niederschlag"],
		[t + 350, "alt:down:faecher"], [t + 352, "jump"], [t + 368, "cast:down_air"], [t + 384, "shot:08_feuerfaecher"],
		[t + 440, "slot:forward:feuerstrom"], [t + 442, "cast:forward"], [t + 452, "shot:09_feuerstrom"],
		[t + 500, "slot:neutral:flammenleib"], [t + 502, "cast:neutral"], [t + 508, "shot:10_flammenleib"],
		[t + 560, "alt:flammenleib:schirm"], [t + 562, "cast:neutral"], [t + 582, "shot:11_feuerschirm"],
		[t + 640, "reset"], [t + 650, "herde"], [t + 660, "super:grosser_brand"], [t + 680, "shot:12_intro_signalturm"], [t + 718, "shot:13_grosser_brand"], [t + 740, "shot:14_grosser_brand_kette"],
		[t + 900, "super:brandgestirn"], [t + 990, "shot:15_brandgestirn_laden"], [t + 1040, "shot:16_brandgestirn_flug"], [t + 1050, "shot:17_brandgestirn_einschlag"],
		[t + 1200, "herde"], [t + 1210, "super:leuchtfeuer"], [t + 1290, "shot:18_leuchtfeuer_flocken"], [t + 1356, "shot:19_leuchtfeuer_zuendung"],
		[t + 1420, "shot:20_hud"],
		[t + 1440, "quit"],
	]


func _process(_delta: float) -> bool:
	f += 1
	for s in steps:
		if s[0] == f:
			_do(s[1])
	return false


func _do(cmd: String) -> void:
	var parts := cmd.split(":")
	match parts[0]:
		"setup":
			_hide_select(root)
			paused = false
			room = _find_room(root)
			p = room.player
			g = p.glut as FeuerCaster
			print("caster: ", g, " style: ", p.style.id)
			p.global_position = Vector2(420, 299)
			p.facing = 1
			p.infinite_aura = true
		"cast":
			if parts[1] != "down_air":
				p.global_position.x = 380 if parts[1] == "forward" else 420
			p.facing = 1
			for z in g.cooldowns:
				g.cooldowns[z] = 0.0
			var d := "down" if parts[1] == "down_air" else parts[1]
			print("cast ", d, " -> ", g.cast(d), " ", g.zug_id)
		"herde":
			for x in [470, 520, 570]:
				g.place_herd(x)
		"jump":
			p.velocity.y = -420.0
		"alt":
			var z := str(p.style.loadout.get(parts[1], parts[1]))
			p.style.set_alt(z, parts[2])
		"slot":
			p.style.assign(parts[2], parts[1])
		"reset":
			p.style.assign("flammenknoechel", "neutral")
			p.style.assign("flammenfaust", "forward")
			p.global_position = Vector2(380, 299)
		"super":
			p.global_position = Vector2(380, 299)
			p.facing = 1
			p.style.super_variant = parts[1]
			p._use_meisterzug()
		"shot":
			root.get_texture().get_image().save_png(out.path_join(parts[1] + ".png"))
		"quit":
			print("herde: ", g.herd_count())
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
