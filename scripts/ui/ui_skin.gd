class_name UiSkin
extends RefCounted
## Manga-Panel-Skin aus PixelLab-Teilen (assets/ui/manga, Raender in slices.json).
## Liefert fertige StyleBoxTexture-Objekte (9-Slice) fuer das HUD.

const DIR := "res://assets/ui/manga/"
const INK := Color("2e222f")    # Resurrect 64, dunkelster Ton = Tusche
const PAPER := Color("ffffff")
const RED := Color("e83b3b")

static var _boxes := {}
static var _margins := {}


static func _load() -> void:
	if not _margins.is_empty():
		return
	var f := FileAccess.open(DIR + "slices.json", FileAccess.READ)
	_margins = JSON.parse_string(f.get_as_text())


## Margins [links, oben, rechts, unten] in Texturpixeln.
static func margins(part: String) -> Array:
	_load()
	return _margins[part]


static func box(part: String) -> StyleBoxTexture:
	if _boxes.has(part):
		return _boxes[part]
	var m := margins(part)
	var sb := StyleBoxTexture.new()
	sb.texture = load(DIR + part + ".png")
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	_boxes[part] = sb
	return sb


## Innenflaeche eines Teils, wenn es auf r gezeichnet wird (z. B. Fuellung eines Balkens).
static func inner(part: String, r: Rect2) -> Rect2:
	var m := margins(part)
	return Rect2(r.position + Vector2(m[0] - 1, m[1]), r.size - Vector2(m[0] + m[2] - 2, m[1] + m[3]))
