class_name Hd2dForest
extends Node3D
## The training forest as a 3D diorama for the HD-2D test, sunny morning:
## terraced cliffs with grass tops, a river with two wooden bridges and a
## small waterfall, pixel-art trees as cards, distant hills fading into haze,
## light shafts, river mist and floating pollen.
## 1 world unit = 16 game pixels; the play line is z = 0, ground top y = 0.
## Variant A uses it only as backdrop; variant B also builds the walkable
## strip (with_strip) that matches the 2D collision of the training room.

const PX := 16.0
const WATER_Y := -7.5
const RIVER_NEAR := -8.0
const RIVER_FAR := -15.0
const FALL_X := 50.0
const BRIDGES := [30.0, 97.0]

var with_strip := false
var water_materials: Array[ShaderMaterial] = []
var sun: DirectionalLight3D
var pollen: CPUParticles3D

var _rng := RandomNumberGenerator.new()
var _sprites: Dictionary = {}  # texture name -> {"xf": Array[Transform3D], "col": Array[Color]}
var _depth_mats: Dictionary = {}  # material -> depth twin material
var _shafts: Array[MeshInstance3D] = []
var _mists: Array = []  # [MeshInstance3D, speed]
var _terrain_mat: ShaderMaterial
var _wood_mat: ShaderMaterial
var _log_mat: ShaderMaterial
var _lip_x: ShaderMaterial
var _lip_z: ShaderMaterial
## Static pieces merged into one mesh per material (few draw calls, fast on the web).
var _batches: Dictionary = {}  # material -> SurfaceTool

## texture -> [wind sway, casts shadow]
const SPRITE_KINDS := {
	"tree_round_a": [0.22, true], "tree_round_b": [0.22, true], "tree_pine": [0.15, true],
	"bush_a": [0.06, true], "bush_b": [0.06, true], "bush_c": [0.06, true],
	"tuft": [0.05, false], "flowers": [0.04, false], "rock": [0.0, true],
}


func _ready() -> void:
	_rng.seed = 2611
	_materials()
	_environment()
	_sky()
	if with_strip:
		_play_strip()
		_front()
	_back_terrace()
	_river()
	_far_bank()
	for bx in BRIDGES:
		_bridge(bx)
	_waterfall()
	_hills()
	_light_shafts()
	_river_mist()
	_pollen()
	_flush_batches()
	_flush_sprites()


func _process(delta: float) -> void:
	for m in _mists:
		var mi: MeshInstance3D = m[0]
		mi.position.x += m[1] * delta
		if mi.position.x > 135.0:
			mi.position.x = -45.0


## Keeps the pollen cloud around what the camera looks at.
func follow(point: Vector3) -> void:
	if pollen:
		pollen.global_position = point + Vector3(0, 1, -2)


func apply_quality(p: Dictionary) -> void:
	sun.shadow_enabled = p.shadows
	var n := int(160.0 * float(p.particles))
	pollen.visible = n > 0
	pollen.emitting = n > 0
	if n > 0 and pollen.amount != n:
		pollen.amount = n
	for s in _shafts:
		s.visible = p.shafts


# --- materials ---------------------------------------------------------------

func _tex(name: String) -> Texture2D:
	return load("res://assets/hd2d/%s.png" % name)


