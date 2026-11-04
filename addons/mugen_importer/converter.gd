@tool
extends RefCounted
## Turns a M.U.G.E.N character (.def + files) into Chibi Legends data:
## sprite strips (PNG, one per animation, scaled to our figure height) and a
## moveset JSON (assets/combat/movesets/<id>.json) that the Player loads.
##
## What is taken over: sprites, animations with frame times, attack boxes
## (Clsn1) and body boxes (Clsn2), damage and push/launch from HitDefs, and a
## suggested mapping of the .cmd commands onto our buttons (light, heavy,
## grab, special) and directions (neutral, forward, up, down, air).
## What is not: the state logic of .cns files (custom code per move), sounds,
## supers. The report lists what needs manual work.
##
## Only for characters you made yourself or that are licensed for reuse.

const Text := preload("mugen/text.gd")
const Sff := preload("mugen/sff.gd")
const Air := preload("mugen/air.gd")
const States := preload("mugen/states.gd")

const DEFAULTS := {
	"height": 56,  # target figure height in pixels (idle pose, foot to head)
	"damage_scale": 0.25,  # M.U.G.E.N damage (life 1000) -> ours
	"knockback_scale": 0.5,  # ground.velocity x (px/tick) -> our knockback
	"launch_scale": 0.8,  # ground.velocity y -> our launch
	"char_dir": "res://assets/characters/imported",
	"moveset_dir": "res://assets/combat/movesets",
}
## Our animation states and the M.U.G.E.N actions that can fill them (first found wins).
const STATE_ACTIONS := {
	"idle": [0], "run": [20, 100, 21], "dash": [100, 105], "jump": [41, 42, 40], "fall": [44, 45, 41],
}
const DIR_SUFFIX := {"neutral": "", "forward": "_vor", "up": "_oben", "down": "_unten", "air": "_luft"}
const BUTTON_PREFIX := {"light": "leicht", "heavy": "schwer", "grab": "griff", "special": "spezial"}
const SPECIAL_DIRS := ["neutral", "forward", "up", "down"]

var report := PackedStringArray()
var written := PackedStringArray()

var _base := ""
var _air: Air
var _sff: Sff
var _states: States
var _scale := 1.0
var _world := 1.0


func _log(line: String) -> void:
	report.append(line)


func _warn(line: String) -> void:
	report.append("⚠ " + line)


