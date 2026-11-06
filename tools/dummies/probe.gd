extends SceneTree
## Test drive for the training dummies: starts the training forest, hits the
## dummies from both sides and saves screenshots. Run (needs a display):
##   xvfb-run godot --path . --fixed-fps 60 -s res://tools/dummies/probe.gd -- <out_dir>

var out := "user://dummy_shots"
var f := 0
var room: TrainingRoom
var dummies: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	CreatorCatalog.save_look(CreatorCatalog.load_look())
	GameFlow.area = "trainingswald"
	GameFlow.mode = GameFlow.DUNGEON
	GameFlow.combat_help_seen = true
	load("res://scripts/main.gd").show_title = false
	change_scene_to_file("res://scenes/main.tscn")


func _process(_delta: float) -> bool:
	f += 1
	match f:
		40:
			_hide_select(root)
			paused = false
			room = _find_room(root)
			for c in room.get_children():
				if c is TrainingDummy:
					dummies.append(c)
			room.player.global_position = Vector2(560, 299)
		50:
			root.get_texture().get_image().save_png(out.path_join("01_ruhe.png"))
		60:
			dummies[0].take_hit(200.0, 0.0)
			dummies[1].take_hit(200.0, 9999.0)
			dummies[3].take_hit(200.0, 0.0)
		63:
			root.get_texture().get_image().save_png(out.path_join("02_treffer_a.png"))
		66:
			root.get_texture().get_image().save_png(out.path_join("03_treffer_b.png"))
		70:
			dummies[2].launch(400.0)
		85:
			root.get_texture().get_image().save_png(out.path_join("04_jongliert.png"))
		100:
			quit()
	return false


func _hide_select(n: Node) -> void:
	if n is CharacterSelect or n is CanvasLayer and n.get_parent() == root:
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
