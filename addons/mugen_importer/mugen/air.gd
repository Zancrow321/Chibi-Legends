@tool
extends RefCounted
## Reads a M.U.G.E.N .air file: actions with frames and collision boxes.
## Clsn1 = attack box, Clsn2 = body box. "ClsnXDefault" applies to every
## following frame of the action, a plain "ClsnX" only to the next frame.
## Boxes are [x1, y1, x2, y2] relative to the character's foot point,
## facing right, y negative = up.

const Text := preload("text.gd")

## action number -> {"frames": [...], "loopstart": int}
## frame: {group, no, x, y, time, flip_h, flip_v, clsn1: [box], clsn2: [box]}
var actions: Dictionary = {}


func parse(text: String) -> void:
	var re_action := RegEx.create_from_string("(?i)^\\[\\s*begin\\s+action\\s+(-?\\d+)\\s*\\]")
	var re_count := RegEx.create_from_string("(?i)^clsn([12])(default)?\\s*:\\s*(\\d+)")
	var re_box := RegEx.create_from_string("(?i)^clsn([12])(?:default)?\\s*\\[\\s*\\d+\\s*\\]\\s*=\\s*(.+)$")
	var cur: Dictionary = {}
	var def1: Array = []
	var def2: Array = []
	var next1: Variant = null
	var next2: Variant = null
	var target := ""  # "d1", "d2", "n1", "n2": where boxes go
	for raw in text.replace("\r", "").split("\n"):
		var line := Text.strip_comment(raw).strip_edges()
		if line == "":
			continue
		var m := re_action.search(line)
		if m:
			cur = {"frames": [], "loopstart": 0}
			actions[m.get_string(1).to_int()] = cur
			def1 = []
			def2 = []
			next1 = null
			next2 = null
			continue
		if cur.is_empty():
			continue
		m = re_count.search(line)
		if m:
			var is_default := m.get_string(2) != ""
			var which := m.get_string(1)
			if is_default:
				if which == "1":
					def1 = []
				else:
					def2 = []
				target = "d" + which
			else:
				if which == "1":
					next1 = []
				else:
					next2 = []
				target = "n" + which
			continue
		m = re_box.search(line)
		if m:
			var v := Text.numbers(m.get_string(2), 4)
			var box := [mini(int(v[0]), int(v[2])), mini(int(v[1]), int(v[3])), maxi(int(v[0]), int(v[2])), maxi(int(v[1]), int(v[3]))]
			match target:
				"d1": def1.append(box)
				"d2": def2.append(box)
				"n1": if next1 != null: next1.append(box)
				"n2": if next2 != null: next2.append(box)
			continue
		if line.to_lower().begins_with("loopstart"):
			cur.loopstart = cur.frames.size()
			continue
		var parts := line.split(",")
		if parts.size() >= 5 and parts[0].strip_edges().is_valid_int():
			var flip := parts[5].strip_edges().to_upper() if parts.size() > 5 else ""
			cur.frames.append({
				"group": parts[0].strip_edges().to_int(), "no": parts[1].strip_edges().to_int(),
				"x": parts[2].strip_edges().to_int(), "y": parts[3].strip_edges().to_int(),
				"time": parts[4].strip_edges().to_int(),
				"flip_h": flip.contains("H"), "flip_v": flip.contains("V"),
				"clsn1": next1 if next1 != null else def1.duplicate(),
				"clsn2": next2 if next2 != null else def2.duplicate(),
			})
			next1 = null
			next2 = null
