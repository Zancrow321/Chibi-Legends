class_name Hd2dView
extends Control
## Renders a 3D world with the HD-2D post chain, built from parts that work
## in the browser renderer (GL Compatibility has no built-in DOF/bloom there):
##   scene view (full 3D) -> quarter-size blurred copy -> composite shader
## Optional extra views, only on "Hoch":
##   depth view: the same meshes drawn again as distance, for real depth of field
##   reflection view: a mirrored camera under the river, for water reflections

const DEPTH_LAYER := 1 << 19
const WATER_LAYER := 1 << 18
const DEPTH_FAR := 160.0

var scene_vp: SubViewport
var depth_vp: SubViewport
var refl_vp: SubViewport
var blur_vp: SubViewport
var camera: Camera3D
var depth_cam: Camera3D
var refl_cam: Camera3D
var display: TextureRect
var composite: ShaderMaterial
var world: Hd2dForest
var water_level := -7.5
## Point in the world that stays sharp (the player / play plane).
var focus_point := Vector3.ZERO

var _blur_rect: TextureRect


func setup(forest: Hd2dForest) -> void:
	world = forest
	add_to_group("hd2d_view")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	scene_vp = _make_vp()
	scene_vp.add_child(forest)
	camera = Camera3D.new()
	camera.fov = 40.0
	camera.near = 0.5
	camera.far = 400.0
	camera.cull_mask = 0xFFFFF & ~DEPTH_LAYER
	forest.add_child(camera)
	camera.current = true

	depth_vp = _make_vp()
	depth_cam = Camera3D.new()
	depth_cam.cull_mask = DEPTH_LAYER
	var denv := Environment.new()
	denv.background_mode = Environment.BG_COLOR
	denv.background_color = Color.WHITE
	denv.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	denv.ambient_light_color = Color.BLACK
	denv.ambient_light_energy = 0.0
	depth_cam.environment = denv
	depth_vp.add_child(depth_cam)

	refl_vp = _make_vp()
	refl_cam = Camera3D.new()
	refl_cam.cull_mask = 0xFFFFF & ~DEPTH_LAYER & ~WATER_LAYER
	refl_vp.add_child(refl_cam)

	blur_vp = _make_vp()
	_blur_rect = TextureRect.new()
	_blur_rect.texture = scene_vp.get_texture()
	_blur_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_blur_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_blur_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var dm := ShaderMaterial.new()
	dm.shader = load("res://shaders/hd2d/down.gdshader")
	_blur_rect.material = dm
	blur_vp.add_child(_blur_rect)

	display = TextureRect.new()
	display.texture = scene_vp.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	composite = ShaderMaterial.new()
	composite.shader = load("res://shaders/hd2d/composite.gdshader")
	composite.set_shader_parameter("scene_tex", scene_vp.get_texture())
	composite.set_shader_parameter("blur_tex", blur_vp.get_texture())
	composite.set_shader_parameter("depth_tex", depth_vp.get_texture())
	display.material = composite
	add_child(display)

	for m in forest.water_materials:
		m.set_shader_parameter("reflection_tex", refl_vp.get_texture())
	get_viewport().size_changed.connect(apply_quality)
	apply_quality()


func _make_vp() -> SubViewport:
	var vp := SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.positional_shadow_atlas_size = 0
	add_child(vp)
	return vp


func apply_quality() -> void:
	var p := Hd2dSettings.preset()
	var screen := get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = screen
	var vp_size := Vector2i((screen * float(p.scale)).round())
	scene_vp.size = vp_size
	blur_vp.size = Vector2i(maxi(1, vp_size.x / 4), maxi(1, vp_size.y / 4))
	_blur_rect.size = Vector2(blur_vp.size)
	depth_vp.size = Vector2i(maxi(1, vp_size.x / 2), maxi(1, vp_size.y / 2))
	refl_vp.size = Vector2i(maxi(1, vp_size.x / 2), maxi(1, vp_size.y / 2))
	depth_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if p.depth_dof else SubViewport.UPDATE_DISABLED
	refl_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if p.reflection else SubViewport.UPDATE_DISABLED
	composite.set_shader_parameter("use_depth", p.depth_dof)
	composite.set_shader_parameter("mid_blur", p.mid_blur)
	composite.set_shader_parameter("bloom_strength", p.bloom)
	for m in world.water_materials:
		m.set_shader_parameter("use_reflection", p.reflection)
	world.apply_quality(p)


func _process(_delta: float) -> void:
	if camera == null:
		return
	var xf := camera.global_transform
	depth_cam.global_transform = xf
	depth_cam.fov = camera.fov
	depth_cam.near = camera.near
	depth_cam.far = DEPTH_FAR
	# mirror the camera at the water plane (no roll, so flipping pitch is enough)
	var rot := camera.global_rotation
	refl_cam.global_position = Vector3(xf.origin.x, 2.0 * water_level - xf.origin.y, xf.origin.z)
	refl_cam.global_rotation = Vector3(-rot.x, rot.y, 0.0)
	refl_cam.fov = camera.fov
	refl_cam.far = camera.far
	# focus distance of the play plane, in the same 0..1 units the depth view writes
	var local := xf.affine_inverse() * focus_point
	composite.set_shader_parameter("focus_depth", clampf(-local.z / DEPTH_FAR, 0.0, 1.0))
	var sp := camera.unproject_position(focus_point)
	composite.set_shader_parameter("tilt_focus_y", sp.y / maxf(1.0, float(scene_vp.size.y)))


## Screen position (in this control's coordinates) of a 3D point.
func to_screen(p: Vector3) -> Vector2:
	var sp := camera.unproject_position(p)
	return sp * (size / Vector2(scene_vp.size))
