@tool
extends EditorPlugin
## Adds the "M.U.G.E.N" dock (right side) to the Godot editor.

const Dock := preload("dock.gd")

var _dock: Control


func _enter_tree() -> void:
	_dock = Dock.new()
	_dock.name = "M.U.G.E.N"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
