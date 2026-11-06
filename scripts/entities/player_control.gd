class_name PlayerControl
extends RefCounted
## Where a fighter's buttons come from. By default the keyboard / gamepad
## (Godot's Input); a scripted control is driven by code instead: the
## Schatten-Kämpfer AI now, the network later. Player and the style casters
## ask `player.ctl` with the same calls they would make on Input.

var scripted := false
var player: Player
var _held := {}
var _just := {}


func is_action_pressed(action: String) -> bool:
	return bool(_held.get(action, false)) if scripted else Input.is_action_pressed(action)


func is_action_just_pressed(action: String) -> bool:
	return _just.has(action) if scripted else Input.is_action_just_pressed(action)


func get_axis(negative: String, positive: String) -> float:
	if not scripted:
		return Input.get_axis(negative, positive)
	return float(is_action_pressed(positive)) - float(is_action_pressed(negative))


## Scripted: hold or release a button. A new press also goes into the
## player's input buffer, like a key press would.
func set_held(action: String, on: bool) -> void:
	if on and not _held.get(action, false):
		_just[action] = true
		if player != null:
			player.press(action)
	_held[action] = on


## Scripted: a short tap (pressed this frame, released on the next).
func tap(action: String) -> void:
	set_held(action, true)
	_just[action] = true
	_held[action] = false
	if player != null:
		player.press(action)


func release_all() -> void:
	_held.clear()


## Called by the player at the end of each physics frame.
func end_frame() -> void:
	_just.clear()
