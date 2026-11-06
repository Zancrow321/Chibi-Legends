extends SceneTree
## Online client without a network: stays offline headless, and a server
## drop always builds the same piece from its seed.
##   godot --headless -s res://tools/online/test_online.gd   → ONLINE-CLIENT OK / FEHLER

var errors: Array = []


func _expect(ok: bool, what: String) -> void:
	print("ONLINE ok: " if ok else "ONLINE FEHLER: ", what)
	if not ok:
		errors.append(what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var online = root.get_node_or_null("Online")
	_expect(online != null, "Autoload Online da")
	_expect(not online.is_online(), "headless bleibt offline")
	var drop := {"id": 7, "source": "essenwaechter", "slot": "waffe", "rarity": 4, "ilvl": 12, "seed": 123456789}
	var a: Dictionary = online.build_item(drop, "glutatem")
	var b: Dictionary = online.build_item(drop, "glutatem")
	_expect(JSON.stringify(a) == JSON.stringify(b), "gleicher Seed = gleiches Teil (%s)" % a.name)
	_expect(a.slot == "waffe" and int(a.rarity) == 4 and int(a.ilvl) == 12 and a.server_id == 7, "Art, Seltenheit, Stufe vom Server")
	var c: Dictionary = online.build_item({"id": 8, "source": "essenwaechter", "slot": "waffe", "rarity": 4, "ilvl": 12, "seed": 987654321}, "glutatem")
	_expect(JSON.stringify(a.stats) != JSON.stringify(c.stats) or a.name != c.name, "anderer Seed = anderes Teil")
	var arm: Dictionary = online.build_item({"id": 9, "source": "essenwacht", "slot": "hose", "rarity": 5, "ilvl": 3, "seed": 42})
	_expect(arm.has("raid") and arm.slot == "hose" and int(arm.rarity) == 5, "Essenwacht-Rüstung aus dem Seed (%s)" % arm.name)
	print("ONLINE-CLIENT OK" if errors.is_empty() else "ONLINE-CLIENT FEHLER: %s" % ", ".join(errors))
	quit()
