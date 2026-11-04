class_name Hd2dStage
extends Node
## Variant B: the whole training forest is 3D. Gameplay logic stays the
## proven 2D code (physics, combat, effects): the training room runs inside
## its own 2D view, and that picture stands in the 3D world as one crisp card
## on the play line (z = 0). The 3D ground and ledges are built from the same
## layout constants as the 2D collision, so feet and platforms line up.

const PITCH := 19.0
const DIST := 31.0
const TOP := -240.0  # 2D y shown at the top of the gameplay card
const SIZE := Vector2i(1400, 600)

var room: TrainingRoom
var numbers: DamageNumbers
var view: Hd2dView
var forest: Hd2dForest
var game_vp: SubViewport
var _aim := Vector3.ZERO
var _shadows: Dictionary = {}  # node -> MeshInstance3D
var _shadow_mat: ShaderMaterial


func _ready() -> void:
	game_vp = SubViewport.new()
	game_vp.size = SIZE
	game_vp.transparent_bg = true
	game_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(game_vp)
	game_vp.canvas_transform = Transform2D(0.0, Vector2(0.0, -TOP))
	room.draw_terrain = false
	game_vp.add_child(room)
	room.camera.enabled = false

	forest = Hd2dForest.new()
	forest.with_strip = true
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	view = Hd2dView.new()
	layer.add_child(view)
	view.setup(forest)
	view.composite.set_shader_parameter("tilt_band", 0.12)
	view.composite.set_shader_parameter("tilt_ramp", 0.3)

	var card := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(SIZE) / Hd2dForest.PX
	card.mesh = q
	card.position = Vector3(SIZE.x * 0.5, 300.0 - (TOP + SIZE.y * 0.5), 0.0) / Hd2dForest.PX
	card.position.z = 0.0
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/hd2d/play_quad.gdshader")
	m.set_shader_parameter("tex", game_vp.get_texture())
	card.material_override = m
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	forest.add_geometry(card)

	_shadow_mat = ShaderMaterial.new()
	_shadow_mat.shader = load("res://shaders/hd2d/blob_shadow.gdshader")
	if numbers:
		numbers.to_screen = func(p: Vector2) -> Vector2: return view.to_screen(to_3d(p))
	_aim = _target_aim(1.0)


static func to_3d(p: Vector2) -> Vector3:
	return Vector3(p.x / Hd2dForest.PX, (300.0 - p.y) / Hd2dForest.PX, 0.0)


func _target_aim(_delta: float) -> Vector3:
	var p := to_3d(room.player.global_position)
	var half_w := 20.0
	var x := clampf(p.x + room.player.facing * 1.8, half_w, TrainingRoom.WIDTH / Hd2dForest.PX - half_w)
	return Vector3(x, 4.2 + p.y * 0.75, 0.0)


func _process(delta: float) -> void:
	if room.player == null:
		return
	# the room's (disabled) 2D camera may reset the view, so pin it every frame
	game_vp.canvas_transform = Transform2D(0.0, Vector2(0.0, -TOP))
	_aim = _aim.lerp(_target_aim(delta), 1.0 - exp(-6.0 * delta))
	var pr := deg_to_rad(PITCH)
	var shake := float(room.get("_shake")) * 0.05 if room.get("_shake") != null else 0.0
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * shake
	view.camera.position = _aim + Vector3(0.0, sin(pr), cos(pr)) * DIST + jitter
	view.camera.rotation = Vector3(-pr, 0.0, 0.0)
	view.focus_point = to_3d(room.player.global_position) + Vector3(0, 1, 0)
	forest.follow(_aim)
	_update_shadows()


func _update_shadows() -> void:
	var actors: Array = [room.player]
	actors.append_array(room.get_tree().get_nodes_in_group("targets"))
	for a in actors:
		var feet: Vector2 = a.global_position
		var top := _surface_below(feet)
		if not _shadows.has(a):
			var mi := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(1.6, 0.9)
			q.orientation = PlaneMesh.FACE_Y
			mi.mesh = q
			mi.material_override = _shadow_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			forest.add_child(mi)
			_shadows[a] = mi
		var s: MeshInstance3D = _shadows[a]
		s.visible = top < INF
		if s.visible:
			var lift := (top - feet.y) / Hd2dForest.PX
			var k := clampf(1.0 - lift * 0.12, 0.35, 1.0)
			s.scale = Vector3(k, 1.0, k)
			s.position = to_3d(Vector2(feet.x, top)) + Vector3(0.0, 0.03, 0.05)


func _surface_below(feet: Vector2) -> float:
	var best := INF
	for g in TrainingRoom.GROUND:
		if feet.x >= g[0] and feet.x <= g[0] + g[2] and g[1] >= feet.y - 3.0:
			best = minf(best, g[1])
	for p in TrainingRoom.PLATFORMS:
		if feet.x >= p[0] and feet.x <= p[0] + p[2] and p[1] >= feet.y - 3.0:
			best = minf(best, p[1])
	return best
