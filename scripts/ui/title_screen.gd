class_name TitleScreen
extends CanvasLayer
## Title screen on the first start: Kaiser's animated logo (80 frames, 20 fps)
## on black, "Taste drücken" blinks below. Any key, click or pad button fades
## it out, then `finished` fires (Main shows the area title card after it).
##
## The logo is drawn sharp from logo.png (frame 0, 960x640). The animation
## (shine sweep over the letters, flickering aura) comes from a half-size sheet:
## the shader adds (frame - frame 0) of the sheet on top of the sharp frame, so
## only the moving light is soft. Assets: tools/branding/make_logo_assets.py.
## In the web build ?titel=0 skips the screen.

signal finished

const FPS := 20.0
const FRAMES := 80
const COLS := 10
const ROWS := 8
const FADE_IN := 0.6
const FADE_OUT := 0.35

const SHADER := """
shader_type canvas_item;
uniform sampler2D base_tex : filter_linear;
uniform sampler2D sheet : filter_linear;
uniform bool linear_out = false;  // viewport renders HDR 2D (Bloom): it expects linear colour
uniform float frame = 0.0;
uniform vec2 grid = vec2(10.0, 8.0);
uniform float fade = 1.0;

vec3 cell(float f, vec2 uv) {
	vec2 c = vec2(mod(f, grid.x), floor(f / grid.x));
	// half a texel inside the cell so the linear filter never reads the neighbour
	vec2 px = 1.0 / vec2(textureSize(sheet, 0));
	vec2 inner = clamp(uv, px * grid * 0.5, 1.0 - px * grid * 0.5);
	return texture(sheet, (c + inner) / grid).rgb;
}

void fragment() {
	vec3 base = texture(base_tex, UV).rgb;
	vec3 col = base + cell(frame, UV) - cell(0.0, UV);
	col = clamp(col, 0.0, 1.0);
	if (linear_out) {
		col = mix(col / 12.92, pow((col + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), col));
	}
	COLOR = vec4(col * fade, 1.0);
}
"""

var _ctl: Control
var _logo: TextureRect
var _mat: ShaderMaterial
var _font: Font
var _t := 0.0
var _out := -1.0  # time since the key press, -1 = still waiting


func _ready() -> void:
	layer = 110  # above everything, also above the area wipe
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load("res://assets/fonts/PixelifySans-SemiBold.ttf")
	_ctl = Control.new()
	_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctl.mouse_filter = Control.MOUSE_FILTER_STOP
	_ctl.draw.connect(_draw_bg)
	add_child(_ctl)

	_mat = ShaderMaterial.new()
	_mat.shader = Shader.new()
	_mat.shader.code = SHADER
	_mat.set_shader_parameter("sheet", load("res://assets/branding/logo_anim_sheet.png"))
	_mat.set_shader_parameter("grid", Vector2(COLS, ROWS))
	var base: Texture2D = load("res://assets/branding/logo.png")
	_mat.set_shader_parameter("base_tex", base)
	_logo = TextureRect.new()
	_logo.texture = base
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.material = _mat
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ctl.add_child(_logo)
	get_tree().paused = true


func _process(delta: float) -> void:
	_t += delta
	var fade := clampf(_t / FADE_IN, 0.0, 1.0)
	if _out >= 0.0:
		_out += delta
		fade = 1.0 - clampf(_out / FADE_OUT, 0.0, 1.0)
		if _out >= FADE_OUT:
			get_tree().paused = false
			finished.emit()
			queue_free()
			return
	_mat.set_shader_parameter("frame", float(int(_t * FPS) % FRAMES))
	_mat.set_shader_parameter("fade", fade)
	_mat.set_shader_parameter("linear_out", get_viewport().use_hdr_2d)
	var size := _ctl.get_viewport_rect().size
	_ctl.size = size
	# logo as large as fits, never above its own size (960x640), room for the prompt below
	var k := minf(minf(size.x / 960.0, (size.y - 40.0) / 640.0), 1.0)
	var ls := Vector2(960.0, 640.0) * k
	_logo.size = ls
	_logo.position = Vector2((size.x - ls.x) * 0.5, maxf(0.0, (size.y - 40.0 - ls.y) * 0.5))
	_ctl.queue_redraw()


func _draw_bg() -> void:
	var size := _ctl.size
	var a := 1.0 if _out < 0.0 else 1.0 - clampf(_out / FADE_OUT, 0.0, 1.0)
	_ctl.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, a))
	if _out >= 0.0 or _t < FADE_IN:
		return
	var blink := 0.55 + 0.45 * cos(_t * 4.0)
	var text := "Taste drücken"
	var fs := 22
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var y := _logo.position.y + _logo.size.y + 26.0
	y = minf(y, size.y - 14.0)
	var p := Vector2((size.x - w) * 0.5, y)
	_ctl.draw_string_outline(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(UiSkin.INK, blink))
	_ctl.draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.86, 0.45, blink))


func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _out < 0.0 and _t > 0.25:
		_out = 0.0
		Sfx.play("ui_confirm")
