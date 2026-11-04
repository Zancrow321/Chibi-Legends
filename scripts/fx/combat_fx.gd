class_name CombatFx
extends Node2D
## Combat feel director: hit-stop (the world freezes for a few frames while
## sparks keep playing), camera shake and zoom punch, screen dimming for
## super moves and white screen flashes. Always processes, so it can run
## the timers while the tree is paused. Tuning lives in FxSettings.

const DIM_Z := 40       # world z of the dark super overlay
const FOCUS_Z := 45     # z of the character performing a super (above the dim)

var room: Node2D
var camera: Camera2D
var sparks: HitSparks

var base_zoom := Vector2(2, 2)
var _freeze := 0.0
var _hold := false       # super pause: stays frozen until released
var _trauma := 0.0
var _kick := Vector2.ZERO
var _punch := 0.0
var _dim := 0.0
var _dim_target := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _flash_layer: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = DIM_Z
	sparks = HitSparks.new()
	sparks.z_index = 10  # relative: above dim and focused character
	add_child(sparks)
	_flash_layer = Node2D.new()
	_flash_layer.z_index = 40
	_flash_layer.draw.connect(_draw_flash)
	add_child(_flash_layer)


## A full hit: sparks, hit-stop, shake, flash and zoom from a profile.
func hit(pos: Vector2, element: String, profile: String, dir: float) -> void:
	var p: Dictionary = FxSettings.HIT[profile]
	var heavy := profile != "light" and profile != "super"
	sparks.hit(pos, element, p.spark * FxSettings.factor("spark"), dir, heavy)
	_apply(p, dir)


## Reaction / finisher blast (big rings and star) with the given profile.
func blast(pos: Vector2, col: Color, radius: float, profile: String) -> void:
	var p: Dictionary = FxSettings.HIT[profile]
	sparks.blast(pos, col, radius, p.spark * FxSettings.factor("spark"))
	_apply(p, 0.0)


func _apply(p: Dictionary, dir: float) -> void:
	freeze(p.stop * FxSettings.factor("stop"))
	shake(p.shake * FxSettings.factor("shake"), dir)
	if p.flash > 0.0:
		flash(p.flash * FxSettings.factor("flash"))
	_punch = maxf(_punch, p.zoom)


func freeze(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_freeze = maxf(_freeze, seconds)
	get_tree().paused = true


## Super pause: freezes the world until hold(false).
func hold(on: bool) -> void:
	_hold = on
	get_tree().paused = on or _freeze > 0.0


func shake(amount: float, dir := 0.0) -> void:
	_trauma = maxf(_trauma, amount)
	if dir != 0.0:
		_kick = Vector2(dir * amount * 0.6, 0.0)  # first frames lean in the hit direction


func flash(strength: float, col := Color.WHITE) -> void:
	_flash = maxf(_flash, clampf(strength, 0.0, 1.0))
	_flash_color = col


func punch(amount: float) -> void:
	_punch = maxf(_punch, amount)


func dim(target: float) -> void:
	_dim_target = target


func is_frozen() -> bool:
	return _freeze > 0.0 or _hold


func _unhandled_input(event: InputEvent) -> void:
	# while frozen the player node gets no input: keep presses in its buffer
	if get_tree().paused and room != null and room.player != null:
		room.player.buffer_input(event)


func _process(delta: float) -> void:
	if _freeze > 0.0:
		_freeze -= delta
		if _freeze <= 0.0:
			_freeze = 0.0
			get_tree().paused = _hold
	# camera: shake (random + kick), zoom punch
	_trauma = maxf(0.0, _trauma - delta * (10.0 + _trauma * 4.0))
	_kick = _kick.lerp(Vector2.ZERO, 1.0 - exp(-25.0 * delta))
	_punch = maxf(0.0, _punch - delta * 0.6)
	if camera != null:
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _trauma + _kick
		camera.offset = off.round()
		camera.zoom = base_zoom * (1.0 + _punch)
	_dim = move_toward(_dim, _dim_target, delta * 4.0)
	_flash = maxf(0.0, _flash - delta * 5.0)
	queue_redraw()
	_flash_layer.queue_redraw()


func _view_rect() -> Rect2:
	if camera == null:
		return Rect2(-2000, -2000, 4000, 4000)
	var size := get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - size, size * 2.0)


func _draw() -> void:
	if _dim > 0.0:
		draw_rect(_view_rect(), Color(0.02, 0.0, 0.06, _dim))


func _draw_flash() -> void:
	if _flash > 0.0:
		_flash_layer.draw_rect(_view_rect(), Color(_flash_color, _flash * 0.8))
