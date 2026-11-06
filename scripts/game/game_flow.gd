class_name GameFlow
extends RefCounted
## Which part of the game is running: the calm overworld (hub, NPCs,
## entrances, its own quiet HUD) or a dungeon / combat area (fighter
## controls, combat HUD). Static, so it survives the scene reload that
## AreaTransition uses to switch between the two.
##
## Web URL: ?modus=dungeon starts straight in the training forest,
## ?modus=overworld (default) in the academy courtyard, ?modus=raid in the
## Glutschmiede raid (boss Essenwächter), ?modus=turm in the Turm der
## Prüfungen (endless tower).

const OVERWORLD := "overworld"
const DUNGEON := "dungeon"

## Areas: title and subtitle for the title card, accent colour, kind.
## Dungeons name the door of the courtyard you come back out of.
const AREAS := {
	"akademie_hof": {"title": "Akademie-Hof", "sub": "Overworld · Treffpunkt der Schüler", "kind": OVERWORLD, "accent": Color("4da6ff")},
	"trainingswald": {"title": "Trainingswald", "sub": "Kampfareal · Stufe 1", "kind": DUNGEON, "accent": Color("e83b3b"), "door": "tor_wald"},
	"glutschmiede": {"title": "Glutschmiede", "sub": "Raid · Essenwächter", "kind": DUNGEON, "accent": Color("ff8a2a"), "door": "tor_glut", "raid": true},
	"turm": {"title": "Turm der Prüfungen", "sub": "Endloser Turm · Wie hoch kommst du?", "kind": DUNGEON, "accent": Color("a46bff"), "door": "tor_turm", "tower": true},
}

static var mode := OVERWORLD
static var area := "akademie_hof"
## Door in the courtyard the player stands in front of when returning
## (empty = first start, the dormitory steps).
static var entry_door := ""
static var _url_read := false


static func is_overworld() -> bool:
	return mode == OVERWORLD


## Raid areas have a boss instead of dummies and waves (RaidDirector).
static func is_raid() -> bool:
	return mode == DUNGEON and bool(area_info(area).get("raid", false))


## The endless tower: floors of enemies instead of waves (TowerDirector).
static func is_tower() -> bool:
	return mode == DUNGEON and bool(area_info(area).get("tower", false))


static func area_info(id: String) -> Dictionary:
	return AREAS.get(id, AREAS["akademie_hof"])


## Sets the state for entering an area (called by AreaTransition when the
## screen is covered).
static func enter(id: String) -> void:
	var info := area_info(id)
	if info.kind == OVERWORLD:
		# coming back: stand in front of the door of the area we leave
		entry_door = String(area_info(area).get("door", ""))
	area = id
	mode = info.kind


static func read_url() -> void:
	if _url_read or not OS.has_feature("web"):
		return
	_url_read = true
	var search := str(JavaScriptBridge.eval("window.location.search", true))
	for part in search.trim_prefix("?").split("&"):
		var kv := part.split("=")
		if kv.size() == 2 and kv[0] == "modus":
			if kv[1] == "dungeon" or kv[1] == "kampf":
				area = "trainingswald"
				mode = DUNGEON
			elif kv[1] == "raid":
				area = "glutschmiede"
				mode = DUNGEON
			elif kv[1] == "turm":
				area = "turm"
				mode = DUNGEON
			elif kv[1] == "overworld" or kv[1] == "hof":
				area = "akademie_hof"
				mode = OVERWORLD
