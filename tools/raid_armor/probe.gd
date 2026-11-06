extends SceneTree
## Schaubild der Raid-Rüstung Essenwacht: sechs Figuren (eine pro Seltenheit)
## mit Rüstung, Helm, Glühen/Bloom und Funken, darunter die Item-Icons.
##   xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 60 -s res://tools/raid_armor/probe.gd -- <out_dir>

var out := "user://ruestung_shots"
var f := 0
var bodies: Array = []


class Icons extends Node2D:
	func _draw() -> void:
		for r in Loot.RARITIES.size():
			for k in RaidArmor.PIECES.size():
				var it := {"slot": RaidArmor.PIECES[k], "rarity": r, "raid": RaidArmor.ID}
				var c := Vector2(110 + r * 212 + (k - 1) * 58, 620)
				draw_rect(Rect2(c - Vector2(25, 25), Vector2(50, 50)), Color(Loot.RARITIES[r].color, 0.25))
				ItemIcon.draw_icon(self, c, it, 2.4)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var stage := Node2D.new()
	root.add_child(stage)
	var bg := ColorRect.new()
	bg.color = Color("1a1420")
	bg.size = Vector2(1280, 720)
	stage.add_child(bg)
	stage.add_child(Bloom.new())
	for r in Loot.RARITIES.size():
		var pid := RaidArmor.part_id(r)
		var b := LayeredBody.new()
		b.look = {"hair": pid, "top": pid, "pants": pid, "shoes": pid, "weapon": "", "skin": 1,
			"colors": {"hair": 0, "top": 0, "pants": 0, "shoes": 0}}
		b.position = Vector2(110 + r * 212, 500)
		b.scale = Vector2(4, 4)
		stage.add_child(b)
		b.play("idle")
		bodies.append(b)
		var l := Label.new()
		l.text = Loot.RARITIES[r].name
		l.add_theme_color_override("font_color", Loot.RARITIES[r].color)
		l.add_theme_font_size_override("font_size", 26)
		l.position = Vector2(110 + r * 212 - 80, 40)
		l.size = Vector2(160, 30)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stage.add_child(l)
	stage.add_child(Icons.new())
	print("RUESTUNG glow levels: ", bodies.map(func(b): return RaidArmor.glow_level(b.look)))


func _process(_delta: float) -> bool:
	f += 1
	match f:
		40:
			_shot("01_idle")
		52:
			_shot("02_idle_welle")
		60:
			for b in bodies:
				b.play("run")
		75:
			_shot("03_lauf")
		80:
			for b in bodies:
				b.play("slash")
		95:
			_shot("04_schlag")
		100:
			print("RUESTUNG-PROBE fertig")
			quit()
	return false


func _shot(n: String) -> void:
	root.get_texture().get_image().save_png(out.path_join(n + ".png"))
