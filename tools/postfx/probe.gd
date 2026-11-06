extends SceneTree
## Before/after probe for the post-processing pass (PostFx): training forest,
## low HP, a super finisher with impact frame and zoom blur, the courtyard,
## the raid and the tower. "vorher" shows the look before the pass.
##   xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 60 -s res://tools/postfx/probe.gd -- <out_dir> [vorher]

var out := "user://postfx_shots"
var tag := "nachher"
var f := 0
var room: TrainingRoom
var steps: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.has("vorher"):
		PostFx.legacy = true
		tag = "vorher"
	DirAccess.make_dir_recursive_absolute(out)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.set("show_title", false)
	_go(GameFlow.DUNGEON, "trainingswald")
	var t := 50
	steps = [
		[t, "setup:420"], [t + 40, "shot:1_wald"],
		[t + 50, "lowhp"], [t + 120, "shot:2_wenig_leben"], [t + 121, "fullhp"],
		[t + 160, "blast"], [t + 162, "shot:3_super_a"], [t + 166, "shot:3_super_b"], [t + 175, "shot:3_super_c"],
		[t + 230, "scene:overworld:akademie_hof"], [t + 300, "hofcam"], [t + 340, "shot:4_hof"],
		[t + 350, "scene:dungeon:glutschmiede"], [t + 420, "setup:300"], [t + 470, "shot:5_raid"],
		[t + 480, "scene:dungeon:turm"], [t + 550, "setup:300"], [t + 600, "shot:6_turm"],
		[t + 610, "quit"],
	]


func _go(mode: String, area: String) -> void:
	GameFlow.mode = mode
	GameFlow.area = area
	change_scene_to_file("res://scenes/main.tscn")


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
			if room != null:
				room.player.global_position = Vector2(float(parts[1]), TrainingRoom.GROUND_Y - 1)
				room.player.facing = 1
		"lowhp":
			room.player.hp = room.player.max_hp * 0.12
		"fullhp":
			room.player.hp = room.player.max_hp
		"blast":
			paused = false
			room.fx.blast(room.player.global_position + Vector2(90, -30), Color(1.0, 0.6, 0.3), 40.0, "super_final")
		"scene":
			paused = false
			_go(parts[1], parts[2])
		"hofcam":
			_hide_select(root)
			for w in current_scene.find_children("*", "Overworld", true, false):
				w.walker.global_position = Vector2(560, 299)
				w.camera.global_position = Vector2(620, 220)
				w.camera.reset_smoothing()
		"shot":
			root.get_texture().get_image().save_png(out.path_join("%s_%s.png" % [parts[1], tag]))
			print("POSTFX shot ", parts[1], " ", tag)
		"quit":
			print("POSTFX-PROBE OK ", tag)
			quit()


func _hide_select(n: Node) -> void:
	if n is CharacterSelect or n is CreatorScreen:
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
