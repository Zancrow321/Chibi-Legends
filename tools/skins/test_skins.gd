extends SceneTree
## Logiktest der Effekt-Skins (CI): Daten gültig, Umfärbung stimmt mit der
## Erwartung, Freischalten über Banner und Pass, Auswahl wird gespeichert.
##   godot --headless -s res://tools/skins/test_skins.gd

var errors: Array = []


func _check(ok: bool, what: String) -> void:
	print("SKIN ", "ok   " if ok else "FEHLT", " ", what)
	if not ok:
		errors.append(what)


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StyleSkin.SAVE))
	StyleSkin.ensure()
	var styles := StyleSkin.all_styles()
	_check(styles.size() == 8, "8 Kampfstile haben Skins (%d)" % styles.size())
	var seen := {}
	for st in styles:
		_check(ResourceLoader.exists("res://assets/combat/styles/%s.json" % st), "Stil %s existiert" % st)
		_check(StyleSkin.skins(st).size() >= 3, "%s hat mindestens 3 Skins" % st)
		for s in StyleSkin.skins(st):
			var key := "%s/%s" % [st, s.id]
			_check(not seen.has(key), "Skin %s eindeutig" % key)
			seen[key] = true
			_check(str(s.get("name", "")) != "" and str(s.get("desc", "")) != "", "%s hat Name und Text" % key)
			_check(not s.has("stats") and not s.has("damage"), "%s ohne Werte (nur Optik)" % key)
			_check(StyleSkin.hint(st, str(s.id)) != "", "%s ist anfangs gesperrt" % key)
			_check(StyleSkin.icon(st, str(s.id)) != null, "%s hat ein umgefärbtes Icon" % key)
	# colour maths: green fire stays bright, white core stays white, HDR stays HDR
	var gift := StyleSkin.info("glutatem", "giftglut")
	var orange := StyleSkin.map_color(gift, Color("ff9a2a"))
	_check(orange.g > orange.r and orange.g > orange.b, "Giftglut macht Orange grün (%s)" % orange.to_html(false))
	var white := StyleSkin.map_color(gift, Color(1, 1, 1))
	_check(absf(white.r - white.g) < 0.02 and absf(white.g - white.b) < 0.05, "Weißer Kern bleibt weiß")
	var hdr := StyleSkin.map_color(gift, Color(2.4, 1.2, 0.4))
	_check(maxf(hdr.r, maxf(hdr.g, hdr.b)) > 1.0, "HDR-Glanz bleibt (Bloom)")
	_check(StyleSkin.map_color({}, Color("ff9a2a")) == Color("ff9a2a"), "Standard färbt nichts um")
	var shadow := StyleSkin.map_color(StyleSkin.info("glutatem", "schattenglut"), Color("ff9a2a"))
	_check(shadow.b > shadow.g, "Schattenglut macht Orange violett (%s)" % shadow.to_html(false))
	# shader materials for every blend mode
	for bm in [CanvasItemMaterial.BLEND_MODE_MIX, CanvasItemMaterial.BLEND_MODE_ADD]:
		var base := CanvasItemMaterial.new()
		base.blend_mode = bm
		base.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		var m := StyleSkin.material_for(gift, base)
		_check(m != null and m.shader != null and "blend_" in m.shader.code, "Shader für Mischart %d" % bm)
	# painting restores the original material
	var node := Node2D.new()
	var spr := Sprite2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	spr.material = add
	node.add_child(spr)
	StyleSkin.paint(node, gift)
	_check(spr.material is ShaderMaterial and "blend_add" in (spr.material as ShaderMaterial).shader.code, "Umfärben behält additive Mischung")
	StyleSkin.paint(node, {})
	_check(spr.material == add, "Standard stellt das Originalmaterial wieder her")
	node.free()
	# unlocking: pass reward, banner prize, choice is saved
	SeasonPass.ensure()
	var found := 0
	for track in ["free", "premium"]:
		for r in SeasonPass.data.get(track, []):
			if str(r.get("kind", "")) == "skin":
				found += 1
				_check(not StyleSkin.info(str(r.style), str(r.id)).is_empty(), "Pass-Skin %s/%s existiert" % [r.style, r.id])
	_check(found >= 3, "Saisonpass hat Skins (%d)" % found)
	_check(StyleSkin.hint("glutatem", "giftglut").begins_with("Saisonpass Gratis"), "Giftglut kommt aus der Gratis-Spur")
	var msg := SeasonPass.give({"kind": "skin", "style": "glutatem", "id": "giftglut"})
	_check(StyleSkin.owns("glutatem", "giftglut") and "Giftglut" in msg, "Pass-Belohnung schaltet Giftglut frei")
	StyleSkin.set_active("glutatem", "blauglut")
	_check(StyleSkin.active_id("glutatem") == "", "Gesperrter Skin lässt sich nicht wählen")
	StyleSkin.set_active("glutatem", "giftglut")
	_check(StyleSkin.active_id("glutatem") == "giftglut", "Giftglut ist aktiv")
	Gacha.ensure()
	var banner: Dictionary = Gacha.banners().filter(func(b): return str(b.style) == "lauffeuer")[0]
	var got := false
	for i in 200:
		var res := Gacha._epic(banner)
		if str(res.get("kind", "")) == "skin":
			got = StyleSkin.owns("lauffeuer", str(res.id))
			break
	_check(got, "Banner »%s« gibt Lauffeuer-Skins als Episch" % banner.title)
	# saved and loaded again
	StyleSkin._loaded = false
	StyleSkin.owned = []
	StyleSkin.active = {}
	StyleSkin.ensure()
	_check(StyleSkin.active_id("glutatem") == "giftglut", "Auswahl bleibt nach Neustart")
	for p in ["res://scripts/ui/glutatem_menu.gd", "res://scripts/ui/gacha_screen.gd", "res://scripts/ui/pass_screen.gd"]:
		_check(load(p) != null, "Skript lädt: " + p)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StyleSkin.SAVE))
	if errors.is_empty():
		print("SKIN-TEST OK")
	else:
		print("SKIN-TEST FEHLER: ", errors)
	quit()
