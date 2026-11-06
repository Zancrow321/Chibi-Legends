class_name ItemMods
extends RefCounted
## Legendäre Fähigkeits-Mods: every legendary item carries one mod that
## changes a Zug of one fighting style (more hits, piercing, an extra wave,
## a shorter cooldown ...). It only works while that style is fought with;
## gear stays account-wide. FightingStyle.params() and .cooldown() apply the
## worn mods, so every caster gets them without own code.
##
## "params" uses the same keys as a Zug's "enhanced" block: <key>_add adds,
## <key>_mul multiplies, anything else is set. "cd_mul" scales the cooldown.
## The same mod worn twice counts once.

## Share of legendary drops whose mod belongs to the style the player uses.
const OWN_STYLE_SHARE := 0.6

const MODS := {
	# Glutatem
	"esse_atem": {"style": "glutatem", "zug": "funkenschlag", "name": "Atem der Esse",
		"text": "Funkenschlag trifft 2× öfter und reicht weiter", "params": {"hits_add": 2, "len_add": 12}},
	"glutkern": {"style": "glutatem", "zug": "essensturz", "name": "Glutkern",
		"text": "Essensturz löst immer ein Nachbeben aus", "params": {"aftershock": true, "wave_damage_add": 3}},
	"schmiedeherz": {"style": "glutatem", "zug": "weissglut", "name": "Schmiedeherz",
		"text": "Weißglut hält 2 s länger, 25 % kürzere Abklingzeit", "params": {"buff_add": 2.0}, "cd_mul": 0.75},
	# Bollwerk
	"panzerkammer": {"style": "bollwerk", "zug": "salve", "name": "Panzerbrecher-Kammer",
		"text": "Die Salve durchschlägt Gegner", "params": {"pierce": true}},
	"doppelzuender": {"style": "bollwerk", "zug": "splitterwurf", "name": "Doppelzünder",
		"text": "Splitterwurf: +30 % Radius und mehr Schaden", "params": {"radius_mul": 1.3, "damage_add": 4}},
	"bastion": {"style": "bollwerk", "zug": "schildprotokoll", "name": "Bastion",
		"text": "Schildprotokoll: +150 Wandleben, 20 % kürzere Abklingzeit", "params": {"hp_add": 150}, "cd_mul": 0.8},
	# Gleichklang
	"seelenecho": {"style": "gleichklang", "zug": "seelensichel", "name": "Seelenecho",
		"text": "Seelensichel schneidet mit Seelenklinge, +40 % Reichweite", "params": {"soul": true, "reach_mul": 1.4}},
	"nachhall": {"style": "gleichklang", "zug": "sicheltakt", "name": "Nachhall",
		"text": "Sicheltakt hinterlässt einen nachhallenden Schnitt", "params": {"linger": true, "reach_add": 10}},
	# Grenzbrecher
	"durchschlagkern": {"style": "grenzbrecher", "zug": "kernstrahl", "name": "Durchschlagkern",
		"text": "Kernstrahl durchdringt alle Gegner und trifft härter", "params": {"pierce": true, "min_dmg_add": 3, "max_dmg_add": 6}},
	"fersenschluss": {"style": "grenzbrecher", "zug": "steilpfad_folge", "name": "Fersenschluss",
		"text": "Steilpfad-Folge endet mit einem Fersenhieb", "params": {"heel": true, "finish_add": 4}},
	# Lauffeuer
	"herdflamme": {"style": "lauffeuer", "zug": "flammenknoechel", "name": "Herdflamme",
		"text": "Flammenknöchel setzt bei jedem Treffer Brandherde", "params": {"herd": true}},
	"zuendschnur": {"style": "lauffeuer", "zug": "flammenfaust", "name": "Zündschnur",
		"text": "Flammenfaust durchschlägt, +30 % Größe", "params": {"pierce": true, "scale_mul": 1.3}},
	# Schwarzmond
	"zweiter_mond": {"style": "schwarzmond", "zug": "mondschnitt", "name": "Zweiter Mond",
		"text": "Mondschnitt schickt eine zusätzliche Welle", "params": {"extra_wave": true}},
	"mondspur": {"style": "schwarzmond", "zug": "schwarze_spur", "name": "Mondspur",
		"text": "Schwarze Spur hinterlässt 2 Nachbilder", "params": {"ghosts": 2}},
	# Spannkraft
	"doppelfeder": {"style": "spannkraft", "zug": "schnappfaust", "name": "Doppelfeder",
		"text": "Schnappfaust schnappt zweimal", "params": {"double": true}},
	"fallbeilwurf": {"style": "spannkraft", "zug": "fallbeilferse", "name": "Fallbeil-Wurf",
		"text": "Fallbeilferse schleudert getroffene Gegner hoch", "params": {"toss": true}},
	# Wirbelwille
	"schattenzwilling": {"style": "wirbelwille", "zug": "wirbelansturm", "name": "Schattenzwilling",
		"text": "Beim Wirbelansturm greift ein Klon von der Seite mit an", "params": {"side_clone": true}},
	"kreiselkern": {"style": "wirbelwille", "zug": "kreiselfaust", "name": "Kreiselkern",
		"text": "Kreiselfaust: +35 % Größe und mehr Schaden", "params": {"damage_add": 5, "size_mul": 1.35}},
}

