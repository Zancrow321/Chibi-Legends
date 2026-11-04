class_name MoveSet
extends RefCounted
## A character's normal attacks, loaded from a JSON file in assets/combat/movesets.
## Each move: button (light, heavy, grab), dir (neutral, forward, up, down, air),
## frame data at 60 fps (startup, active, recovery), hitbox, damage, knockback.

const FPS := 60.0

var moves: Dictionary = {}
var weight := "mittel"


static func load_file(path: String) -> MoveSet:
	var ms := MoveSet.new()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("MoveSet: %s fehlt" % path)
		return ms
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("MoveSet: %s ist kein gültiges JSON" % path)
		return ms
	ms.weight = data.get("weight", "mittel")
	for id in data.get("moves", {}):
		var m: Dictionary = data.moves[id]
		m["id"] = id
		ms.moves[id] = m
	return ms


## The move for a button + direction. In the air every button uses its "air"
## move; a direction without its own move falls back to neutral. Chains
## (leicht_1 -> leicht_2) start at the first move listed for that direction.
func pick(button: String, dir: String, in_air: bool) -> Dictionary:
	var want := "air" if in_air else dir
	for d in [want, "neutral"]:
		for id in moves:
			var m: Dictionary = moves[id]
			if m.button == button and m.dir == d:
				return m
	return {}


func get_move(id: String) -> Dictionary:
	return moves.get(id, {})


## Total length of a move in seconds.
static func length(m: Dictionary) -> float:
	return float(m.startup + m.active + m.recovery) / FPS


## "startup", "active" or "recovery" for a time t (seconds) into the move.
static func phase_at(m: Dictionary, t: float) -> String:
	var f := t * FPS
	if f < m.startup:
		return "startup"
	if f < m.startup + m.active:
		return "active"
	return "recovery"
