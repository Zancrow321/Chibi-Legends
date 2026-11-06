extends SceneTree
## Pictures of the guild features without a server: the Gildenhaus in the
## courtyard and the guild screen filled with example data (preview mode).
##   xvfb-run godot --path . --fixed-fps 60 -s res://tools/guild/probe.gd -- <out_dir>
## Headless it only checks that everything builds: GILDEN-PROBE OK.

var out := ""
var f := 0
var ok := true


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.set("show_title", false)
	GameFlow.area = "akademie_hof"
	GameFlow.mode = GameFlow.OVERWORLD
	GameFlow.entry_door = ""
	change_scene_to_file("res://scenes/main.tscn")


func _process(_d: float) -> bool:
	f += 1
	match f:
		40:
			_hide(root)
			paused = false
			var ow := _find(root, "Overworld")
			if ow != null:
				ow.walker.global_position = Vector2(330, 299)
		90:
			_shot("gilde_01_gildenhaus")
		100:
			var gs := _screen()
			ok = ok and gs != null
			gs.preview = true
			gs.list = [
				{"id": 1, "name": "Glutfalken", "tag": "GLUT", "banner": 0, "level": 4, "members": 18, "slots": 30},
				{"id": 2, "name": "Sternwacht", "tag": "STRN", "banner": 1, "level": 2, "members": 20, "slots": 20},
			]
			gs.open()
		130:
			_shot("gilde_02_beitreten")
		140:
			var gs := _screen()
			gs.guild = {"id": 1, "name": "Glutfalken", "tag": "GLUT", "banner": 3, "level": 5, "xp": 2100, "xp_next": 5000,
				"trophies": 7, "slots": 35, "role": "anfuehrer", "week": "2026-11-02",
				"members": [
					{"id": "a", "name": "Kaiser", "role": "anfuehrer", "points": 412, "me": true},
					{"id": "b", "name": "Hotaru", "role": "offizier", "points": 260, "me": false},
					{"id": "c", "name": "Raiga", "role": "mitglied", "points": 95, "me": false},
				],
				"goals": [
					{"goal": "boss", "target": 15, "progress": 15, "done": true},
					{"goal": "marks", "target": 100, "progress": 64, "done": false},
					{"goal": "tower", "target": 120, "progress": 37, "done": false},
				]}
			GuildState.set_from(gs.guild)
			gs._build()
		170:
			_shot("gilde_03_halle")
		180:
			print("GILDEN-PROBE OK" if ok else "GILDEN-PROBE FEHLER")
			quit()
	return false


func _screen() -> GuildScreen:
	return root.find_children("*", "GuildScreen", true, false).front() if not root.find_children("*", "GuildScreen", true, false).is_empty() else null


func _shot(name: String) -> void:
	if out == "" or DisplayServer.get_name() == "headless":
		return
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png(out.path_join(name + ".png"))


func _hide(n: Node) -> void:
	if n is CharacterSelect or n is CreatorScreen:
		n.visible = false
	for c in n.get_children():
		_hide(c)


func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls or (n.get_script() != null and n.get_script().get_global_name() == cls):
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r != null:
			return r
	return null
