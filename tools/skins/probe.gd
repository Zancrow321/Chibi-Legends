extends SceneTree
## Schaubild der Effekt-Skins eines Kampfstils: startet den Trainingswald mit
## dem Stil, setzt nacheinander Standard und jeden Skin und macht je Skin
## Bilder von zwei Zügen und einem Meisterzug.
##   xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 60 -s res://tools/skins/probe.gd -- <stil> <out_dir>

var style_id := "glutatem"
var out := "user://skin_shots"
var f := 0
var room: TrainingRoom
var p: Player
var steps: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		style_id = args[0]
	if args.size() > 1:
		out = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.set("show_title", false)
	StyleSkin.unlock_all()
	Gacha.unlock_all()
	var look := CreatorCatalog.load_look()
	look["style"] = style_id
	var w := str(Gacha.style_info(style_id).get("weapon", ""))
	if style_id == "glutatem":
		w = "glutklinge"
	look["weapon"] = "" if w == "none" else w
	CreatorCatalog.save_look(look)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://style_%s.json" % style_id))
	GameFlow.area = "trainingswald"
	GameFlow.mode = GameFlow.DUNGEON
	change_scene_to_file("res://scenes/main.tscn")
	var ids: Array = [StyleSkin.DEFAULT]
	for s in StyleSkin.skins(style_id):
		ids.append(str(s.id))
	var t := 40
	steps.append([t, "setup"])
	t += 10
	for i in ids.size():
		var id: String = ids[i]
		var tag := "%d_%s" % [i, id if id != "" else "standard"]
		steps.append([t, "skin:" + id])
		steps.append([t + 2, "cast:neutral"])
		steps.append([t + 16, "shot:%s_a" % tag])
		steps.append([t + 70, "cast:forward"])
		steps.append([t + 84, "shot:%s_b" % tag])
		steps.append([t + 150, "super"])
		steps.append([t + 150 + 40, "shot:%s_c" % tag])
		steps.append([t + 150 + 70, "shot:%s_d" % tag])
		steps.append([t + 150 + 110, "shot:%s_e" % tag])
		t += 420
	steps.append([t, "quit"])


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
			p.infinite_aura = true
			print("SKIN-PROBE style ", p.style.id, " caster ", p.glut)
		"skin":
			StyleSkin.set_active(style_id, parts[1])
			print("SKIN-PROBE skin '", parts[1], "' active ", StyleSkin.active_id(style_id))
		"cast":
			p.global_position = Vector2(380, 299)
			p.velocity = Vector2.ZERO
			p.facing = 1
			for z in p.glut.cooldowns:
				p.glut.cooldowns[z] = 0.0
			p.glut.interrupt()
			p.glut.cast(parts[1])
		"super":
			p.global_position = Vector2(380, 299)
			p.facing = 1
			p.glut.interrupt()
			p.gauge = 300.0
			p._use_meisterzug()
		"shot":
			root.get_texture().get_image().save_png(out.path_join(parts[1] + ".png"))
		"quit":
			print("SKIN-PROBE OK")
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
