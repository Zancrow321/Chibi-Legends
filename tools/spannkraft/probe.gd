extends SceneTree
## Test drive for the fighting style Spannkraft: starts the training forest
## with the style, casts every Zug (tapped and voll gespannt), a Rückschwung
## and all three Meisterzüge and saves screenshots. Run (needs a display):
##   xvfb-run godot --path . --fixed-fps 60 -s res://tools/spannkraft/probe.gd -- <out_dir>

var out := "user://spannkraft_shots"
var f := 0
var room: TrainingRoom
var p: Player
var g: FederCaster
var steps: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var look := CreatorCatalog.load_look()
	look["style"] = "spannkraft"
	look["weapon"] = ""
	CreatorCatalog.save_look(look)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://style_spannkraft.json"))
	GameFlow.area = "trainingswald"
	GameFlow.mode = GameFlow.DUNGEON
	GameFlow.combat_help_seen = true
	change_scene_to_file("res://scenes/main.tscn")
	var t := 40
	steps = [
		[t, "setup"],
		[t + 10, "cast:neutral"], [t + 18, "shot:01_schnappfaust"],
		[t + 60, "hold"], [t + 62, "cast:neutral"], [t + 110, "shot:02_spannen_voll"], [t + 112, "release"], [t + 118, "shot:03_schnappfaust_voll"],
		[t + 170, "cast:forward"], [t + 184, "shot:04_fegebein"],
		[t + 240, "cast:up"], [t + 254, "shot:05_katapult"],
		[t + 330, "cast:down"], [t + 352, "shot:06_fallbeilferse"],
		[t + 420, "loadout:neutral:prallbauch"], [t + 422, "cast:neutral"], [t + 432, "shot:07_prallbauch"],
		[t + 480, "loadout:forward:spannzug"], [t + 482, "cast:forward"], [t + 494, "shot:08_spannzug"],
		[t + 540, "loadout:neutral:schnappfaust"], [t + 541, "loadout:forward:fegebein"],
		[t + 542, "alt:schnappfaust:prassel"], [t + 544, "cast:neutral"], [t + 560, "shot:09_prasselfaust"],
		[t + 620, "alt:schnappfaust:"], [t + 622, "cast:neutral"], [t + 632, "swing:up"], [t + 634, "unswing"], [t + 646, "shot:10_rueckschwung"],
		[t + 720, "super:dampfhagel"], [t + 770, "shot:11_siedepuls"], [t + 840, "shot:12_dampfhagel"], [t + 880, "shot:13_dampfhagel_ende"],
		[t + 960, "super:federkanone"], [t + 1060, "shot:14_prallform"], [t + 1094, "shot:15_federkanone"],
		[t + 1200, "super:grenzenlos"], [t + 1250, "shot:16_grenzenlos"], [t + 1280, "cast:neutral"], [t + 1290, "shot:17_frei_schnapp"],
		[t + 1300, "shot:18_hud"], [t + 1400, "bowl"], [t + 1402, "cast:neutral"], [t + 1418, "shot:20_rumms"], [t + 1430, "release"],
		[t + 1760, "shot:19_finale"],
		[t + 1800, "quit"],
	]


func _process(_delta: float) -> bool:
	f += 1
	if OS.get_environment("PROBE_DEBUG") != "" and f >= 672 and f <= 690 and g != null:
		print(f, " ", g.zug_id, " ", g.phase, " t=", snappedf(g.t, 0.01), " snap=", snappedf(g._snap_t, 0.01), " chain=", g.chain_left, " just=", Input.is_action_just_pressed("special"), " pressed=", Input.is_action_pressed("special"))
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
			g = p.glut as FederCaster
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
			print("tension ", g.tension)
			Input.action_release("special")
		"swing":
			Input.action_press("move_up")
			_send("special", true)
		"unswing":
			_send("special", false)
			Input.action_release("move_up")
			print("swing -> ", g.zug_id, " chain ", g.chain_left, " transfer ", g._transfer)
		"bowl":
			# two dummies close together: a strong hit throws one into the other
			p.global_position.x = 420
			Input.action_press("special")
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


## A real input event (sets "just pressed" for the physics frame, unlike action_press).
func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


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
