class_name RaidScaling
extends RefCounted
## How strong a raid boss is for 1 to 4 players (Kampf-Endgame doc,
## "Raids und Bosse"). Offline there is one player; the web URL
## ?spieler=2..4 tries the bigger versions solo (for tests and balance).

## Per player count: boss HP, Wucht-Leiste, shield crystals, shield time (s).
const TABLE := {
	1: {"hp": 1.0, "wucht": 1.0, "crystals": 2, "shield_time": 20.0},
	2: {"hp": 1.8, "wucht": 1.5, "crystals": 3, "shield_time": 20.0},
	3: {"hp": 2.5, "wucht": 1.9, "crystals": 4, "shield_time": 24.0},
	4: {"hp": 3.2, "wucht": 2.3, "crystals": 4, "shield_time": 20.0},
}

static var players := 1
static var _url_read := false


static func row() -> Dictionary:
	_read_url()
	return TABLE[clampi(players, 1, 4)]


static func hp_factor() -> float:
	return float(row().hp)


static func wucht_factor() -> float:
	return float(row().wucht)


static func crystals() -> int:
	return int(row().crystals)


static func shield_time() -> float:
	return float(row().shield_time)


static func _read_url() -> void:
	if _url_read or not OS.has_feature("web"):
		return
	_url_read = true
	var search := str(JavaScriptBridge.eval("window.location.search", true))
	for part in search.trim_prefix("?").split("&"):
		var kv := part.split("=")
		if kv.size() == 2 and kv[0] == "spieler" and kv[1].is_valid_int():
			players = clampi(int(kv[1]), 1, 4)
