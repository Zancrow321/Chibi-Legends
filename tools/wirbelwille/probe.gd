extends SceneTree
## Test drive for the fighting style Wirbelwille: starts the training forest
## with the style, casts every Zug (plain and verstärkt with marks), the
## alternatives with clones and all three Meisterzüge, saves screenshots.
## Run (needs a display):
##   xvfb-run godot --path . --fixed-fps 60 -s res://tools/wirbelwille/probe.gd -- <out_dir>

var out := "user://wirbelwille_shots"
var f := 0
var room: TrainingRoom
var p: Player
var g: WirbelCaster
var steps: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var look := CreatorCatalog.load_look()
	look["style"] = "wirbelwille"
	look["weapon"] = ""
	CreatorCatalog.save_look(look)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://style_wirbelwille.json"))
	GameFlow.area = "trainingswald"
	GameFlow.mode = GameFlow.DUNGEON
	GameFlow.combat_help_seen = true
	change_scene_to_file("res://scenes/main.tscn")
	var t := 40
	steps = [
		[t, "setup"],
		[t + 10, "cast:neutral"], [t + 24, "shot:01_wirbelansturm"],
		[t + 70, "cast:forward"], [t + 82, "shot:02_kreiselfaust_laden"], [t + 92, "shot:03_kreiselfaust_treffer"],
		[t + 150, "cast:up"], [t + 168, "shot:04_klon_aufsteiger"],
		[t + 240, "cast:down"], [t + 262, "shot:05_wirbelsturz"], [t + 280, "shot:06_wirbelsturz_aufprall"],
		[t + 340, "marks"], [t + 342, "hold"], [t + 343, "cast:neutral"], [t + 372, "shot:07_ansturm_klon"], [t + 380, "release"],
		[t + 420, "marks"], [t + 422, "hold"], [t + 423, "cast:forward"], [t + 438, "shot:08_kreiselfaust_verstaerkt"], [t + 450, "release"],
		[t + 500, "loadout:neutral:wechselhuelle"], [t + 502, "cast:neutral"], [t + 510, "counter"], [t + 520, "shot:09_wechselhuelle"],
		[t + 580, "loadout:forward:klonschleuder"], [t + 582, "cast:forward"], [t + 598, "follow"], [t + 604, "shot:10_klonschleuder"],
		[t + 660, "loadout:neutral:wirbelansturm"], [t + 661, "loadout:forward:kreiselfaust"],
		[t + 662, "alt:wirbelansturm:doppel"], [t + 664, "cast:neutral"], [t + 690, "shot:11_doppelter_auftakt"],
		[t + 740, "alt:kreiselfaust:gross"], [t + 742, "cast:forward"], [t + 772, "shot:12_grosse_kreiselfaust"], [t + 784, "shot:13_grosse_treffer"],
		[t + 840, "alt:wirbelsturz:kunai"], [t + 842, "cast:down"], [t + 860, "shot:14_kunai_regen"],
		[t + 900, "super:sturmrad"], [t + 960, "shot:15_sturmrad_form"], [t + 1000, "shot:16_sturmrad_flug"], [t + 1080, "shot:17_sturmrad_abschluss"],
		[t + 1200, "super:hundert_schatten"], [t + 1300, "shot:18_hundert_schatten"], [t + 1370, "shot:19_hundert_ende"],
		[t + 1480, "super:orkanmantel"], [t + 1540, "shot:20_orkanmantel"], [t + 1560, "alt:kreiselfaust:"], [t + 1562, "cast:forward"], [t + 1584, "shot:21_mantel_kreiselfaust"],
		[t + 1600, "shot:22_hud"],
		[t + 2040, "shot:23_mantel_ende"],
		[t + 2080, "quit"],
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
			g = p.glut as WirbelCaster
			print("caster: ", g, " style: ", p.style.id)
			p.global_position = Vector2(420, 299)
			p.facing = 1
			p.infinite_aura = true
		"cast":
			p.global_position.x = 330 if parts[1] == "forward" else 420
			p.facing = 1
			for z in g.cooldowns:
				g.cooldowns[z] = 0.0
			print("cast ", parts[1], " -> ", g.cast(parts[1]), " ", g.zug_id, " marks ", g.marks, " clones ", g.clone_count())
		"marks":
			g.marks = 3
		"hold":
			Input.action_press("special")
		"release":
			Input.action_release("special")
		"follow":
			g._follow = true
		"counter":
			print("counter -> ", g.try_counter(p.global_position.x + 30.0))
		"loadout":
			p.style.loadout[parts[1]] = parts[2]
		"alt":
			p.style.active_alt[parts[1]] = parts[2]
		"super":
			p.global_position = Vector2(380, 299)
			p.style.super_variant = parts[1]
			p._use_meisterzug()
		"shot":
			root.get_texture().get_image().save_png(out.path_join(parts[1] + ".png"))
		"quit":
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
