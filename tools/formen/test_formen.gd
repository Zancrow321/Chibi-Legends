extends SceneTree
## Test der 30 Baukasten-Kampfstile (CI). Erst die Daten (Züge, Alternativen,
## Meisterzug, 50 SP, Effekt-Sprites, Icons, Katalog, Banner), dann im
## Trainingswald: jeder Stil wird angelegt, jeder Zug in Grundform und allen
## Alternativen gewirkt und jeder Meisterzug gezündet. Jeder Stil muss Schaden
## machen. Gibt FORMEN-TEST OK oder FORMEN-TEST FEHLER aus.
##   godot --headless --fixed-fps 60 -s res://tools/formen/test_formen.gd
##   xvfb-run godot --path . --fixed-fps 60 -s res://tools/formen/test_formen.gd -- <out_dir>
## Mit Bildschirm und Ordner speichert er je Stil drei Bilder (zwei Züge und
## einen Meisterzug) und wirkt nur drei Grundformen und einen Meisterzug.

const KINDS := ["hieb", "geschoss", "sturm", "saeule", "sturz", "konter", "aura", "feld", "strahl", "schritt", "regen", "wirbel"]
const SUPERS := ["strahl", "regen", "nova", "ansturm", "feld", "saeulen"]
const KERNE := ["rhythmus", "ladung", "marken", "echo", "blutzoll", "fokus"]

var out := ""
var errors: Array = []
var ids: Array = []
var queue: Array = []  # [wait_frames, cmd]
var wait := 40
var room: TrainingRoom
var p: Player
var g: FormCaster
var cur := ""
var dmg_at_start := 0.0
var casts := 0
var failed_casts := 0
var damage_by: Dictionary = {}


func _check(ok: bool, what: String) -> void:
	if not ok:
		print("FORMEN FEHLT ", what)
		errors.append(what)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
		DirAccess.make_dir_recursive_absolute(out)
	var f := FileAccess.open("res://assets/combat/formen/styles.json", FileAccess.READ)
	ids = (JSON.parse_string(f.get_as_text()) as Dictionary).get("styles", [])
	_check(ids.size() == 30, "30 Stile (%d)" % ids.size())
	_check_data()
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.set("show_title", false)
	var look := CreatorCatalog.load_look()
	look["style"] = ids[0]
	CreatorCatalog.save_look(look)
	GameFlow.area = "trainingswald"
	GameFlow.mode = GameFlow.DUNGEON
	change_scene_to_file("res://scenes/main.tscn")
	queue.append([0, "setup"])
	for sid in ids:
		var st := FightingStyle.load_style(sid)
		queue.append([4, "style:" + sid])
		var n := 0
		var zi := 0
		for z in st.zug_order:
			zi += 1
			if out != "" and zi > 3:
				continue
			var alts: Array = [""]
			if out == "":
				for a in st.zug(z).get("alts", []):
					alts.append(str(a.id))
			for a in alts:
				queue.append([2, "cast:%s:%s" % [z, a]])
				if out != "" and a == "" and n < 2 and str(st.zug(z).kind) != "konter":
					queue.append([16, "shot:%s_%d_%s" % [sid, n + 1, z]])
					n += 1
				queue.append([70, "end"])
		var vi := 0
		for v in st.variants():
			if out != "" and vi > 0:
				continue
			queue.append([2, "super:" + str(v.id)])
			if out != "" and vi == 0:
				queue.append([70, "shot:%s_3_%s" % [sid, str(v.id)]])
			queue.append([330, "superend"])
			vi += 1
		queue.append([2, "count"])
	queue.append([2, "quit"])


