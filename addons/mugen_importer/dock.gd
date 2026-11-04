@tool
extends VBoxContainer
## Editor dock: pick a character's .def, confirm the rights, import.

const Converter := preload("converter.gd")

var _path: LineEdit
var _id: LineEdit
var _height: SpinBox
var _rights: CheckBox
var _button: Button
var _report: RichTextLabel
var _dialog: EditorFileDialog


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "M.U.G.E.N-Charakter importieren"
	add_child(title)

	var hint := Label.new()
	hint.text = "Nur für eigene Figuren oder solche mit Lizenz zur Weiterverwendung. Keine Fan-Rips fremder Anime- oder Spielfiguren."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	add_child(hint)

	add_child(_label("Charakter (.def):"))
	var row := HBoxContainer.new()
	_path = LineEdit.new()
	_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path.placeholder_text = "Pfad zur .def-Datei"
	_path.text_changed.connect(func(_t): _suggest_id())
	row.add_child(_path)
	var pick := Button.new()
	pick.text = "Wählen…"
	pick.pressed.connect(_open_dialog)
	row.add_child(pick)
	add_child(row)

	add_child(_label("ID im Spiel (Dateiname):"))
	_id = LineEdit.new()
	_id.placeholder_text = "z. B. probe"
	add_child(_id)

	var hrow := HBoxContainer.new()
	hrow.add_child(_label("Figurenhöhe (px):"))
	_height = SpinBox.new()
	_height.min_value = 16
	_height.max_value = 256
	_height.value = 56
	hrow.add_child(_height)
	add_child(hrow)

	_rights = CheckBox.new()
	_rights.text = "Die Figur ist von mir oder ich habe eine Lizenz zur Weiterverwendung."
	_rights.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rights.toggled.connect(func(_on): _update_button())
	add_child(_rights)

	_button = Button.new()
	_button.text = "Importieren"
	_button.pressed.connect(_import)
	add_child(_button)

	_report = RichTextLabel.new()
	_report.fit_content = false
	_report.custom_minimum_size = Vector2(0, 260)
	_report.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_report.selection_enabled = true
	add_child(_report)

	_dialog = EditorFileDialog.new()
	_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_dialog.filters = PackedStringArray(["*.def ; M.U.G.E.N-Charakter"])
	_dialog.file_selected.connect(func(p: String):
		_path.text = p
		_suggest_id())
	add_child(_dialog)
	_update_button()


func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _open_dialog() -> void:
	_dialog.popup_file_dialog()


func _suggest_id() -> void:
	if _id.text == "" or _id.has_meta("auto"):
		_id.text = _path.text.get_file().get_basename().to_lower().replace(" ", "_").replace("-", "_")
		_id.set_meta("auto", true)


func _update_button() -> void:
	_button.disabled = not _rights.button_pressed


func _import() -> void:
	var c := Converter.new()
	var ok := c.run(_path.text.strip_edges(), _id.text.strip_edges(), {
		"height": int(_height.value), "rights_confirmed": _rights.button_pressed,
	})
	_report.text = "\n".join(c.report)
	if ok:
		EditorInterface.get_resource_filesystem().scan()
		_report.append_text("\n\nIm Spiel mit Taste M zum neuen Kämpfer wechseln.")