func _shader_mat(path: String, params: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func _materials() -> void:
	_terrain_mat = _shader_mat("res://shaders/hd2d/terrain.gdshader", {"tex_top": _tex("grass_top"), "tex_side": _tex("cliff_side")})
	_wood_mat = _shader_mat("res://shaders/hd2d/terrain.gdshader", {"tex_top": _tex("wood_planks"), "tex_side": _tex("wood_log"), "swap_top_uv": true, "texel_scale": 0.5, "top_tint": Color(0.9, 0.9, 0.9)})
	_log_mat = _shader_mat("res://shaders/hd2d/terrain.gdshader", {"tex_top": _tex("wood_log"), "tex_side": _tex("wood_log"), "texel_scale": 1.0, "top_tint": Color(0.9, 0.9, 0.9)})
	_lip_x = _shader_mat("res://shaders/hd2d/lip.gdshader", {"tex": _tex("grass_lip")})
	_lip_z = _shader_mat("res://shaders/hd2d/lip.gdshader", {"tex": _tex("grass_lip"), "along_z": true})


func _depth_twin_mat(m: Material) -> Material:
	if not _depth_mats.has(m):
		var d: ShaderMaterial = m.duplicate()
		d.set_shader_parameter("depth_mode", true)
		_depth_mats[m] = d
	return _depth_mats[m]


## Adds a mesh and (for the depth-of-field pass) its depth twin.
func add_geometry(gi: GeometryInstance3D, twin := true) -> void:
	add_child(gi)
	if not twin:
		return
	var t: GeometryInstance3D
	if gi is MultiMeshInstance3D:
		t = MultiMeshInstance3D.new()
		(t as MultiMeshInstance3D).multimesh = (gi as MultiMeshInstance3D).multimesh
	else:
		t = MeshInstance3D.new()
		(t as MeshInstance3D).mesh = (gi as MeshInstance3D).mesh
	t.transform = gi.transform
	t.material_override = _depth_twin_mat(gi.material_override)
	t.layers = Hd2dView.DEPTH_LAYER
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(t)


# --- light and sky -----------------------------------------------------------

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.86, 0.91, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.64, 0.73, 0.80)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.9, 0.72)
	sun.light_energy = 0.95
	sun.rotation_degrees = Vector3(-50, -32, 0)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.8
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.light_cull_mask = 0xFFFFF & ~Hd2dView.DEPTH_LAYER
	add_child(sun)


func _sky() -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(900, 260)
	mi.mesh = q
	mi.position = Vector3(45, 45, -195)
	mi.material_override = _shader_mat("res://shaders/hd2d/sky.gdshader")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# --- terrain -----------------------------------------------------------------

func _q(v: float) -> float:
	return roundf(v * 4.0) / 4.0  # snap to quarter units (4 px)


## Box of terrain with grass overhang on the edges that face the camera.
func _block(x0: float, x1: float, z0: float, z1: float, top: float, bottom: float, mat: Material = null, lips := true) -> void:
	var b := BoxMesh.new()
	b.size = Vector3(x1 - x0, top - bottom, z1 - z0)
	_batch(b, Transform3D(Basis.IDENTITY, Vector3((x0 + x1) * 0.5, (top + bottom) * 0.5, (z0 + z1) * 0.5)), mat if mat else _terrain_mat)
	if not lips:
		return
	var lip_h := 0.75
	var y := top - lip_h * 0.5 + 0.0625
	_lip(Vector3((x0 + x1) * 0.5, y, z1 + 0.02), Vector2(x1 - x0, lip_h), 0.0, _lip_x)
	_lip(Vector3(x0 - 0.02, y, (z0 + z1) * 0.5), Vector2(z1 - z0, lip_h), -90.0, _lip_z)
	_lip(Vector3(x1 + 0.02, y, (z0 + z1) * 0.5), Vector2(z1 - z0, lip_h), 90.0, _lip_z)


func _lip(pos: Vector3, size: Vector2, yaw: float, mat: Material) -> void:
	var q := QuadMesh.new()
	q.size = size
	_batch(q, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), pos), mat)


func _batch(mesh: Mesh, xf: Transform3D, mat: Material) -> void:
	if not _batches.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[mat] = st
	(_batches[mat] as SurfaceTool).append_from(mesh, 0, xf)


func _flush_batches() -> void:
	for mat in _batches:
		var mi := MeshInstance3D.new()
		mi.mesh = (_batches[mat] as SurfaceTool).commit()
		mi.material_override = mat
		if mat == _lip_x or mat == _lip_z:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_geometry(mi)
	_batches.clear()


