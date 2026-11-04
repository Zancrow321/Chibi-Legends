extends Node
## Registers all input actions at startup (keyboard + gamepad), so the
## project.godot stays readable and bindings live in one place.

const KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_down": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE, KEY_W, KEY_UP],
	"dash": [KEY_SHIFT],
	"attack": [KEY_J],
	"skill_1": [KEY_K, KEY_1],
	"skill_2": [KEY_L, KEY_2],
	"skill_3": [KEY_I, KEY_3],
	"skill_4": [KEY_O, KEY_4],
	"super": [KEY_P, KEY_5],
	"cycle_fx": [KEY_V],
	"toggle_infinite_aura": [KEY_U],
	"reset_cooldowns": [KEY_R],
	"cycle_look": [KEY_C],
	"toggle_help": [KEY_H],
}

const PAD_BUTTONS := {
	"jump": [JOY_BUTTON_A],
	"dash": [JOY_BUTTON_B],
	"attack": [JOY_BUTTON_X],
	"skill_1": [JOY_BUTTON_Y],
	"skill_2": [JOY_BUTTON_RIGHT_SHOULDER],
	"skill_3": [JOY_BUTTON_LEFT_SHOULDER],
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"move_down": [JOY_BUTTON_DPAD_DOWN],
	"reset_cooldowns": [JOY_BUTTON_BACK],
	"cycle_look": [JOY_BUTTON_START],
}

## Triggers (axis) for skill 4, sticks for movement.
const PAD_AXES := {
	"skill_4": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	"super": [[JOY_AXIS_TRIGGER_LEFT, 1.0]],
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

