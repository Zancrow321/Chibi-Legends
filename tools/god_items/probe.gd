extends SceneTree
## Schaubild der GOD-Stufe: vier Figuren mit GOD-Teilen und allen Effekten
## (Flügel, Heiligenschein, Hörnerflammen, Bannkreis, Spuren, Waffen-Glühen,
## Erhebung), dazu die GOD-Halle und die Enthüllung.
##   xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 60 -s res://tools/god_items/probe.gd -- <out_dir>

var out := "user://god_shots"
var f := 0
var bodies: Array = []
var stage: Node2D
var hall: GodHall
const HOLY := ["god_sonnenkrone", "god_gewand", "god_beinkleid", "god_morgenschritte", "god_seraphfluegel"]
const DEMON := ["god_hoernerkrone", "god_hoellenpanzer", "god_kettenbeinkleid", "god_aschewandler", "god_verdammnisschwingen"]
## [GOD-Teile, Kampfstil, Waffe im Look, Titel]
const FIGS := [
	[HOLY + ["god_glockenschwinge"], "gleichklang", "sense_nachhall", "Serie I · Heilig (Erhebung)"],
	[DEMON + ["god_hoellenschlund"], "glutatem", "schwert_kaiser", "Serie II · Dämon (Erhebung)"],
	[["god_sonnenkrone", "god_seraphfluegel", "god_sonnenfaeuste", "god_morgenschritte"], "grenzbrecher", "", "Heilig · Sonnenfäuste"],
	[["god_hoernerkrone", "god_verdammnisschwingen", "god_seraphfluegel", "god_mondfresser", "god_hoellenpanzer"], "schwarzmond", "schwert_kaiser", "Gefallener Engel · Mondfresser"],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	Profile.reset()
	CreatorCatalog.ensure()
	stage = Node2D.new()
	root.add_child(stage)
	var bg := ColorRect.new()
	bg.color = Color("140f1c")
	bg.size = Vector2(1280, 720)
	stage.add_child(bg)
	var floor_r := ColorRect.new()
	floor_r.color = Color("221a2c")
	floor_r.position = Vector2(0, 560)
	floor_r.size = Vector2(1280, 160)
	stage.add_child(floor_r)
	stage.add_child(Bloom.new())
	for i in FIGS.size():
		var fg: Array = FIGS[i]
		var b := LayeredBody.new()
		b.god_style = fg[1]
		b.look = {"hair": "", "top": "kampfweste", "pants": "", "shoes": "", "weapon": fg[2], "skin": 1, "style": fg[1],
			"colors": {"hair": 0, "top": 0, "pants": 0, "shoes": 0}}
		b.position = Vector2(170 + i * 313, 560)
		b.scale = Vector2(4, 4)
		stage.add_child(b)
		b.god = fg[0]
		b.play("idle")
		bodies.append(b)
		var l := Label.new()
		l.text = fg[3]
		l.add_theme_color_override("font_color", Color("fff1b8"))
		l.add_theme_font_size_override("font_size", 20)
		l.position = Vector2(170 + i * 313 - 150, 640)
		l.size = Vector2(300, 30)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stage.add_child(l)


func _process(delta: float) -> bool:
	f += 1
	match f:
		70:
			_shot("01_stehen")
		95:
			_shot("02_stehen_fluegelschlag")
		100:
			for b in bodies:
				b.play("run")

		131:
			_shot("03_laufen_spuren")
		140:
			for b in bodies:
				b.play("slash")
		152:
			_shot("04_schlag")
		160:
			for b in bodies:
				b.play("idle")
			Profile.ensure()
			GodItems.grant_all_test()
			var layer := CanvasLayer.new()
			root.add_child(layer)
			hall = GodHall.new()
			layer.add_child(hall)
		162:
			hall.open()
			hall.sel = 4
			hall._toggle_try()
		230:
			_shot("05_god_halle")
		240:
			hall.sel = 15
			hall._toggle_try()
		300:
			_shot("06_god_halle_anprobe")
		310:
			hall.close()
			hall.reveal("god_verdammnisschwingen")
		400:
			_shot("07_enthuellung")
		410:
			Profile.reset()
			print("GOD-PROBE fertig")
			quit()
	if f > 100 and f < 140:
		for i in bodies.size():
			var b: LayeredBody = bodies[i]
			b.position.x += 90.0 * delta * (1 if i % 2 == 0 else -1)
			b.facing = 1 if i % 2 == 0 else -1
	return false


func _shot(n: String) -> void:
	root.get_texture().get_image().save_png(out.path_join(n + ".png"))