## A row of terrace blocks with ragged fronts and slightly varying heights.
## Returns the blocks as [x0, x1, z_front, top] for decoration.
func _row(z_back: float, z_front: float, top: float, bottom: float, jitter_top: float, jitter_front: float, fixed: Dictionary = {}) -> Array:
	var out: Array = []
	var x := -45.0
	while x < 135.0:
		var seg := _q(_rng.randf_range(6.0, 15.0))
		var t := _q(top + _rng.randf_range(-jitter_top, jitter_top))
		var zf := _q(z_front + _rng.randf_range(-jitter_front, 0.0))
		for fx in fixed:  # keep a fixed segment (waterfall / bridge landing)
			if x < fx + 2.0 and x + seg > fx - 2.0:
				if x < fx - 2.0:
					seg = fx - 2.0 - x
				else:
					seg = 4.0
					t = fixed[fx]
					zf = z_front
				break
		_block(x, x + seg, z_back, zf, t, bottom)
		out.append([x, x + seg, zf, t])
		x += seg
	return out


func _play_strip() -> void:
	# walkable ground and floating ledges, from the training room's 2D layout
	var grounds: Array = TrainingRoom.GROUND
	for i in grounds.size():
		var g: Array = grounds[i]
		var x0: float = g[0] / PX
		var x1: float = (g[0] + g[2]) / PX
		if i == 0:
			x0 = -45.0
		if i == grounds.size() - 1:
			x1 = 135.0
		_block(x0, x1, -2.5, 2.0, (300.0 - g[1]) / PX, -10.0)
	for p in TrainingRoom.PLATFORMS:
		var x0: float = p[0] / PX
		var x1: float = (p[0] + p[2]) / PX
		var top: float = (300.0 - p[1]) / PX
		_block(x0, x1, -1.25, 1.25, top, top - 0.5)
		_block(x0 + 0.5, x1 - 0.5, -0.9, 0.9, top - 0.5, top - 1.25, null, false)
		_block(x0 + 1.5, x1 - 1.5, -0.5, 0.5, top - 1.25, top - 1.75, null, false)
	# tufts along the front edge, flowers and rocks behind the play line
	var x := -40.0
	while x < 130.0:
		var top := _ground_top(x)
		_sprite("tuft", Vector3(x, top, _rng.randf_range(1.5, 1.9)), _rng.randf_range(0.9, 1.3))
		if _rng.randf() < 0.35:
			_sprite("flowers", Vector3(x + 0.7, top, _rng.randf_range(-2.2, -1.2)))
		if _rng.randf() < 0.12:
			_sprite("rock", Vector3(x + 1.3, top, -2.0), _rng.randf_range(0.8, 1.2))
		if _rng.randf() < 0.18:
			_sprite(["bush_a", "bush_b"][_rng.randi() % 2], Vector3(x, top, -2.3), _rng.randf_range(0.9, 1.2))
		x += _rng.randf_range(1.4, 3.0)


func _ground_top(x: float) -> float:
	for g in TrainingRoom.GROUND:
		if x * PX >= g[0] and x * PX < g[0] + g[2]:
			return (300.0 - g[1]) / PX
	return 0.0 if x < 40.0 else (300.0 - TrainingRoom.GROUND[-1][1]) / PX


func _front() -> void:
	# variant B: lower ground between camera and play line, a little stream
	# and big near bushes that the depth of field melts into soft shapes
	for b in _row(2.0, 4.5, -3.5, -10.0, 0.25, 0.5):
		if _rng.randf() < 0.6:
			_sprite("tuft", Vector3(b[0] + 2.0, b[3], b[2] - 0.4), 1.2)
		if _rng.randf() < 0.5:
			_sprite("flowers", Vector3(b[0] + 4.0, b[3], b[2] - 1.0))
	_water_plane(Vector3(45, -5.2, 7.0), Vector2(190, 6.0), 4.0, 10.0)
	_row(10.0, 26.0, -4.0, -10.0, 0.25, 0.0)
	var x := -40.0
	while x < 130.0:
		var k: String = ["bush_a", "bush_b", "bush_c", "tuft"][_rng.randi() % 4]
		_sprite(k, Vector3(x, -4.0, _rng.randf_range(10.5, 13.0)), _rng.randf_range(1.8, 2.8))
		x += _rng.randf_range(2.0, 5.0)


