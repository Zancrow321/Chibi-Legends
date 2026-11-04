class_name Hd2dInfo
extends Control
## Small panel for the look test: which view and preset are active, the
## keys to switch them and the current frame rate.

var view_name := ""
var font: Font
var hud: Node  # shows only while the HUD's help (H) is open


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if hud != null and not hud.show_help:
		return
	var q: String = Hd2dSettings.NAMES[Hd2dSettings.quality]
	var text := "[B] Ansicht: %s    [G] Grafik: %s    %d FPS" % [view_name, q, Engine.get_frames_per_second()]
	var fs := 14
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 24
	# Under the tip line, between the player bars (left) and the minimap (right).
	var r := Rect2(maxf(472.0, get_viewport_rect().size.x * 0.545 - w * 0.5), 54, w, 24)
	draw_rect(r, Color(0.09, 0.07, 0.16, 0.86))
	draw_rect(r, Color("f2c14e"), false, 1.0)
	draw_string(font, r.position + Vector2(12, 17), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fbf3e4"))
