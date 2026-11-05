class_name Atmosphere
extends ColorRect
## God rays and ground mist (shaders/fx/atmosphere.gdshader) as a full-screen
## rect. Put it into the canvas layer of the nearest backdrop, after the
## backdrop sprite: it then lies over the trees and under the fighters.
## Presets per area mood; hidden on the lowest graphics preset.

const PRESETS := {
	"dusk": {"sun": Vector2(0.27, 0.5), "ray": Color(1.0, 0.6, 0.42), "rays": 0.26, "mist": Color(0.42, 0.34, 0.62), "mist_k": 0.38, "top": 0.6, "bottom": 0.92},
	"day": {"sun": Vector2(1.1, -0.3), "ray": Color(1.0, 0.93, 0.75), "rays": 0.0, "mist": Color(0.86, 0.88, 0.98), "mist_k": 0.22, "top": 0.62, "bottom": 0.95},
}

var preset := "dusk"
var _mat: ShaderMaterial


func _ready() -> void:
	add_to_group("hd2d_view")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/fx/atmosphere.gdshader")
	material = _mat
	var p: Dictionary = PRESETS[preset]
	_mat.set_shader_parameter("sun", p.sun)
	_mat.set_shader_parameter("ray_color", p.ray)
	_mat.set_shader_parameter("ray_strength", p.rays)
	_mat.set_shader_parameter("mist_color", p.mist)
	_mat.set_shader_parameter("mist_strength", p.mist_k)
	_mat.set_shader_parameter("mist_top", p.top)
	_mat.set_shader_parameter("mist_bottom", p.bottom)
	apply_quality()


func apply_quality() -> void:
	visible = Hd2dSettings.quality > 0


func _process(_delta: float) -> void:
	if not visible:
		return
	var vp := get_viewport()
	var vis := vp.get_visible_rect().size
	position = Vector2.ZERO
	size = vis  # the layer is not a Control: keep the rect on the whole screen
	var ct := vp.get_canvas_transform()
	_mat.set_shader_parameter("aspect", vis.x / vis.y)
	_mat.set_shader_parameter("art_px", maxf(1.0, round(ct.get_scale().x * vp.get_final_transform().get_scale().x)))
	_mat.set_shader_parameter("cam_x", -ct.origin.x / ct.get_scale().x)