func _back_terrace() -> void:
	var rows := _row(RIVER_NEAR, -2.5, -5.75, -10.0, 0.25, 0.75)
	for b in rows:
		var x: float = b[0]
		while x < b[1]:
			var z := _rng.randf_range(-6.5, -4.0)
			var r := _rng.randf()
			if r < 0.3 and absf(x - BRIDGES[0]) > 3.0 and absf(x - BRIDGES[1]) > 3.0:
				_sprite(["tree_round_a", "tree_round_b", "tree_pine"][_rng.randi() % 3], Vector3(x, b[3], z), _rng.randf_range(1.1, 1.5), _tint(0.08))
			elif r < 0.6:
				_sprite(["bush_a", "bush_b", "bush_c"][_rng.randi() % 3], Vector3(x, b[3], z + 1.5), _rng.randf_range(1.0, 1.4))
			_sprite("tuft", Vector3(x + 1.0, b[3], RIVER_NEAR + 0.4), 1.0)
			x += _rng.randf_range(3.0, 6.5)


func _river() -> void:
	var m := _water_plane(Vector3(45, WATER_Y, (RIVER_NEAR + RIVER_FAR) * 0.5), Vector2(200, RIVER_NEAR - RIVER_FAR), RIVER_NEAR, RIVER_FAR)
	m.set_shader_parameter("mist_amount", 0.25)


func _water_plane(pos: Vector3, size: Vector2, bank_a: float, bank_b: float) -> ShaderMaterial:
	var mi := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = size
	mi.mesh = p
	mi.position = pos
	var m := _shader_mat("res://shaders/hd2d/water.gdshader", {"bank_a": bank_a, "bank_b": bank_b})
	mi.material_override = m
	mi.layers = Hd2dView.WATER_LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_materials.append(m)
	add_geometry(mi)
	return m


func _far_bank() -> void:
	var fall := {FALL_X: -4.5}
	var r1 := _row(-20.0, RIVER_FAR, -4.25, -10.0, 0.5, 0.0, fall)
	var r2 := _row(-27.0, -20.0, -1.5, -10.0, 0.75, 1.0, {FALL_X: -1.5})
	var r3 := _row(-36.0, -27.0, 1.5, -10.0, 1.0, 1.5, {FALL_X: 1.5})
	var r4 := _row(-50.0, -36.0, 5.0, -10.0, 1.25, 2.0)
	for b in r1:
		var x: float = b[0]
		while x < b[1]:
			if absf(x - FALL_X) > 2.5:
				_sprite(["bush_a", "bush_b", "bush_c", "rock"][_rng.randi() % 4], Vector3(x, b[3], _rng.randf_range(-19.0, -16.5)), _rng.randf_range(0.9, 1.3))
				_sprite("tuft", Vector3(x + 0.8, b[3], b[2] - 0.3))
			x += _rng.randf_range(2.0, 4.5)
	for rows in [[r2, 0.55, 1.3], [r3, 0.75, 1.5], [r4, 0.95, 1.7]]:
		for b in rows[0]:
			var x: float = b[0]
			while x < b[1]:
				if absf(x - FALL_X) > 2.5 and _rng.randf() < rows[1]:
					var k: String = ["tree_round_a", "tree_round_b", "tree_pine", "tree_pine"][_rng.randi() % 4]
					_sprite(k, Vector3(x, b[3], b[2] - _rng.randf_range(1.0, 5.0)), _rng.randf_range(1.1, rows[2]), _tint(0.1))
				else:
					_sprite(["bush_a", "bush_c"][_rng.randi() % 2], Vector3(x, b[3], b[2] - 0.8), 1.1)
				x += _rng.randf_range(2.5, 5.0)


