@tool
extends SceneTree
## Same importer from the command line (for tests and batch use):
##   godot --headless --path . -s addons/mugen_importer/cli.gd -- \
##       <pfad/zur/figur.def> --id=<name> [--hoehe=56] --rechte-bestaetigt
## Afterwards run "godot --headless --path . --import" so Godot picks up the PNGs.

const Converter := preload("converter.gd")


func _init() -> void:
	var def_path := ""
	var opts := {}
	var id := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--id="):
			id = a.substr(5)
		elif a.begins_with("--hoehe="):
			opts["height"] = a.substr(8).to_int()
		elif a == "--rechte-bestaetigt":
			opts["rights_confirmed"] = true
		elif not a.begins_with("--"):
			def_path = a
	if def_path == "":
		print("Aufruf: -s addons/mugen_importer/cli.gd -- <figur.def> --id=<name> --rechte-bestaetigt")
		quit(2)
		return
	if not def_path.is_absolute_path() and not def_path.begins_with("res://"):
		def_path = ProjectSettings.globalize_path("res://").path_join(def_path)
	if id == "":
		id = def_path.get_file().get_basename()
	var c := Converter.new()
	var ok := c.run(def_path, id, opts)
	print("\n".join(c.report))
	quit(0 if ok else 1)
