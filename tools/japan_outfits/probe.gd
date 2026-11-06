extends SceneTree
## Schaubild der Anime- und japanischen Kleidung im Spiel (LayeredBody mit Bloom).
##   xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 60 -s res://tools/japan_outfits/probe.gd -- <out_dir> [cyber|frost]

const LOOKS := [
	["hanabi", "kitsune", 0], ["mondhakama", "chonmage", 0], ["kranich", "kasa", 0], ["gakuran", "stachel", 0],
	["matrose", "zwillinge", 0], ["yukata", "dutt", 0], ["shinobi", "hachimaki", 0], ["miko", "lang", 0],
]

const CYBER_LOOKS := [
	["neonlaeufer", "neonvisier", 0], ["chromsoeldner", "kurz", 0], ["datenhoodie", "wuschel", 0], ["synthidol", "zwillinge", 0],
	["konzern", "lang", 0], ["strassenklinge", "neonkamm", 0], ["neonlaeufer", "neonkamm", 0], ["datenhoodie", "neonvisier", 0],
]

const FROST_LOOKS := [
	["eisjaeger", "hoernerhelm", 0], ["runenschild", "flechtbart", 0], ["frostseherin", "lang", 0], ["baerenhaut", "flechtbart", 0],
	["nordwanderer", "kurz", 0], ["eisjaeger", "flechtbart", 0], ["runenschild", "hoernerhelm", 0], ["baerenhaut", "hoernerhelm", 0],
]

var out := "user://kleidung_shots"
var f := 0
var bodies: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	CreatorCatalog.ensure()
	var theme := args[1] if args.size() > 1 else ""
	var looks: Array = {"cyber": CYBER_LOOKS, "frost": FROST_LOOKS}.get(theme, LOOKS)
	var stage := Node2D.new()
	root.add_child(stage)
	var bg := ColorRect.new()
	bg.color = Color("1a1420")
	bg.size = Vector2(1280, 720)
	stage.add_child(bg)
	stage.add_child(Bloom.new())
	for i in looks.size():
		var lk: Array = looks[i]
		var b := LayeredBody.new()
		b.look = {"hair": lk[1], "top": lk[0], "pants": lk[0], "shoes": lk[0], "weapon": "", "skin": 1,
			"colors": {"hair": lk[2], "top": 0, "pants": 0, "shoes": 0}}
		b.position = Vector2(110 + (i % 4) * 290 + (i / 4) * 150, 330 + (i / 4) * 330)
		b.scale = Vector2(4, 4)
		stage.add_child(b)
		b.play("idle")
		bodies.append(b)
		var l := Label.new()
		l.text = CreatorCatalog.item_name("top", lk[0])
		l.add_theme_font_size_override("font_size", 17)
		l.position = b.position + Vector2(-90, -290)
		l.size = Vector2(180, 30)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stage.add_child(l)


func _process(_delta: float) -> bool:
	f += 1
	match f:
		40:
			_shot("01_stehen")
		50:
			for b in bodies:
				b.play("run")
		65:
			_shot("02_laufen")
		70:
			for b in bodies:
				b.play("slash")
		82:
			_shot("03_schlag")
		90:
			for b in bodies:
				b.set_pose("highkick_hit")
		95:
			_shot("04_tritt")
		100:
			print("KLEIDUNG-PROBE fertig")
			quit()
	return false


func _shot(n: String) -> void:
	root.get_texture().get_image().save_png(out.path_join(n + ".png"))