func _tint(v: float) -> Color:
	var k := _rng.randf_range(-v, v)
	return Color(1.0 + k * 0.5, 1.0 + k, 1.0 + k * 0.3)


func _bridge(x: float) -> void:
	var y := -4.3
	var z0 := RIVER_FAR - 1.5
	var z1 := RIVER_NEAR + 1.0
	var hw := 1.2
	_block(x - hw, x + hw, z0, z1, y, y - 0.25, _wood_mat, false)
	for side in [-1.0, 1.0]:
		var px: float = x + side * (hw - 0.05)
		_block(px - 0.12, px + 0.12, z0, z1, y - 0.25, y - 0.55, _log_mat, false)  # beam
		_block(px - 0.06, px + 0.06, z0, z1, y + 1.05, y + 0.9, _log_mat, false)  # rail
		var z := z0 + 0.3
		while z <= z1:
			var bottom := WATER_Y - 0.5 if z > RIVER_FAR and z < RIVER_NEAR else y - 1.0
			_block(px - 0.13, px + 0.13, z - 0.13, z + 0.13, y + 1.3, bottom, _log_mat, false)
			z += 2.3
	# landing path on the near side, small stones on the far side
	# earth ramp up to the deck on the near bank
	_block(x - hw - 0.3, x + hw + 0.3, RIVER_NEAR - 0.2, RIVER_NEAR + 2.2, y - 0.25, -10.0)
	_sprite("rock", Vector3(x - 2.2, -5.75, RIVER_NEAR + 1.4), 0.9)
	_sprite("flowers", Vector3(x + 2.2, -5.75, RIVER_NEAR + 1.0))


func _waterfall() -> void:
	var fall_mat := _shader_mat("res://shaders/hd2d/waterfall.gdshader")
	# [z of the face, top, bottom]
	for step in [[-27.0, 1.5, -1.5], [-20.0, -1.5, -4.5], [RIVER_FAR, -4.5, WATER_Y]]:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		var h: float = step[1] - step[2] + 0.2
		q.size = Vector2(3.4, h)
		mi.mesh = q
		mi.position = Vector3(FALL_X, (step[1] + step[2]) * 0.5, step[0] + 0.08)
		var m: ShaderMaterial = fall_mat.duplicate()
		m.set_shader_parameter("width_px", 3.4 * PX)
		m.set_shader_parameter("height_px", h * PX)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_geometry(mi)
	# the stream on the terrace tops feeding it
	for s in [[-27.0, -20.0, -1.5], [-20.0, RIVER_FAR, -4.5], [-36.0, -27.0, 1.5]]:
		var m := _water_plane(Vector3(FALL_X, s[2] + 0.03, (s[0] + s[1]) * 0.5), Vector2(3.2, s[1] - s[0]), s[0] - 5.0, s[1] + 5.0)
		m.set_shader_parameter("flow", 0.0)
	# spray at the foot
	for i in 4:
		_mist(Vector3(FALL_X + _rng.randf_range(-1.5, 1.5), WATER_Y + 0.6 + i * 0.3, RIVER_FAR + 0.6), Vector2(4.5, 2.5), 0.45, 0.0)


