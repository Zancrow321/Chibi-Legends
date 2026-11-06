extends SceneTree
## Test drive for the fighting style Gleichklang (PixelLab-Effekte): starts the training forest
## with the style, casts every Zug and all three Meisterzüge and saves
## screenshots. Run (needs a display, e.g. xvfb-run):
##   godot --path . --fixed-fps 60 -s res://tools/gleichklang/probe.gd -- <out_dir>

var out := "user://gleichklang_shots"
var f := 0
var room: TrainingRoom
var p: Player
var g: KlangCaster
var steps: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var look := CreatorCatalog.load_look()
	look["style"] = "gleichklang"
	look["weapon"] = "sense_nachhall"
	CreatorCatalog.save_look(look)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://style_gleichklang.json"))
	GameFlow.area = "trainingswald"
	GameFlow.mode = GameFlow.DUNGEON
	load("res://scripts/main.gd").show_title = false
	change_scene_to_file("res://scenes/main.tscn")
	var t := 40
	steps = [
		[t, "setup"],
		[t + 8, "shotzoom:00_katana_nah"],
		[t + 12, "light"], [t + 26, "shot:01_schnitt_quer"],
		[t + 50, "light"], [t + 62, "light"], [t + 74, "light"], [t + 80, "light"], [t + 88, "shot:02_schnitt_stich"],
		[t + 110, "heavy_up"], [t + 138, "shot:03_schnitt_hoch"],
		[t + 170, "cast:neutral"], [t + 196, "shot:04_sicheltakt"],
		[t + 250, "cast:forward"], [t + 268, "shot:05_seelensichel"],
		[t + 330, "cast:up"], [t + 342, "shot:06_himmelsreigen"],
		[t + 400, "schritt"], [t + 402, "cast:neutral"], [t + 412, "shot:07_sichelschritt"],
		[t + 470, "lauschen"], [t + 472, "cast:neutral"], [t + 486, "counter"], [t + 492, "shot:08_seelenlauschen"],
		[t + 560, "jump"], [t + 580, "cast:down"], [t + 640, "shot:09_fallende_sichel"],
		[t + 720, "super:erntebogen"], [t + 755, "shot:10_meisterzug"], [t + 820, "shot:11_erntebogen"],
		[t + 1000, "super:totengelaeut"], [t + 1125, "shot:12_totengelaeut"],
		[t + 1300, "super:reiner_klang"], [t + 1362, "shot:13_reiner_klang"], [t + 1480, "shot:14_reiner_klang_ring"],
		[t + 1560, "quit"],
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
			g = p.glut as KlangCaster
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
		"light":
			p._queued = "light"
		"heavy_up":
			p._queued = "heavy"
			p._queued_dir = "up"
		"schritt":
			p.style.loadout["neutral"] = "sichelschritt"
		"lauschen":
			p.style.loadout["neutral"] = "seelenlauschen"
		"counter":
			print("counter ", g.try_counter(p.global_position.x + 30.0))
		"jump":
			p.velocity.y = -420.0
		"super":
			p.style.loadout["neutral"] = "sicheltakt"
			p.global_position = Vector2(380, 299)
			p.style.super_variant = parts[1]
			p._use_meisterzug()
		"shot":
			root.get_texture().get_image().save_png(out.path_join(parts[1] + ".png"))
		"shotzoom":
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
