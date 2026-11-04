extends SceneTree
## Test drive for the fighting style Grenzbrecher: starts the training forest
## with the style, casts every Zug, a charged Kernstrahl, Ki sammeln,
## the Ki-Mangel palm push and all three Meisterzüge and saves screenshots. Run (needs a display):
##   xvfb-run godot --path . --fixed-fps 60 -s res://tools/grenzbrecher/probe.gd -- <out_dir>

var out := "user://grenzbrecher_shots"
var f := 0
var room: TrainingRoom
var p: Player
var g: GrenzCaster
var steps: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var look := CreatorCatalog.load_look()
	look["style"] = "grenzbrecher"
	look["weapon"] = ""
	look["top"] = "steilpfad"
	look["pants"] = "steilpfad"
	look["shoes"] = "steilpfad"
	CreatorCatalog.save_look(look)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://style_grenzbrecher.json"))
	GameFlow.area = "trainingswald"
	GameFlow.mode = GameFlow.DUNGEON
	GameFlow.combat_help_seen = true
	change_scene_to_file("res://scenes/main.tscn")
	var t := 40
	steps = [
		[t, "setup"],
		[t + 10, "cast:neutral"], [t + 24, "shot:01_steilpfad_folge"],
		[t + 70, "hold"], [t + 72, "cast:forward"], [t + 110, "shot:02_kernstrahl_laden"], [t + 134, "shot:03_kernstrahl"], [t + 136, "release"],
		[t + 180, "cast:up"], [t + 190, "shot:04_himmelsauftakt"],
		[t + 260, "air"], [t + 262, "cast:down"], [t + 276, "shot:05_meteor"],
		[t + 330, "loadout:neutral:ruhiger_gegenschlag"], [t + 332, "cast:neutral"], [t + 340, "counter"], [t + 346, "shot:06_gegenschlag"],
		[t + 400, "loadout:forward:fernschritt"], [t + 402, "cast:forward"], [t + 426, "shot:07_fernschritt"],
		[t + 470, "loadout:neutral:steilpfad_folge"], [t + 471, "loadout:forward:kernstrahl"],
		[t + 480, "gather"], [t + 530, "shot:08_sammeln"], [t + 560, "ungather"],
		[t + 580, "alt:kernstrahl:verdichtet"], [t + 582, "hold"], [t + 584, "cast:forward"], [t + 668, "shot:09_verdichtet"], [t + 670, "release"],
		[t + 720, "alt:kernstrahl:"], [t + 721, "noki"], [t + 722, "cast:forward"], [t + 740, "shot:10_kimangel"],
		[t + 800, "super:grenzbruch"], [t + 850, "shot:11_grenzbruch_intro"], [t + 880, "shot:12_grenzbruch"], [t + 920, "cast:neutral"], [t + 934, "shot:13_grenzbruch_folge"],
		[t + 1100, "super:fernstrahl"], [t + 1180, "shot:14_fernstrahl_ziel"], [t + 1210, "shot:15_fernstrahl"],
		[t + 1320, "super:sonnenkern"], [t + 1420, "shot:16_sonnenkern_laden"], [t + 1500, "shot:17_sonnenkern_voll"], [t + 1540, "shot:18_sonnenkern_einschlag"],
		[t + 1560, "shot:19_hud"],
		[t + 1600, "quit"],
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
			g = p.glut as GrenzCaster
			print("caster: ", g, " style: ", p.style.id)
			p.global_position = Vector2(420, 299)
			p.facing = 1
			p.infinite_aura = true
		"cast":
			p.global_position.x = 300 if parts[1] == "forward" else 420
			p.facing = 1
			for z in g.cooldowns:
				g.cooldowns[z] = 0.0
			print("cast ", parts[1], " -> ", g.cast(parts[1]), " ", g.zug_id, " phase ", g.phase)
		"hold":
			Input.action_press("special")
		"release":
			print("ki ", g.ki, " zug ", g.zug_id, " phase ", g.phase)
			Input.action_release("special")
		"air":
			p.global_position = Vector2(420, 230)
			p.velocity = Vector2.ZERO
		"counter":
			print("counter -> ", p.receive_hit(10.0, p.global_position.x + 30.0), " phase ", g.phase)
		"gather":
			p.global_position = Vector2(380, 299)
			Input.action_press("move_down")
		"ungather":
			print("ki after gather ", g.ki)
			Input.action_release("move_down")
		"noki":
			g.ki = 5.0
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