static var _tex := {}
static var _lines := {}
static var _style := ""
static var _style_frame := -1


static func info(mod_id: String) -> Dictionary:
	return MODS.get(mod_id, {})


## A mod for a new legendary: mostly one for the style in use.
static func roll(style_hint := "") -> String:
	var own: Array = MODS.keys().filter(func(m): return MODS[m].style == style_hint)
	if not own.is_empty() and randf() < OWN_STYLE_SHARE:
		return own[randi() % own.size()]
	var all: Array = MODS.keys()
	return all[randi() % all.size()]


## The fighting style the player fights with (saved in the creator look).
static func current_style() -> String:
	var frame := Engine.get_process_frames()
	if frame != _style_frame:  # the menus ask every frame: read the file once per frame
		_style_frame = frame
		_style = str(CreatorCatalog.load_look().get("style", "glutatem"))
	return _style


## Mod ids of all worn legendary items (each once).
static func worn() -> Array:
	var out: Array = []
	for s in Profile.SLOTS:
		var it := Profile.equipped_item(s)
		var m := str(it.get("mod", ""))
		if m != "" and MODS.has(m) and not m in out:
			out.append(m)
	return out


## Worn mods that change a Zug of this style.
static func for_zug(style_id: String, zug_id: String) -> Array:
	return worn().filter(func(m): return MODS[m].style == style_id and MODS[m].zug == zug_id)


## Applies the worn mods of a Zug to its parameters (in place).
static func apply(style_id: String, zug_id: String, p: Dictionary) -> void:
	for m in for_zug(style_id, zug_id):
		var mp: Dictionary = MODS[m].get("params", {})
		for k: String in mp:
			var v = mp[k]
			if k.ends_with("_add"):
				var key := k.trim_suffix("_add")
				p[key] = _scale(p.get(key, 0), 1.0, v)
			elif k.ends_with("_mul"):
				var key := k.trim_suffix("_mul")
				p[key] = _scale(p.get(key, 0), v, 0.0)
			else:
				p[k] = v


## Number or per-hit list: x * mul + add (lists element-wise).
static func _scale(x, mul: float, add: float):
	if x is Array:
		var out: Array = []
		for e in x:
			out.append(float(e) * mul + add)
		return out
	if x is bool:
		return x
	return float(x) * mul + add


## Cooldown factor of the worn mods for a Zug.
static func cd_factor(style_id: String, zug_id: String) -> float:
	var f := 1.0
	for m in for_zug(style_id, zug_id):
		f *= float(MODS[m].get("cd_mul", 1.0))
	return f


## "Glutatem · Funkenschlag"
static func target_line(mod_id: String) -> String:
	var m := info(mod_id)
	if m.is_empty():
		return ""
	if not _lines.has(mod_id):
		var zug_name := str(m.zug)
		var f := FileAccess.open("res://assets/combat/styles/%s.json" % m.style, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text()) if f else null
		if d is Dictionary:
			zug_name = str(d.get("zuege", {}).get(zug_name, {}).get("name", zug_name))
		_lines[mod_id] = "%s · %s" % [Gacha.style_name(str(m.style)), zug_name]
	return _lines[mod_id]


## PixelLab rune icon per style assets/items/mods/<style>.png (tools/items/gen_extra.py).
static func texture(mod_id: String) -> Texture2D:
	var style := str(info(mod_id).get("style", ""))
	if not _tex.has(style):
		var p := "res://assets/items/mods/%s.png" % style
		_tex[style] = load(p) if ResourceLoader.exists(p) else null
	return _tex[style]
