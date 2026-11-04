class_name Hd2dBackdrop
extends CanvasLayer
## Variant A: the 2D play layer stays exactly as it is; behind it the forest
## is a real 3D diorama (depth of field, bloom, haze, water), and a light
## overlay on top puts the flat layer into the same morning light.
## The 3D camera follows the 2D camera, so the play plane (z = 0) lines up
## and everything behind it gets true perspective parallax.

const PITCH := 16.0
const DIST := 31.0

var room: TrainingRoom
var view: Hd2dView
var forest: Hd2dForest
var _rays: ShaderMaterial


func _ready() -> void:
	layer = -1
	forest = Hd2dForest.new()
	view = Hd2dView.new()
	add_child(view)
	view.setup(forest)
	view.composite.set_shader_parameter("focus_range", 0.0)
	view.composite.set_shader_parameter("far_ramp", 0.3)
	view.composite.set_shader_parameter("tilt_focus_y", 1.0)
	view.composite.set_shader_parameter("tilt_band", 0.25)
	view.composite.set_shader_parameter("tilt_ramp", 0.45)
	view.composite.set_shader_parameter("base_blur", 0.0)

	var overlay := CanvasLayer.new()
	overlay.layer = 5
	add_child(overlay)
	var rays := ColorRect.new()
	rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays = ShaderMaterial.new()
	_rays.shader = load("res://shaders/hd2d/light_overlay.gdshader")
	rays.material = _rays
	overlay.add_child(rays)
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = load("res://shaders/hd2d/vignette.gdshader")
	vig.material = vm
	overlay.add_child(vig)


func _process(_delta: float) -> void:
	if room == null or room.camera == null:
		return
	var c := room.camera.get_screen_center_position()
	var aim := Vector3(c.x / Hd2dForest.PX, (300.0 - c.y) / Hd2dForest.PX, 0.0)
	var p := deg_to_rad(PITCH)
	view.camera.position = aim + Vector3(0.0, sin(p), cos(p)) * DIST
	view.camera.rotation = Vector3(-p, 0.0, 0.0)
	view.focus_point = aim
	forest.follow(aim)
	_rays.set_shader_parameter("scroll", c.x)
