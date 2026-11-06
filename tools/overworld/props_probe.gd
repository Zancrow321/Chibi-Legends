extends SceneTree
## Screenshots of the courtyard props (fountain, forge stall, shrine, both
## gates) to check that they read as side view next to the figures. Run:
##   xvfb-run godot --path . --fixed-fps 60 -s res://tools/overworld/props_probe.gd -- <out_dir>

var out := "user://props_shots"
var f := 0
const SPOTS := [["brunnen", 520.0], ["schmiede", 930.0], ["schrein", 1270.0], ["waldtor", 1730.0], ["gluttor", 2060.0]]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameFlow.mode = GameFlow.OVERWORLD
	GameFlow.area = "akademie_hof"
	load("res://scripts/main.gd").show_title = false  # no title screen
	change_scene_to_file("res://scenes/main.tscn")


func _process(_delta: float) -> bool:
	f += 1
	var i := (f - 60) / 40
	if f < 60:
		return false
	if i >= SPOTS.size():
		quit()
		return false
	var step := (f - 60) % 40
	if step == 0:
		_hide_select(root)
		paused = false
		for w in current_scene.find_children("*", "Overworld", true, false):
			w.walker.global_position = Vector2(SPOTS[i][1] + 40.0, w.ground_y(SPOTS[i][1] + 40.0))
			w.camera.global_position = Vector2(SPOTS[i][1], w.ground_y(SPOTS[i][1]) - 70.0)
			w.camera.reset_smoothing()
	elif step == 30:
		root.get_texture().get_image().save_png(out.path_join("%s.png" % SPOTS[i][0]))
	return false


func _hide_select(n: Node) -> void:
	if n is CharacterSelect or n is CreatorScreen:
		n.visible = false
	for c in n.get_children():
		_hide_select(c)
