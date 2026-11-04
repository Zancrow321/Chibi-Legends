extends SceneTree
## Test drive for the fighting style Bollwerk: starts the training forest
## in the Bollwerk armor, casts every Zug and several alternatives, breaks
## the shield, empties the magazine and plays all three Meisterzüge and saves screenshots. Run (needs a display):
##   xvfb-run godot --path . --fixed-fps 60 -s res://tools/bollwerk/probe.gd -- <out_dir>

var out := "user://bollwerk_shots"
var f := 0
var room: TrainingRoom
var p: Player
var g: BollwerkCaster
var steps: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var look := CreatorCatalog.load_look()
	look["style"] = "bollwerk"
	look["weapon"] = "wachhund"
	for k in ["top", "pants", "shoes"]:
		look[k] = "bollwerk"
	look["hair"] = "bollwerk_helm"
	CreatorCatalog.save_look(look)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://style_bollwerk.json"))
	GameFlow.area = "trainingswald"
	GameFlow.mode = GameFlow.DUNGEON
	GameFlow.combat_help_seen = true
	change_scene_to_file("res://scenes/main.tscn")
	var t := 40
	steps = [
		[t, "setup"],
		[t + 10, "cast:neutral"], [t + 20, "shot:01_salve"],
		[t + 50, "cast:neutral"], [t + 58, "shot:02_salve_rhythmus"],
		[t + 90, "cast:forward"], [t + 104, "shot:03_durchbruch"],
		[t + 160, "cast:up"], [t + 180, "shot:04_granate_flug"], [t + 246, "shot:05_granate_explosion"],
		[t + 300, "air"], [t + 302, "cast:down"], [t + 318, "shot:06_orbitalsturz_zielen"], [t + 350, "shot:07_orbitalsturz_aufschlag"],
		[t + 420, "loadout:neutral:schildprotokoll"], [t + 422, "cast:neutral"], [t + 440, "shot:08_schutzwand"],
		[t + 500, "loadout:forward:kettenhaken"], [t + 502, "cast:forward"], [t + 510, "shot:09_kettenhaken"],
		[t + 580, "loadout:neutral:salve"], [t + 581, "loadout:forward:durchbruch"],
		[t + 582, "alt:durchbruch:fremdklinge"], [t + 584, "cast:forward"], [t + 598, "shot:10_fremdklinge"],
		[t + 650, "alt:salve:kurzwort"], [t + 652, "cast:neutral"], [t + 656, "shot:11_kurzwort"],
		[t + 700, "alt:salve:"], [t + 702, "shieldbreak"], [t + 708, "shot:12_schild_weg"],
		[t + 730, "cast:neutral"], [t + 760, "empty"], [t + 762, "cast:neutral"], [t + 770, "shot:13_leer_nachladen"],
		[t + 840, "super:zwillingsrohr"], [t + 880, "shot:14_visier"], [t + 925, "shot:15_rakete"], [t + 960, "shot:16_raketen_einschlag"],
		[t + 1060, "super:lanzenstrahl"], [t + 1140, "shot:17_zielstrahl"], [t + 1170, "shot:18_lanzenstrahl"],
		[t + 1280, "super:letzter_befehl"], [t + 1340, "shot:19_haken"], [t + 1370, "shot:20_kracks"], [t + 1392, "shot:21_schrot"],
		[t + 1500, "shot:22_hud"],
		[t + 1520, "quit"],
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
			g = p.glut as BollwerkCaster
			print("caster: ", g, " style: ", p.style.id)
			p.global_position = Vector2(420, 299)
			p.facing = 1
			p.infinite_aura = true
		"cast":
			if parts[1] != "down":
				p.global_position.x = 300 if parts[1] == "forward" else 420
			p.facing = 1
			for z in g.cooldowns:
				g.cooldowns[z] = 0.0
			print("cast ", parts[1], " -> ", g.cast(parts[1]), " ", g.zug_id, " phase ", g.phase, " ammo ", g.ammo, " energy ", g.energy, " shield ", g.shield)
		"air":
			p.global_position = Vector2(470, 200)
			p.velocity = Vector2.ZERO
		"shieldbreak":
			print("shield ", g.shield, " -> absorbed ", g.guard_hit(g.shield_max + 10.0, 200.0, null), " now ", g.shield)
		"empty":
			g.ammo = 0
			g.reload_t = 0.0
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
