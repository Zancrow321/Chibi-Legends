extends SceneTree
## Test drive for the screen and sprite shaders (PostFx, Atmosphere,
## dissolve, wind, rim light): training forest at dusk with an enemy that
## dies and burns away, a finisher shockwave, heat over the forge, then the
## courtyard. Saves screenshots. Run (needs a display, e.g. xvfb-run):
##   godot --path . --fixed-fps 60 -s res://tools/shader/probe.gd -- <out_dir> [quality 0..2] [ohne_hud]

var out := "user://shader_shots"
var f := 0
var room: TrainingRoom
var p: Player
var steps: Array = []
var enemy: Enemy
var hide_hud := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		Hd2dSettings.quality = int(args[1])
	hide_hud = args.size() > 2 and args[2] == "ohne_hud"
	DirAccess.make_dir_recursive_absolute(out)
	GameFlow.area = "trainingswald"
	GameFlow.mode = GameFlow.DUNGEON
	GameFlow.combat_help_seen = true
	change_scene_to_file("res://scenes/main.tscn")
	var t := 40
	steps = [
		[t, "setup"], [t + 40, "shot:01_wald"],
		[t + 50, "enemy"], [t + 90, "kill"],
		[t + 260, "blast"], [t + 268, "shot:04_schockwelle_a"], [t + 278, "shot:05_schockwelle_b"],
		[t + 330, "forge"], [t + 400, "shot:06_esse_hitze"],
		[t + 420, "lantern"], [t + 460, "shot:07_randlicht"],
		[t + 480, "overworld"], [t + 540, "hofcam"], [t + 580, "shot:08_hof"], [t + 590, "quit"],
	]
	for i in 20:  # the death and the dissolve, frame by frame
		steps.append([t + 92 + i * 8, "shot:02_tod_%02d" % i])


func _process(_delta: float) -> bool:
	f += 1
	if hide_hud and current_scene != null:
		for c in current_scene.get_children():
			if c is CanvasLayer and (c as CanvasLayer).layer >= 10:
				(c as CanvasLayer).visible = false
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
			p.global_position = Vector2(420, 299)
			p.facing = 1
		"enemy":
			enemy = Enemy.new()
			enemy.world = room
			enemy.type_id = "moosgolem"
			enemy.position = Vector2(500, 299)
			room.add_enemy(enemy)
		"kill":
			enemy.apply_damage(99999.0)
			paused = false
		"blast":
			paused = false
			room.fx.blast(Vector2(520, 270), Color(1.0, 0.6, 0.3), 40.0, "super_final")
		"forge":
			paused = false
			p.global_position = Vector2(1000, 271)
		"lantern":
			p.global_position = Vector2(745, 299)
			p.facing = 1
		"overworld":
			paused = false
			GameFlow.mode = GameFlow.OVERWORLD
			GameFlow.area = "akademie_hof"
			change_scene_to_file("res://scenes/main.tscn")
		"hofcam":
			for w in current_scene.find_children("*", "Overworld", true, false):
				w.walker.global_position = Vector2(560, 299)
				w.camera.global_position = Vector2(620, 220)
				w.camera.reset_smoothing()
		"shot":
			root.get_texture().get_image().save_png(out.path_join(parts[1] + ".png"))
		"quit":
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