## def_path: the character's .def (absolute or res:// path).
## id: name for the output (letters, digits, _). opts: see DEFAULTS, plus
## "rights_confirmed": true, which is required.
func run(def_path: String, id: String, opts: Dictionary = {}) -> bool:
	report.clear()
	written.clear()
	var o := DEFAULTS.duplicate()
	o.merge(opts, true)
	if not o.get("rights_confirmed", false):
		_warn("Abgebrochen: Bitte bestätigen, dass die Figur selbst gemacht oder zur Weiterverwendung lizenziert ist.")
		return false
	id = id.to_lower().strip_edges().replace(" ", "_").replace("-", "_")
	if id == "" or not id.is_valid_identifier():
		_warn("Ungültige ID \"%s\" (nur Buchstaben, Ziffern, _)." % id)
		return false

	# ---- .def
	if not FileAccess.file_exists(def_path):
		_warn("Datei fehlt: %s" % def_path)
		return false
	_base = def_path.get_base_dir()
	var info := {}
	var files := {}
	for sec in Text.sections(Text.read_text(def_path)):
		if sec.name_l == "info":
			info = sec.props
		elif sec.name_l == "files":
			files = sec.props
	var display := Text.unquote(info.get("displayname", info.get("name", id)))
	var author := Text.unquote(info.get("author", ""))
	_log("Figur: %s%s" % [display, (" (von %s)" % author) if author != "" else ""])

	# ---- sprites
	_sff = Sff.new()
	var sff_path := Text.find_file(_base, files.get("sprite", ""))
	if sff_path == "" or not _sff.open(sff_path):
		_warn(_sff.error if _sff.error != "" else "Sprite-Datei (sprite=) nicht gefunden.")
		return false
	_log("Sprites: %s (SFF v%d, %d Bilder)" % [sff_path.get_file(), _sff.version, _sff.sprites.size()])
	if _sff.version == 1 and files.has("pal1"):
		var act := Text.find_file(_base, files.pal1)
		if act != "":
			_sff.set_act(act)
			_log("Palette: %s" % act.get_file())

	# ---- animations
	_air = Air.new()
	var air_path := Text.find_file(_base, files.get("anim", ""))
	if air_path == "":
		_warn("Animationsdatei (anim=) nicht gefunden.")
		return false
	_air.parse(Text.read_text(air_path))
	_log("Animationen: %s (%d Aktionen)" % [air_path.get_file(), _air.actions.size()])
	if not _air.actions.has(0):
		_warn("Aktion 0 (Stehen) fehlt, die Größe wird geschätzt.")

	# ---- states and commands
	_states = States.new()
	var state_files := PackedStringArray()
	var keys := ["cmd", "cns", "st"]
	for k in 10:
		keys.append("st%d" % k)
	for k in keys:
		if not files.has(k):
			continue
		var p := Text.find_file(_base, files[k])
		if p == "":
			_warn("%s = %s nicht gefunden." % [k, files[k]])
		elif not state_files.has(p):
			state_files.append(p)
			_states.parse(Text.read_text(p))
	if files.has("stcommon"):
		_log("stcommon (%s) wird nicht gelesen: allgemeine Zustände bringt unser Spiel selbst mit." % files.stcommon)
	_log("Zustände: %d, Befehle: %d" % [_states.statedefs.size(), _states.commands.size()])

	# ---- scale
	var idle_h := _idle_height()
	_scale = float(o.height) / maxf(1.0, idle_h)
	_world = float(o.height) / maxf(1.0, idle_h * _states.constant("size", "yscale", 1.0))
	_log("Größe: Stehbild %d px hoch -> %d px (Faktor %.2f)" % [idle_h, o.height, _scale])

	# ---- moves
	var attacks := _find_attacks()
	if attacks.is_empty():
		_warn("Keine Angriffe gefunden (Zustände mit movetype = A und HitDef).")
	var mapping := _map_commands(attacks)
	var life := _states.constant("data", "life", 1000.0)
	var dmg_scale: float = o.damage_scale * 1000.0 / maxf(1.0, life)
	var moves := {}
	var state_to_id := {}
	var strips_needed := {}  # action -> true
	var order: Array = attacks.keys()
	order.sort()
	for st in order:
		var a: Dictionary = attacks[st]
		var slot: Dictionary = mapping.get(st, {"button": "extra", "dir": "neutral"})
		var mid := _move_id(slot, st, moves)
		var mv := _build_move(st, a, slot, dmg_scale, o)
		if mv.is_empty():
			continue
		moves[mid] = mv
		state_to_id[st] = mid
		strips_needed[a.anim] = true
	# chains (only taken over for light moves, like our own 3-hit chain)
	for st in order:
		if not state_to_id.has(st):
			continue
		var target: int = attacks[st].get("chain", -1)
		if target >= 0 and state_to_id.has(target):
			var mv: Dictionary = moves[state_to_id[st]]
			mv["chain"] = state_to_id[target]
			if mv.button != "light":
				_log("Kette %s -> %s: bei uns nur für Leicht, bleibt als Hinweis." % [state_to_id[st], state_to_id[target]])

	# ---- sprite strips
	var states_map := {}
	for state in STATE_ACTIONS:
		for act in STATE_ACTIONS[state]:
			if _air.actions.has(act) and not _air.actions[act].frames.is_empty():
				states_map[state] = "a%d" % act
				strips_needed[act] = true
				break
	if not states_map.has("idle"):
		var first: int = _air.actions.keys().min() if not _air.actions.is_empty() else -1
		if first >= 0:
			states_map["idle"] = "a%d" % first
			strips_needed[first] = true
	var cell := _cell_bounds(strips_needed.keys())
	var char_dir: String = String(o.char_dir).path_join(id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(char_dir))
	var strips := {}
	var acts: Array = strips_needed.keys()
	acts.sort()
	for act in acts:
		var s := _write_strip(act, cell, char_dir)
		if not s.is_empty():
			strips["a%d" % act] = s
	for state in states_map.keys():
		if not strips.has(states_map[state]):
			states_map.erase(state)
	for mid in moves.keys():
		if not strips.has(moves[mid].strip):
			_warn("%s: Animation fehlt, Bewegung ohne eigene Bilder." % mid)

	# ---- json
	var body_box := _body_box()
	var data := {
		"_doc": "Importiert aus M.U.G.E.N (%s). Werte sind Vorschläge: Schaden, Rückstoß und Reihenfolge der Tasten bitte im Spiel prüfen." % def_path.get_file(),
		"name": display,
		"weight": "mittel",
		"source": {"format": "mugen", "def": def_path.get_file(), "author": author, "rights_confirmed": true,
			"imported": Time.get_date_string_from_system()},
		"sprite": {"cell": [cell.size_s.x, cell.size_s.y], "foot": [cell.foot_s.x, cell.foot_s.y],
			"body": body_box, "states": states_map, "strips": strips},
		"moves": moves,
	}
	var json_path: String = String(o.moveset_dir).path_join(id + ".json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(String(o.moveset_dir)))
	var f := FileAccess.open(json_path, FileAccess.WRITE)
	if f == null:
		_warn("Konnte %s nicht schreiben." % json_path)
		return false
	f.store_string(JSON.stringify(data, "\t", false))
	f.close()
	written.append(json_path)
	_log("")
	_log("Belegung:")
	for mid in moves:
		var mv: Dictionary = moves[mid]
		_log("  %-16s %-8s %-8s Zustand %s, %d/%d/%d Bilder, Schaden %s" % [mid, mv.button, mv.dir,
			mv.source_state, mv.startup, mv.active, mv.recovery, mv.damage])
	var rep := FileAccess.open(char_dir.path_join("import_bericht.txt"), FileAccess.WRITE)
	if rep:
		rep.store_string("\n".join(report))
		written.append(char_dir.path_join("import_bericht.txt"))
	_log("Fertig: %s und %d Bilderstreifen in %s" % [json_path, strips.size(), char_dir])
	return true


# ------------------------------------------------------------------ attacks

## state -> {anim, hitdefs: [props], label, type, chain}
func _find_attacks() -> Dictionary:
	var out := {}
	for st in _states.statedefs:
		if st < 0:
			continue
		var sd: Dictionary = _states.statedefs[st]
		var props: Dictionary = sd.props
		var hitdefs: Array = []
		var chain := -1
		for c in sd.controllers:
			if c.type == "hitdef" or c.type == "projectile":
				hitdefs.append(c.props)
			elif c.type == "changestate":
				var trig := " ".join(States.triggers(c)).to_lower()
				if trig.contains("command") and (trig.contains("movecontact") or trig.contains("movehit")):
					chain = int(Text.numbers(String(c.props.get("value", "-1")), 1)[0])
		var movetype := String(props.get("movetype", "I")).to_upper()
		if hitdefs.is_empty() or not movetype.begins_with("A"):
			continue
		var anim: int = st
		if props.has("anim"):
			var a := String(props.anim)
			if a.is_valid_int():
				anim = a.to_int()
		if not _air.actions.has(anim):
			_warn("Zustand %d: Animation %d fehlt, übersprungen." % [st, anim])
			continue
		out[st] = {"anim": anim, "hitdefs": hitdefs, "type": String(props.get("type", "S")).to_upper(),
			"chain": chain, "projectile": hitdefs[0].has("projanim")}
	# chains only to states that are attacks too
	for st in out:
		if out[st].chain >= 0 and not out.has(out[st].chain):
			out[st].chain = -1
	return out


## Reads the ChangeState controllers of [Statedef -1] (the .cmd) and turns
## each command into button + direction. Returns state -> {button, dir, label}.
func _map_commands(attacks: Dictionary) -> Dictionary:
	var out := {}
	var taken := {}
	var ctrls: Array = _states.statedefs.get(-1, {}).get("controllers", [])
	var re_cmd := RegEx.create_from_string("(?i)command\\s*(!?=)\\s*\"([^\"]+)\"")
	var re_type := RegEx.create_from_string("(?i)statetype\\s*(!?=)\\s*([sca])")
	for c in ctrls:
		if c.type != "changestate":
			continue
		var st := int(Text.numbers(String(c.props.get("value", "-1")), 1)[0])
		if not attacks.has(st) or out.has(st):
			continue
		var cmds := PackedStringArray()
		var stype := ""
		for t in States.triggers(c):
			for m in re_cmd.search_all(t):
				if m.get_string(1) == "=":
					cmds.append(m.get_string(2))
			for m in re_type.search_all(t):
				if m.get_string(1) == "=":
					stype = m.get_string(2).to_upper()
		if cmds.is_empty():
			continue
		var slot := _classify(cmds)
		if slot.is_empty():
			continue
		if stype == "A" or attacks[st].type == "A":
			slot.dir = "air"
		elif (stype == "C" or attacks[st].type == "C") and slot.dir == "neutral":
			slot.dir = "down"
		if st >= 3000:
			_log("Zustand %d (%s) sieht nach einem Super aus: nicht belegt, unsere Supers laufen über die Legendenleiste." % [st, c.label])
			continue
		if slot.button == "special":
			if taken.has("special:" + slot.dir):
				for d in SPECIAL_DIRS:
					if not taken.has("special:" + d):
						_log("Spezial %s (%s): Richtung %s war belegt, liegt jetzt auf %s." % [st, c.label, slot.dir, d])
						slot.dir = d
						break
			if slot.dir == "air":
				slot.dir = "neutral" if not taken.has("special:neutral") else slot.dir
		var key: String = slot.button + ":" + slot.dir
		if taken.has(key):
			_log("Zustand %d (%s): %s + %s ist schon mit Zustand %d belegt, bleibt als Extra." % [st, c.label, slot.button, slot.dir, taken[key]])
			continue
		taken[key] = st
		slot["label"] = c.label
		out[st] = slot
	# fallback without .cmd: by state number ranges (M.U.G.E.N conventions)
	var free_ranges := [[200, 299, ["light", "heavy"], ["neutral", "forward"]], [400, 499, ["light", "heavy"], ["down"]],
		[600, 699, ["light", "heavy"], ["air"]], [1000, 2999, ["special"], SPECIAL_DIRS]]
	var order: Array = attacks.keys()
	order.sort()
	for st in order:
		if out.has(st) or _is_chain_target(st, attacks):
			continue
		for r in free_ranges:
			if st < r[0] or st > r[1]:
				continue
			var placed := false
			for d in r[3]:
				for b in r[2]:
					if not taken.has(b + ":" + d):
						taken[b + ":" + d] = st
						out[st] = {"button": b, "dir": d, "label": ""}
						_log("Zustand %d ohne Befehl in der .cmd: nach Nummer auf %s + %s gelegt." % [st, b, d])
						placed = true
						break
				if placed:
					break
		if not out.has(st):
			_log("Zustand %d: keine freie Taste, bleibt als Extra." % st)
	return out


func _is_chain_target(st: int, attacks: Dictionary) -> bool:
	for other in attacks:
		if attacks[other].chain == st:
			return true
	return false


## Commands like "~D, DF, F, x" -> special forward; "x" -> light; "/$F" adds
## the hold direction; "x+y" or two buttons -> grab.
func _classify(names: PackedStringArray) -> Dictionary:
	var buttons := {}
	var hold_dir := ""
	var motion_dir := ""
	var motion := false
	for n in names:
		for cmd in _states.commands.get(n, []):
			var tokens := String(cmd).split(",")
			var dirs_before := 0
			for t in tokens:
				var tok := String(t).strip_edges()
				var is_hold := tok.contains("/")
				tok = tok.replace("~", "").replace("/", "").replace("$", "").replace(">", "")
				while tok.length() > 0 and tok[0].is_valid_int():
					tok = tok.substr(1)
				for part in tok.split("+"):
					var p := String(part).strip_edges()
					if p.to_lower() in ["a", "b", "c", "x", "y", "z"]:
						buttons[p.to_lower()] = true
					elif p.to_upper() in ["F", "B", "D", "U", "DF", "DB", "UF", "UB"]:
						if is_hold:
							hold_dir = p.to_upper()
						else:
							dirs_before += 1
							motion_dir = p.to_upper()
			if dirs_before >= 2:
				motion = true
	if buttons.is_empty():
		return {}
	var button := "light"
	if motion:
		button = "special"
	elif buttons.size() >= 2:
		button = "grab"
	elif buttons.has("y") or buttons.has("b") or buttons.has("z") or buttons.has("c"):
		button = "heavy"
	var motion_map := {"F": "forward", "DF": "forward", "UF": "up", "U": "up", "UB": "up", "D": "down", "DB": "down", "B": "neutral"}
	var hold_map := {"F": "forward", "DF": "down", "UF": "up", "U": "up", "UB": "up", "D": "down", "DB": "down", "B": "neutral"}
	var dir: String = motion_map.get(motion_dir, "neutral") if motion else hold_map.get(hold_dir, "neutral")
	return {"button": button, "dir": dir}


func _move_id(slot: Dictionary, st: int, moves: Dictionary) -> String:
	if slot.button == "extra":
		return "extra_%d" % st
	var mid: String = BUTTON_PREFIX[slot.button] + DIR_SUFFIX[slot.dir]
	if moves.has(mid):
		mid += "_%d" % st
	return mid


func _build_move(st: int, a: Dictionary, slot: Dictionary, dmg_scale: float, o: Dictionary) -> Dictionary:
	var frames: Array = _air.actions[a.anim].frames
	var ticks := PackedInt32Array()
	for fr in frames:
		ticks.append(maxi(1, int(fr.time)))  # -1 (endless) counts as one tick
	var first := -1
	var last := -1
	for k in frames.size():
		if not frames[k].clsn1.is_empty():
			if first < 0:
				first = k
			last = k
	var hd: Dictionary = a.hitdefs[0]
	var hitbox := [24, -28, 32, 24]
	var startup := 0
	var active := 0
	if first >= 0:
		for k in first:
			startup += ticks[k]
		for k in range(first, last + 1):
			active += ticks[k]
		var box := _union(frames[first].clsn1)
		hitbox = [roundi((box[0] + box[2]) * 0.5 * _scale), roundi((box[1] + box[3]) * 0.5 * _scale),
			maxi(4, roundi((box[2] - box[0]) * _scale)), maxi(4, roundi((box[3] - box[1]) * _scale))]
		var gaps := 0
		for k in range(first, last + 1):
			if frames[k].clsn1.is_empty():
				gaps += 1
		if gaps > 0:
			_log("Zustand %d: mehrere Trefferphasen, bei uns ein Treffer über %d Bilder." % [st, active])
	else:
		# projectile or box-less move: hit at the frame the HitDef starts
		var elem := 1
		for c in _states.statedefs[st].controllers:
			if c.type == "hitdef" or c.type == "projectile":
				var re := RegEx.create_from_string("(?i)animelem\\s*=\\s*(\\d+)")
				var m := re.search(" ".join(States.triggers(c)))
				if m:
					elem = m.get_string(1).to_int()
				break
		for k in clampi(elem - 1, 0, frames.size()):
			startup += ticks[k]
		active = 4
		_warn("Zustand %d: keine Clsn1-Box%s, Trefferbox geschätzt." % [st, " (Projektil)" if a.projectile else ""])
	var total := 0
	for t in ticks:
		total += t
	var recovery := maxi(1, total - startup - active)
	startup = maxi(1, startup)
	active = maxi(1, active)
	# damage, push, launch
	var dmg := Text.numbers(String(hd.get("damage", "0")), 1)[0]
	var gv := Text.numbers(String(hd.get("ground.velocity", "0")), 2)
	var damage := maxi(1, roundi(dmg * dmg_scale))
	var knockback := roundi(absf(gv[0]) * 60.0 * _world * float(o.knockback_scale))
	var launch := roundi(-gv[1] * 60.0 * _world * float(o.launch_scale))
	var button: String = slot.button
	var mv := {
		"name": slot.get("label", "") if slot.get("label", "") != "" else "Zustand %d" % st,
		"button": button, "dir": slot.dir,
		"startup": startup, "active": active, "recovery": recovery,
		"damage": damage, "hitbox": hitbox, "knockback": knockback,
		"draw": "hit", "strip": "a%d" % a.anim, "source_state": st,
		"pose": _pose(ticks, startup, active, recovery),
	}
	if launch != 0:
		mv["launch"] = launch
	if button in ["heavy", "special", "grab"] or damage >= 12:
		mv["profile"] = "heavy"
	if a.projectile:
		mv["projectile"] = true
	return mv


## Frame index of the strip for every tick of each phase, so the game shows
## exactly the M.U.G.E.N timing.
static func _pose(ticks: PackedInt32Array, startup: int, active: int, recovery: int) -> Dictionary:
	var per_tick := PackedInt32Array()
	for k in ticks.size():
		for t in ticks[k]:
			per_tick.append(k)
	var get_range := func(a: int, n: int) -> Array:
		var r: Array = []
		for t in n:
			r.append(per_tick[clampi(a + t, 0, per_tick.size() - 1)])
		return r
	return {"startup": get_range.call(0, startup), "active": get_range.call(startup, active),
		"recovery": get_range.call(startup + active, recovery)}


static func _union(boxes: Array) -> Array:
	var b: Array = boxes[0].duplicate()
	for x in boxes:
		b[0] = mini(b[0], x[0])
		b[1] = mini(b[1], x[1])
		b[2] = maxi(b[2], x[2])
		b[3] = maxi(b[3], x[3])
	return b


func _body_box() -> Array:
	if not _air.actions.has(0):
		return []
	for fr in _air.actions[0].frames:
		if not fr.clsn2.is_empty():
			var b := _union(fr.clsn2)
			return [roundi((b[0] + b[2]) * 0.5 * _scale), roundi((b[1] + b[3]) * 0.5 * _scale),
				roundi((b[2] - b[0]) * _scale), roundi((b[3] - b[1]) * _scale)]
	return []


# ------------------------------------------------------------------ sprites

func _idle_height() -> float:
	if _air.actions.has(0):
		for fr in _air.actions[0].frames:
			var s := _sff.get_sprite(fr.group, fr.no)
			if s.is_empty():
				continue
			var img: Image = s.image
			var used := img.get_used_rect()
			if used.size.y > 0:
				return float(s.axis.y - used.position.y)
	for s in _sff.sprites:
		if s.get("h", 0) > 0:
			return float(s.h)
	return 100.0


## The frame image placed relative to the foot point: {"image", "pos" (top left)}.
func _frame_image(fr: Dictionary) -> Dictionary:
	var s := _sff.get_sprite(fr.group, fr.no)
	if s.is_empty():
		return {}
	var img: Image = s.image
	var axis: Vector2i = s.axis
	if fr.flip_h or fr.flip_v:
		img = img.duplicate()
		if fr.flip_h:
			img.flip_x()
			axis.x = img.get_width() - axis.x
		if fr.flip_v:
			img.flip_y()
			axis.y = img.get_height() - axis.y
	return {"image": img, "pos": Vector2i(fr.x, fr.y) - axis}


## One cell size for all strips (original and scaled) and the foot point in it.
func _cell_bounds(acts: Array) -> Dictionary:
	var mn := Vector2i(-8, -8)
	var mx := Vector2i(8, 1)
	for act in acts:
		for fr in _air.actions[act].frames:
			var fi := _frame_image(fr)
			if fi.is_empty():
				continue
			var used: Rect2i = fi.image.get_used_rect()
			if used.size.x == 0:
				continue
			var tl: Vector2i = fi.pos + used.position
			mn = Vector2i(mini(mn.x, tl.x), mini(mn.y, tl.y))
			mx = Vector2i(maxi(mx.x, tl.x + used.size.x), maxi(mx.y, tl.y + used.size.y))
	var size := mx - mn
	var size_s := Vector2i(ceili(size.x * _scale) + 2, ceili(size.y * _scale) + 2)
	var foot_s := Vector2i(roundi(-mn.x * _scale) + 1, roundi(-mn.y * _scale) + 1)
	return {"min": mn, "size": size, "size_s": size_s, "foot_s": foot_s}


func _write_strip(act: int, cell: Dictionary, dir: String) -> Dictionary:
	var frames: Array = _air.actions[act].frames
	if frames.is_empty():
		return {}
	var cw: int = cell.size_s.x
	var ch: int = cell.size_s.y
	var strip := Image.create(cw * frames.size(), ch, false, Image.FORMAT_RGBA8)
	var ticks: Array = []
	var missing := 0
	for k in frames.size():
		var fr: Dictionary = frames[k]
		ticks.append(int(fr.time))
		var fi := _frame_image(fr)
		if fi.is_empty():
			missing += 1
			continue
		# draw at original size into an original-size cell, then scale the cell
		var orig := Image.create(cell.size.x, cell.size.y, false, Image.FORMAT_RGBA8)
		var src: Image = fi.image
		var at: Vector2i = fi.pos - cell.min
		orig.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)
		var w := maxi(1, roundi(cell.size.x * _scale))
		var h := maxi(1, roundi(cell.size.y * _scale))
		orig.resize(w, h, Image.INTERPOLATE_NEAREST)
		strip.blend_rect(orig, Rect2i(0, 0, w, h), Vector2i(k * cw + 1, 1))
	if missing > 0:
		_warn("Aktion %d: %d Bilder fehlen in der SFF." % [act, missing])
	var path := dir.path_join("a%d.png" % act)
	if strip.save_png(ProjectSettings.globalize_path(path)) != OK:
		_warn("Konnte %s nicht speichern." % path)
		return {}
	written.append(path)
	return {"file": path, "frames": frames.size(), "ticks": ticks, "loop": int(_air.actions[act].loopstart)}