func _check_data() -> void:
	CreatorCatalog.ensure()
	var cat: Dictionary = CreatorCatalog.data
	var banners: Array = Gacha.banners()
	for sid in ids:
		var st := FightingStyle.load_style(sid)
		_check(str(st.data.get("caster", "")) == "form", "%s: caster form" % sid)
		_check(st.zug_order.size() == 6, "%s: 6 Züge" % sid)
		_check(st.variants().size() == 3, "%s: 3 Meisterzug-Varianten" % sid)
		_check(st.total_sp() == 50, "%s: 50 SP (%d)" % [sid, st.total_sp()])
		_check(str(st.data.get("kern", {}).get("type", "")) in KERNE, "%s: Kern" % sid)
		for d in FightingStyle.DIRS:
			_check(st.zuege.has(st.zug_in(d)), "%s: Platz %s belegt" % [sid, d])
		for z in st.zug_order:
			var zd := st.zug(z)
			_check(str(zd.get("kind", "")) in KINDS, "%s/%s: Art" % [sid, z])
			_check(zd.get("alts", []).size() == 3, "%s/%s: 3 Alternativen" % [sid, z])
			_check(ResourceLoader.exists("res://assets/combat/vfx/%s/%s.png" % [sid, z]), "%s/%s: Effekt-Sprite" % [sid, z])
			_check(ResourceLoader.exists("res://assets/combat/icons/%s/%s.png" % [sid, z]), "%s/%s: Icon" % [sid, z])
		_check(ResourceLoader.exists("res://assets/combat/icons/%s/meisterzug.png" % sid), "%s: Meisterzug-Icon" % sid)
		for v in st.variants():
			_check(str(v.get("kind", "")) in SUPERS, "%s/%s: Meisterzug-Art" % [sid, v.id])
			_check(ResourceLoader.exists("res://assets/combat/vfx/%s/%s.png" % [sid, v.id]), "%s/%s: Meisterzug-Sprite" % [sid, v.id])
			_check(ResourceLoader.exists("res://assets/combat/icons/%s/%s.png" % [sid, v.id]), "%s/%s: Meisterzug-Icon" % [sid, v.id])
		_check(cat.get("styles", {}).has(sid), "%s: im Creator-Katalog" % sid)
		var w := str(cat.get("styles", {}).get(sid, {}).get("weapon", ""))
		_check(w == "" or cat.get("weapons", {}).has(w), "%s: Waffe %s existiert" % [sid, w])
		_check(banners.any(func(b): return str(b.style) == sid), "%s: Banner im Sternschrein" % sid)
		_check(FormIcons.handles(sid), "%s: Icons über FormIcons" % sid)
	print("FORMEN Daten geprüft: %d Fehler" % errors.size())


func _process(_delta: float) -> bool:
	if queue.is_empty():
		return false
	wait -= 1
	if wait > 0:
		return false
	var step: Array = queue.pop_front()
	_do(str(step[1]))
	wait = int(queue[0][0]) if not queue.is_empty() else 1
	return false


func _do(cmd: String) -> void:
	var parts := cmd.split(":")
	match parts[0]:
		"setup":
			_hide_select(root)
			paused = false
			room = _find_room(root)
			_check(room != null, "Trainingswald startet")
			if room == null:
				queue.clear()
				_end_test()
				return
			p = room.player
			p.infinite_aura = true
		"style":
			cur = parts[1]
			if p.glut != null:
				p.glut.queue_free()
				p.glut = null
			p.style = FightingStyle.load_style(cur)
			p.moveset = MoveSet.load_file(p.style.moveset_path())
			p.init_style()
			g = p.glut as FormCaster
			_check(g != null, "%s: FormCaster" % cur)
			dmg_at_start = room.total_damage
		"cast":
			if g == null:
				return
			if g.busy():
				g.interrupt()
			p.in_super = false
			p.hitstun = 0.0
			p.global_position = Vector2(400, 299)
			p.velocity = Vector2.ZERO
			p.facing = 1
			for z in g.cooldowns:
				g.cooldowns[z] = 0.0
			p.style.loadout["neutral"] = parts[1]
			p.style.active_alt[parts[1]] = parts[2]
			var ok := g.cast("neutral")
			casts += 1
			if not ok:
				failed_casts += 1
				_check(false, "%s/%s/%s: Zug startet" % [cur, parts[1], parts[2]])
		"end":
			if g != null and g.busy():
				g.interrupt()
		"super":
			if g == null:
				return
			p.global_position = Vector2(400, 299)
			p.velocity = Vector2.ZERO
			p.facing = 1
			p.style.super_variant = parts[1]
			p.gauge = 300.0
			p._use_meisterzug()
			_check(p.in_super, "%s/%s: Meisterzug startet" % [cur, parts[1]])
		"superend":
			_check(not p.in_super, "%s: Meisterzug endet" % cur)
		"count":
			var d := room.total_damage - dmg_at_start
			damage_by[cur] = d
			print("FORMEN %s Schaden %d" % [cur, int(d)])
			_check(d > 0.0, "%s: macht Schaden" % cur)
		"shot":
			root.get_texture().get_image().save_png(out.path_join(parts[1] + ".png"))
		"quit":
			_end_test()


func _end_test() -> void:
	print("FORMEN Züge gewirkt: %d (fehlgeschlagen %d)" % [casts, failed_casts])
	if errors.is_empty():
		print("FORMEN-TEST OK")
	else:
		print("FORMEN-TEST FEHLER (%d)" % errors.size())
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