func _hills() -> void:
	# distant tree-covered hills, then far ridges; the haze does the rest
	for layer in [[-62.0, 9.0, 20.0, 28.0], [-95.0, 16.0, 30.0, 45.0], [-140.0, 26.0, 45.0, 60.0]]:
		var x := -80.0
		while x < 170.0:
			var r := _rng.randf_range(layer[2], layer[3])
			var mi := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = r
			s.height = r * 2.0
			s.radial_segments = 24
			s.rings = 12
			mi.mesh = s
			mi.scale = Vector3(1.0, layer[1] / r, 0.6)
			mi.position = Vector3(x, -6.0, layer[0] - r * 0.3)
			mi.material_override = _terrain_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_geometry(mi)
			if layer[0] > -100.0:
				var tx := x - r * 0.7
				while tx < x + r * 0.7:
					var u: float = (tx - x) / r
					var top: float = -6.0 + layer[1] * sqrt(maxf(0.0, 1.0 - u * u)) - 0.6
					_sprite("tree_pine", Vector3(tx, top, layer[0] - r * 0.3 + r * 0.45), _rng.randf_range(1.6, 2.4))
					tx += _rng.randf_range(2.0, 4.0)
			x += r * _rng.randf_range(1.0, 1.5)


# --- atmosphere --------------------------------------------------------------

func _light_shafts() -> void:
	var m := _shader_mat("res://shaders/hd2d/shaft.gdshader")
	for i in 9:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(_rng.randf_range(3.0, 7.0), 46.0)
		mi.mesh = q
		mi.position = Vector3(-30.0 + i * 19.0 + _rng.randf_range(-5, 5), 8.0, _rng.randf_range(-30.0, -9.0))
		mi.rotation_degrees.z = 28.0
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_shafts.append(mi)


func _river_mist() -> void:
	var x := -40.0
	while x < 130.0:
		_mist(Vector3(x, WATER_Y + 0.9, _rng.randf_range(-14.0, -9.0)), Vector2(_rng.randf_range(10, 18), 3.0), 0.22, _rng.randf_range(0.3, 0.7))
		x += _rng.randf_range(10.0, 18.0)


func _mist(pos: Vector3, size: Vector2, amount: float, speed: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.position = pos
	mi.material_override = _shader_mat("res://shaders/hd2d/mist.gdshader", {"tex": _tex("dot"), "amount": amount})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_mists.append([mi, speed])


func _pollen() -> void:
	pollen = CPUParticles3D.new()
	pollen.amount = 160
	pollen.lifetime = 9.0
	pollen.preprocess = 9.0
	pollen.local_coords = false
	pollen.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	pollen.emission_box_extents = Vector3(26, 9, 14)
	pollen.direction = Vector3(1, 0.3, 0)
	pollen.spread = 180.0
	pollen.initial_velocity_min = 0.1
	pollen.initial_velocity_max = 0.5
	pollen.gravity = Vector3(0.12, -0.05, 0)
	pollen.scale_amount_min = 0.6
	pollen.scale_amount_max = 1.4
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _tex("dot")
	m.albedo_color = Color(1.0, 0.94, 0.7, 0.9)
	q.material = m
	pollen.mesh = q
	pollen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pollen)


# --- sprite cards ------------------------------------------------------------

func _sprite(kind: String, pos: Vector3, scale := 1.0, tint := Color.WHITE) -> void:
	if not _sprites.has(kind):
		_sprites[kind] = {"xf": [], "col": []}
	var flip := -1.0 if _rng.randf() < 0.5 else 1.0
	var b := Basis.from_scale(Vector3(scale * flip, scale, scale))
	_sprites[kind].xf.append(Transform3D(b, pos))
	_sprites[kind].col.append(tint)


func _flush_sprites() -> void:
	for kind in _sprites:
		var tex := _tex(kind)
		var w := tex.get_width() / PX
		var h := tex.get_height() / PX
		var q := QuadMesh.new()
		q.size = Vector2(w, h)
		q.center_offset = Vector3(0, h * 0.5, 0)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = q
		var list: Array = _sprites[kind].xf
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
			mm.set_instance_color(i, _sprites[kind].col[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var info: Array = SPRITE_KINDS.get(kind, [0.0, false])
		mmi.material_override = _shader_mat("res://shaders/hd2d/sprite.gdshader", {"tex": tex, "wind": info[0]})
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if info[1] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_geometry(mmi)
