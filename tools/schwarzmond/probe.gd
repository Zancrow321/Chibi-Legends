extends SceneTree
## Test drive for the fighting style Schwarzmond: starts the training forest
## with the style, casts every Zug and all three Meisterzüge and saves
## screenshots. Run (needs a display, e.g. xvfb-run):
##   godot --path . --fixed-fps 60 -s res://tools/schwarzmond/probe.gd -- <out_dir>

var out := "user://schwarzmond_shots"
var f := 0
var room: TrainingRoom
var p: Player
var g: MondCaster
var steps: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var look := CreatorCatalog.load_look()
	look["style"] = "schwarzmond"
	CreatorCatalog.save_look(look)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://style_schwarzmond.json"))
	GameFlow.area = "trainingswald"
	GameFlow.mode = GameFlow.DUNGEON
	GameFlow.combat_help_seen = true
	change_scene_to_file("res://scenes/main.tscn")
	var t := 40
	steps = [
		[t, "setup"],
		[t + 10, "cast:neutral"], [t + 26, "shot:01_mondschnitt"],
		[t + 80, "cast:forward"], [t + 98, "shot:02_mondsichel"],
		[t + 150, "cast:up"], [t + 160, "shot:03_aufsteigender_mond"],
		[t + 230, "cast:down"], [t + 262, "shot:04_fallender_mond"],
		[t + 320, "vollmond"], [t + 322, "cast:forward"], [t + 345, "shot:05_vollmond_sichel"],
		[t + 400, "spur"], [t + 402, "cast:neutral"], [t + 406, "queue_light"], [t + 416, "shot:06_schwarze_spur"],
		[t + 470, "abwehr"], [t + 472, "cast:neutral"], [t + 480, "shot:07_abwehr"],
		[t + 540, "super:blutmond"], [t + 560, "shot:08_grosses_bild"], [t + 620, "shot:09_blutmond_ladung"], [t + 650, "shot:10_blutmond_welle"],
		[t + 760, "shot:11_schattenlarve"], [t + 762, "shotzoom:11b_larve_nah"],
		[t + 1100, "super:neumond"], [t + 1170, "shot:12_neumond"],
		[t + 1260, "cast:neutral_reset"], [t + 1272, "shot:13_neumond_schnitt"],
		[t + 1400, "super:mondfinsternis"], [t + 1470, "shot:14_mondfinsternis"], [t + 1500, "shot:15_finsternis_schnitt"],
		[t + 1560, "shot:16_hud"],
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
			g = p.glut as MondCaster
			print("caster: ", g, " style: ", p.style.id)
			p.global_position = Vector2(420, 299)
			p.facing = 1
			p.infinite_aura = true
		"cast":
			p.global_position.x = 300 if parts[1] == "forward" else 420
			p.facing = 1
			for z in g.cooldowns:
				g.cooldowns[z] = 0.0
			var d := "neutral" if parts[1] == "neutral_reset" else parts[1]
			print("cast ", d, " -> ", g.cast(d), " ", g.zug_id)
		"vollmond":
			g.stage = 3
		"spur":
			p.style.loadout["neutral"] = "schwarze_spur"
		"abwehr":
			p.style.loadout["neutral"] = "entschlossene_abwehr"
		"queue_light":
			p._queued = "light"
		"super":
			p.style.loadout["neutral"] = "mondschnitt"
			p.global_position = Vector2(380, 299)
			p.style.super_variant = parts[1]
			p._use_meisterzug()
		"shot":
			root.get_texture().get_image().save_png(out.path_join(parts[1] + ".png"))
		"shotzoom":
			print("hair anchor offset: ", p.sprite.body._hair.global_position - p.global_position, " scale ", p.sprite.body._hair.global_scale)
			var img := root.get_texture().get_image()
			var cam := room.camera
			var xf := root.get_canvas_transform()
			var c: Vector2 = xf * (p.global_position + Vector2(0, -30))
			var rect := Rect2i(int(c.x) - 90, int(c.y) - 70, 180, 140).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			var crop := img.get_region(rect)
			crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
			crop.save_png(out.path_join(parts[1] + ".png"))
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
