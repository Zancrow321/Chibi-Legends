class_name PaletteRemap
extends RefCounted
## Color variants for sprites in the master palette (assets/palettes/swaps.json).
##
##   sprite.material = PaletteRemap.material("raiga_gi_blau")
##   PaletteRemap.set_variant(sprite.material, "original")
##
## Build the LUT after editing swaps.json: python3 tools/palette/build.py

const SHADER := preload("res://assets/shaders/palette_remap.gdshader")
const LUT_PATH := "res://assets/palettes/swaps_lut.png"
const LUT_INFO := "res://assets/palettes/swaps_lut.json"
const PALETTE_DIR := "res://assets/palettes/"

static var _rows: Array = []
static var _palette_name := ""


static func _load_info() -> void:
	if not _rows.is_empty():
		return
	var f := FileAccess.open(LUT_INFO, FileAccess.READ)
	if f == null:
		push_warning("PaletteRemap: %s fehlt (tools/palette/build.py ausführen)" % LUT_INFO)
		_rows = ["original"]
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	_rows = data.get("rows", ["original"])
	_palette_name = data.get("palette", "")


## Row index of a variant name (0 = original, also for unknown names).
static func row(variant_name: String) -> int:
	_load_info()
	return maxi(_rows.find(variant_name), 0)


static func variants() -> Array:
	_load_info()
	return _rows.duplicate()


static func material(variant_name := "original") -> ShaderMaterial:
	_load_info()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("master_palette", load(PALETTE_DIR + _palette_name + ".png"))
	mat.set_shader_parameter("swap_lut", load(LUT_PATH))
	mat.set_shader_parameter("variant", row(variant_name))
	return mat


static func set_variant(mat: ShaderMaterial, variant_name: String) -> void:
	mat.set_shader_parameter("variant", row(variant_name))
