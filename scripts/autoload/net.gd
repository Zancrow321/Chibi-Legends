class_name Net
extends RefCounted
## Typed access to the Online autoload from any script. Autoload names are
## not known when scripts compile in test runs (godot -s), so gameplay code
## goes through Net instead of naming Online directly. Without the autoload
## everything counts as offline.


static func node() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Online") if tree != null else null


static func is_online() -> bool:
	var n := node()
	return n != null and n.is_online()


static func state() -> String:
	var n := node()
	return str(n.state) if n != null else "offline"


static func call_fn(fn: String, args := {}) -> Dictionary:
	var n := node()
	if n == null:
		return {"ok": false, "data": null, "error": "offline"}
	return await n.call_fn(fn, args)


static func build_item(drop: Dictionary, style_hint := "") -> Dictionary:
	var n := node()
	return n.build_item(drop, style_hint) if n != null else {}
