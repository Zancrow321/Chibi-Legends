@tool
extends RefCounted
## Reads M.U.G.E.N state files (.cns, .st, .cmd): [Statedef N] blocks with
## their [State N, label] controllers, the [Command] list from the .cmd and
## the [Data] / [Size] / [Velocity] constants.

const Text := preload("text.gd")

## state number -> {"props": {...}, "controllers": [{label, type, kv, props}]}
var statedefs: Dictionary = {}
## command name -> Array of command strings (a name can be defined twice)
var commands: Dictionary = {}
## lowercase section name -> props, for [Data], [Size], [Velocity], ...
var constants: Dictionary = {}


func parse(text: String) -> void:
	var re_def := RegEx.create_from_string("(?i)^statedef\\s+(-?\\d+)")
	var re_state := RegEx.create_from_string("(?i)^state\\s+(-?\\d+)\\s*(?:,\\s*(.*))?$")
	var current := -999999
	for sec in Text.sections(text):
		var name: String = sec.name
		var m := re_def.search(name)
		if m:
			current = m.get_string(1).to_int()
			if not statedefs.has(current):
				statedefs[current] = {"props": sec.props, "controllers": []}
			else:
				statedefs[current].props.merge(sec.props)
			continue
		m = re_state.search(name)
		if m:
			# controllers belong to the statedef above them, whatever number
			# their header says; old style .cmd files have [State -1, x]
			# without any [Statedef -1]
			var owner := current
			if owner == -999999:
				owner = m.get_string(1).to_int()
				if not statedefs.has(owner):
					statedefs[owner] = {"props": {}, "controllers": []}
			statedefs[owner].controllers.append({
				"label": m.get_string(2).strip_edges() if m.get_string(2) != "" else name,
				"type": String(sec.props.get("type", "")).to_lower(),
				"kv": sec.kv, "props": sec.props,
			})
			continue
		if sec.name_l == "command":
			var cname := Text.unquote(sec.props.get("name", ""))
			if cname != "":
				if not commands.has(cname):
					commands[cname] = []
				commands[cname].append(String(sec.props.get("command", "")))
			continue
		if sec.name_l in ["data", "size", "velocity", "movement", "info", "defaults", "remap"]:
			if not constants.has(sec.name_l):
				constants[sec.name_l] = {}
			constants[sec.name_l].merge(sec.props)


func constant(section: String, key: String, fallback: float) -> float:
	var v = constants.get(section, {}).get(key, null)
	if v == null:
		return fallback
	return Text.numbers(String(v), 1)[0]


## All trigger expressions of a controller (triggerall + trigger1..n).
static func triggers(ctrl: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for kv in ctrl.kv:
		if String(kv[0]).begins_with("trigger"):
			out.append(String(kv[1]))
	return out
