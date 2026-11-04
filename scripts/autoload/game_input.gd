extends Node
## Registers all input actions at startup (keyboard + gamepad), so the
## project.godot stays readable and bindings live in one place.

const KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_down": [KEY_S, KEY_DOWN],
	"move_up": [KEY_W, KEY_UP],
	"jump": [KEY_SPACE],
	"dash": [KEY_SHIFT],
	"light": [KEY_J],
	"heavy": [KEY_K],
	"special": [KEY_L],
	"super": [KEY_P],
	"toggle_figure": [KEY_T],
	"cycle_moveset": [KEY_F],
	"cycle_fx": [KEY_V],
	"toggle_infinite_aura": [KEY_U],
	"reset_cooldowns": [KEY_R],
	"cycle_look": [KEY_C],
	"toggle_help": [KEY_H],
	"toggle_ui": [KEY_I],
	"style_menu": [KEY_TAB, KEY_M],
	"toggle_light": [KEY_N],
}

const PAD_BUTTONS := {
	"jump": [JOY_BUTTON_A],
	"dash": [JOY_BUTTON_RIGHT_SHOULDER],
	"light": [JOY_BUTTON_X],
	"heavy": [JOY_BUTTON_Y],
	"special": [JOY_BUTTON_B],
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"move_down": [JOY_BUTTON_DPAD_DOWN],
	"move_up": [JOY_BUTTON_DPAD_UP],
	"reset_cooldowns": [JOY_BUTTON_BACK],
	"cycle_look": [JOY_BUTTON_START],
	"style_menu": [JOY_BUTTON_LEFT_SHOULDER],
}

## Trigger for the super, sticks for movement and attack directions.
const PAD_AXES := {
	"super": [[JOY_AXIS_TRIGGER_LEFT, 1.0]],
	"move_up": [[JOY_AXIS_LEFT_Y, -1.0]],
	"move_left": [[JOY_AXIS_LEFT_X, -1.0]],
	"move_right": [[JOY_AXIS_LEFT_X, 1.0]],
	"move_down": [[JOY_AXIS_LEFT_Y, 1.0]],
}


func _ready() -> void:
	for action in KEYS:
		_ensure(action)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action in PAD_BUTTONS:
		_ensure(action)
		for button in PAD_BUTTONS[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)
	for action in PAD_AXES:
		_ensure(action)
		for pair in PAD_AXES[action]:
			var ev := InputEventJoypadMotion.new()
			ev.axis = pair[0]
			ev.axis_value = pair[1]
			InputMap.action_add_event(action, ev)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.35)


## Label for the HUD (first keyboard key of an action).
func key_label(action: String) -> String:
	if not KEYS.has(action):
		return ""
	return OS.get_keycode_string(KEYS[action][0])

